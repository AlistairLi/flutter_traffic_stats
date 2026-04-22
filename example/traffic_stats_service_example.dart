// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
//
// import 'package:flutter_mxlogger/flutter_mxlogger.dart';
// import 'package:flutter_traffic_stats/flutter_traffic_stats.dart';
// import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';
//
// /// 宿主工程侧的流量统计落盘与上报实现。
// ///
// /// - 外层负责懒初始化和统一入口
// /// - 内层负责具体的 MXLogger 初始化与文件读写
// /// - flutter_mxlogger: ^1.2.15
// class TrafficStatsService {
//   static final TrafficStatsService _instance =
//       TrafficStatsService._internal();
//
//   factory TrafficStatsService() => _instance;
//
//   TrafficStatsService._internal();
//
//   _TrafficStatsWriteLog? _writeLog;
//   bool _configured = false;
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
//       ),
//     );
//   }
//
//   /// 根据远端开关控制流量统计是否开启。
//   void setEnabled(bool enabled) {
//     FlutterTrafficStats.setEnabled(enabled);
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
//       FlutterTrafficStats.restoreFromJson(json);
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
//       if (_writeLog == null) {
//         await _init();
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
//   Future<void> reportSnapshot(
//     TrafficStatsSnapshot memorySnapshot,
//     TrafficStatsReportContext context,
//   ) async {
//     final writeLog = _writeLog ?? await _init();
//     final persistedJson = await writeLog.readSnapshotJson();
//     final reportedSnapshot = persistedJson != null
//         ? TrafficStatsSnapshot.fromJson(persistedJson)
//         : memorySnapshot;
//
//     final uploadModel = await CommonApi.of.getUploadParam();
//     if (uploadModel == null) {
//       Logger.network(
//           event: NetEvents.failedUploadParamsFailed,
//           msg:
//               'Failed to obtain the upload parameters, on report traffic, stats, uploadModel == null.');
//       return;
//     }
//
//     final payload = persistedJson ?? memorySnapshot.toJson();
//     final payloadBytes = utf8.encode(jsonEncode(payload));
//     final uploaded = await TrafficAwareOssUploader.putBytesObject(
//       endpoint: uploadModel.endpoint,
//       accessKeyId: uploadModel.accessKeyId,
//       accessKeySecret: uploadModel.accessKeySecret,
//       securityToken: uploadModel.securityToken,
//       bucketName: uploadModel.bucket,
//       uploadPath: uploadModel.path,
//       uploadBytes: payloadBytes,
//     );
//     if (!uploaded) {
//       throw StateError('traffic stats upload to oss failed');
//     }
//
//     final saved = await CommonApi.of.uploadLog(uploadModel.path);
//     if (!saved) {
//       throw StateError('traffic stats upload callback failed');
//     }
//
//     await writeLog.deleteSnapshot();
//     FlutterTrafficStats.store.consumeReportedSnapshot(reportedSnapshot);
//
//     writeLog.infoLog(
//       'report traffic stats trigger=${context.trigger.name} count=${context.dailyReportCount}',
//       name: 'traffic_stats',
//       tag: 'report',
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
//       msg: 'NadyTrafficStatsService.$action error',
//       exception: error,
//       stackTrace: stackTrace,
//     );
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
//   static const String _nameSpace = 'com.nadychat.traffic.stats';
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
//     final file = await _snapshotFile();
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
//     final file = await _snapshotFile();
//     if (await file.exists()) {
//       await file.delete();
//     }
//   }
//
//   @override
//
//   /// 覆盖写入最新快照到本地文件。
//   Future<void> writeSnapshot(TrafficStatsSnapshot snapshot) async {
//     final file = await _snapshotFile();
//     await file.parent.create(recursive: true);
//     await file.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
//   }
//
//   /// 返回快照文件路径。
//   Future<File> _snapshotFile() async {
//     if (logDir == null || logDir!.isEmpty) {
//       throw StateError('traffic stats logger is not initialized');
//     }
//     return File(p.join(logDir!, _snapshotFileName));
//   }
// }
