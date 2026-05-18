// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
//
// /// 宿主工程侧的流量统计落盘与上报实现。
// ///
// /// - 外层负责懒初始化和统一入口
// /// - 内层负责具体的 MXLogger 初始化与文件读写
// class TrafficStatsService {
//   static const Duration _reportInterval = Duration(minutes: 30);
//
//   static final TrafficStatsService _instance =
//   TrafficStatsService._internal();
//
//   factory TrafficStatsService() => _instance;
//
//   TrafficStatsService._internal();
//
//   _TrafficStatsWriteLog? _writeLog;
//   bool _configured = false;
//
//   bool get _enabled => FlutterTrafficStats.isEnabled;
//
//   /// 将宿主 App 版本注入流量统计快照。
//   Future<void> configureAppVersion() async {
//     try {
//       final packageInfo = await PackageInfo.fromPlatform();
//       FlutterTrafficStats.setAppVersion(
//         '${packageInfo.version}+${packageInfo.buildNumber}',
//       );
//     } catch (e, s) {
//       _logError('configureAppVersion', e, s);
//     }
//   }
//
//   /// 懒初始化底层存储实现。
//   Future<_TrafficStatsWriteLog> _init() async {
//     _TrafficStatsWriteLog writeLog = _MXTrafficStatsWriteLog();
//     _writeLog = await writeLog.init();
//     return writeLog;
//   }
//
//   /// 给流量统计库注入宿主侧的落盘和上报回调。
//   void configure() {
//     if (_configured) {
//       return;
//     }
//     _configured = true;
//     FlutterTrafficStats.configurePersistence(
//       TrafficStatsPersistenceConfig(
//         onPersist: (snapshot) =>
//             TrafficStatsService().persistSnapshot(snapshot),
//       ),
//     );
//     FlutterTrafficStats.configureReporting(
//       TrafficStatsReportingConfig(
//         onReport: (snapshot, context) =>
//             TrafficStatsService().reportSnapshot(snapshot, context),
//         loadReportQuota: TrafficStatsService().loadReportQuota,
//         saveReportQuota: TrafficStatsService().saveReportQuota,
//       ),
//     );
//   }
//
//   /// 根据远端开关控制流量统计是否开启。
//   void setEnabled(bool enabled) async {
//     if (enabled) {
//       await configureAppVersion();
//     }
//     FlutterTrafficStats.setEnabled(enabled, clearOnDisable: true);
//     if (!enabled) {
//       unawaited(_deleteSnapshotIfNeeded());
//     }
//   }
//
//   /// 启动时从本地恢复上次落盘的统计快照。
//   Future<void> restorePersistedSnapshot() async {
//     try {
//       final writeLog = _writeLog ?? await _init();
//       final json = await writeLog.readSnapshotJson();
//       if (json == null) {
//         return;
//       }
//       final snapshot = TrafficStatsSnapshot.fromJson(json);
//       if (!_isCurrentAppVersionSnapshot(snapshot)) {
//         await _discardStaleSnapshot(writeLog, snapshot, clearMemory: true);
//         return;
//       }
//       FlutterTrafficStats.restoreFromSnapshot(snapshot);
//       writeLog.infoLog(
//         'restore traffic stats snapshot from local file',
//         name: 'traffic_stats',
//         tag: 'restore',
//       );
//     } catch (e, s) {
//       _logError('restorePersistedSnapshot', e, s);
//     }
//   }
//
//   /// 进入首页后主动触发一次上报。
//   Future<void> reportAfterEnterMainPage() async {
//     try {
//       if (!_enabled) {
//         return;
//       }
//       if (_writeLog == null) {
//         await _init();
//       }
//       if (!await _canTriggerReportNow()) {
//         return;
//       }
//       await FlutterTrafficStats.reportNow();
//     } catch (e, s) {
//       _logError('reportAfterEnterMainPage', e, s);
//     }
//   }
//
//   /// 将内存中的统计快照写入本地文件。
//   Future<void> persistSnapshot(TrafficStatsSnapshot snapshot) async {
//     final writeLog = _writeLog ?? await _init();
//     await writeLog.writeSnapshot(snapshot);
//     writeLog.infoLog(
//       'persist traffic stats snapshot bytes=${snapshot.totals['snapshotBytes']}',
//       name: 'traffic_stats',
//       tag: 'persist',
//     );
//   }
//
//   /// 执行一次真正的上报逻辑，优先读取本地快照，没有再回退到内存快照。
//   Future<bool> reportSnapshot(
//       TrafficStatsSnapshot memorySnapshot,
//       TrafficStatsReportContext context,
//       ) async {
//     if (!_enabled) {
//       return false;
//     }
//     final writeLog = _writeLog ?? await _init();
//     final persistedJson = await writeLog.readSnapshotJson();
//     final reportedSnapshot = persistedJson == null
//         ? memorySnapshot
//         : TrafficStatsSnapshot.fromJson(persistedJson);
//     final usePersistedSnapshot =
//         persistedJson != null && _isCurrentAppVersionSnapshot(reportedSnapshot);
//     if (persistedJson != null && !usePersistedSnapshot) {
//       await _discardStaleSnapshot(writeLog, reportedSnapshot);
//     }
//     final payload =
//     usePersistedSnapshot ? persistedJson : memorySnapshot.toJson();
//
//     final uploadModel = await CommonApi.of.getUploadParam();
//     if (uploadModel == null) {
//       Logger.network(
//           event: NetEvents.failedUploadParamsFailed,
//           msg:
//           'Failed to obtain the upload parameters, on report traffic, stats, uploadModel == null.');
//       return false;
//     }
//     if (!_enabled) {
//       return false;
//     }
//
//     final payloadBytes = utf8.encode(jsonEncode(payload));
//     final uploaded = await TrafficAwareOssUploader.putBytesObject(
//         endpoint: uploadModel.endpoint,
//         accessKeyId: uploadModel.accessKeyId,
//         accessKeySecret: uploadModel.accessKeySecret,
//         securityToken: uploadModel.securityToken,
//         bucketName: uploadModel.bucket,
//         uploadPath: uploadModel.path,
//         uploadBytes: payloadBytes,
//         label: 'traffic_stats_upload\n${uploadModel.path}');
//     if (!uploaded) {
//       return false;
//     }
//     if (!_enabled) {
//       return false;
//     }
//
//     final saved = await CommonApi.of.uploadLog(uploadModel.path);
//     if (!saved) {
//       return false;
//     }
//
//     if (usePersistedSnapshot) {
//       await writeLog.deleteSnapshot();
//     }
//     FlutterTrafficStats.store.consumeReportedSnapshot(
//       usePersistedSnapshot ? reportedSnapshot : memorySnapshot,
//     );
//     await _updateLastReportAt();
//
//     writeLog.infoLog(
//       'report traffic stats trigger=${context.trigger.name} count=${context.dailyReportCount}',
//       name: 'traffic_stats',
//       tag: 'report',
//     );
//     return true;
//   }
//
//   bool _isCurrentAppVersionSnapshot(TrafficStatsSnapshot snapshot) {
//     final currentAppVersion = FlutterTrafficStats.store.appVersion;
//     return snapshot.appVersion != null &&
//         currentAppVersion != null &&
//         snapshot.appVersion == currentAppVersion;
//   }
//
//   Future<void> _discardStaleSnapshot(
//       _TrafficStatsWriteLog writeLog, TrafficStatsSnapshot snapshot,
//       {bool clearMemory = false}) async {
//     await writeLog.deleteSnapshot();
//     if (clearMemory) {
//       FlutterTrafficStats.store.clear();
//     }
//     writeLog.infoLog(
//       'discard stale traffic stats snapshot appVersion=${snapshot.appVersion}',
//       name: 'traffic_stats',
//       tag: 'version',
//     );
//   }
//
//   Future<TrafficStatsReportQuota?> loadReportQuota() async {
//     final day = await SpUtil().getString(
//       SpKeys.trafficStatsReportQuotaDay,
//       '',
//     );
//     if (day.isEmpty) {
//       return null;
//     }
//     final quotaDay = DateTime.tryParse(day);
//     if (quotaDay == null) {
//       return null;
//     }
//     final count = await SpUtil().getInt(
//       SpKeys.trafficStatsReportCountToday,
//       0,
//     );
//     return TrafficStatsReportQuota(
//       quotaDay: quotaDay,
//       reportCountToday: count,
//     );
//   }
//
//   Future<void> saveReportQuota(TrafficStatsReportQuota quota) async {
//     await SpUtil().setString(
//       SpKeys.trafficStatsReportQuotaDay,
//       formatQuotaDay(quota.quotaDay),
//     );
//     await SpUtil().setInt(
//       SpKeys.trafficStatsReportCountToday,
//       quota.reportCountToday,
//     );
//   }
//
//   /// 统一记录流量统计模块内部错误。
//   void _logError(String action, Object error, [StackTrace? stackTrace]) {
//     _writeLog?.errorLog(
//       '$action failed: $error',
//       name: 'traffic_stats',
//       tag: 'error',
//     );
//     Logger.network(
//       event: NetEvents.apiRequestFailed,
//       msg: 'TrafficStatsService.$action error',
//       exception: error,
//       stackTrace: stackTrace,
//     );
//   }
//
//   Future<bool> _canTriggerReportNow() async {
//     final lastReportMillis = await SpUtil().getInt(
//       SpKeys.trafficStatsLastReportAt,
//       0,
//     );
//     if (lastReportMillis <= 0) {
//       return true;
//     }
//     final lastReportAt = DateTime.fromMillisecondsSinceEpoch(lastReportMillis);
//     return DateTime.now().difference(lastReportAt) >= _reportInterval;
//   }
//
//   Future<void> _updateLastReportAt() {
//     return SpUtil().setInt(
//       SpKeys.trafficStatsLastReportAt,
//       DateTime.now().millisecondsSinceEpoch,
//     );
//   }
//
//   Future<void> _deleteSnapshotIfNeeded() async {
//     try {
//       final writeLog = _writeLog ?? await _init();
//       await writeLog.deleteSnapshot();
//     } catch (e, s) {
//       _logError('deleteSnapshotIfNeeded', e, s);
//     }
//   }
// }
//
// abstract class _TrafficStatsWriteLog {
//   /// 初始化底层日志目录和文件能力。
//   Future<_TrafficStatsWriteLog> init();
//
//   /// 记录普通信息日志。
//   void infoLog(String msg, {String? name, String? tag});
//
//   /// 记录错误日志。
//   void errorLog(String msg, {String? name, String? tag});
//
//   /// 写入最新的流量统计快照。
//   Future<void> writeSnapshot(TrafficStatsSnapshot snapshot);
//
//   /// 读取最近一次落盘的流量统计快照。
//   Future<Map<String, dynamic>?> readSnapshotJson();
//
//   /// 删除本地已落盘的流量统计快照。
//   Future<void> deleteSnapshot();
// }
//
// class _MXTrafficStatsWriteLog extends _TrafficStatsWriteLog {
//   static const String _nameSpace = 'com.chat.traffic.stats';
//   static const String _snapshotFileName = 'traffic_stats_snapshot.json';
//
//   MXLogger? logger;
//   String? logDir;
//
//   @override
//
//   /// 初始化独立的 MXLogger 目录与存储参数。
//   Future<_TrafficStatsWriteLog> init() async {
//     final directory = await getApplicationDocumentsDirectory();
//     logger = await MXLogger.initialize(
//       nameSpace: _nameSpace,
//       directory: '${directory.path}/traffic_stats_logs/',
//       storagePolicy: MXStoragePolicyType.yyyy_MM_dd,
//       fileName: 'traffic_stats',
//       fileHeader: 'traffic stats snapshot storage',
//     );
//     logger?.setMaxDiskAge(60 * 60 * 24 * 7);
//     logger?.setMaxDiskSize(1024 * 1024 * 10);
//     logger?.setConsoleEnable(false);
//     logger?.setLevel(1);
//     logDir = logger?.diskcachePath;
//     return this;
//   }
//
//   @override
//
//   /// 写入错误级别日志。
//   void errorLog(String msg, {String? name, String? tag}) {
//     logger?.error(msg, name: name, tag: tag);
//   }
//
//   @override
//
//   /// 写入信息级别日志。
//   void infoLog(String msg, {String? name, String? tag}) {
//     logger?.info(msg, name: name, tag: tag);
//   }
//
//   @override
//
//   /// 读取本地保存的快照 JSON。
//   Future<Map<String, dynamic>?> readSnapshotJson() async {
//     final file = await _snapshotFile(_snapshotFileName);
//     if (!await file.exists()) {
//       return null;
//     }
//
//     final content = await file.readAsString();
//     if (content.isEmpty) {
//       return null;
//     }
//     return Map<String, dynamic>.from(jsonDecode(content) as Map);
//   }
//
//   @override
//   Future<void> deleteSnapshot() async {
//     final file = await _snapshotFile(_snapshotFileName);
//     if (await file.exists()) {
//       await file.delete();
//     }
//   }
//
//   @override
//
//   /// 覆盖写入最新快照到本地文件。
//   Future<void> writeSnapshot(TrafficStatsSnapshot snapshot) async {
//     final file = await _snapshotFile(_snapshotFileName);
//     await _writeSnapshotFile(file, snapshot);
//   }
//
//   Future<void> _writeSnapshotFile(
//       File file,
//       TrafficStatsSnapshot snapshot,
//       ) async {
//     await file.parent.create(recursive: true);
//     await file.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
//   }
//
//   /// 返回快照文件路径。
//   Future<File> _snapshotFile(String fileName) async {
//     if (logDir == null || logDir!.isEmpty) {
//       throw StateError('traffic stats logger is not initialized');
//     }
//     return File(p.join(logDir!, fileName));
//   }
// }
