import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

String formatQuotaDay(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// High-level traffic source categories used for aggregation.
enum TrafficBucket {
  /// Standard HTTP/HTTPS API traffic.
  /// 普通 HTTP/HTTPS 接口流量。
  api,

  /// Image loading traffic.
  /// 图片加载流量。
  image,

  /// Other remote resource traffic.
  /// 其他远程资源流量。
  resource,

  /// WebSocket or long-link traffic.
  /// WebSocket 或长连接流量。
  webSocket,

  /// Realtime voice/audio streaming traffic.
  /// 实时语音/音频流量。
  rtcAudio,

  /// Generic file download traffic.
  /// 通用文件下载流量。
  fileDownload,

  /// Generic file upload traffic.
  /// 通用文件上传流量。
  fileUpload,

  /// Short video playback traffic.
  /// 短视频播放流量。
  shortVideo,

  // /// Instant messaging traffic.
  // /// 即时消息流量。
  // im,
}

/// Describes how precise a traffic measurement is.
enum TrafficAccuracy {
  /// Exact byte/field count from a trusted source.
  /// 来自可靠来源的精确字节/字段统计。
  exact,

  /// Estimated count derived from payload shape or headers.
  /// 根据 payload 结构或 header 推算的估算值。
  estimated,

  /// Only occurrence/count is known, not actual bytes.
  /// 仅知道次数，无法得到真实字节数。
  countOnly,
}

/// Aggregated traffic data for one logical item, such as an API or channel.
class TrafficAggregate {
  TrafficAggregate({
    required this.bucket,
    required this.label,
    required this.host,
    required this.accuracy,
  });

  /// Traffic category of this aggregate item.
  /// 当前聚合项所属的流量类别。
  final TrafficBucket bucket;

  /// Human-readable identifier, such as API path or channel name.
  /// 可读标识，例如接口路径或频道名。
  final String label;

  /// Host/domain related to this traffic item.
  /// 当前流量项关联的主机或域名。
  final String host;

  /// Precision level of the collected stats.
  /// 当前统计结果的精度级别。
  TrafficAccuracy accuracy;

  /// Uploaded bytes.
  /// 上行字节数。
  int uploadBytes = 0;

  /// Downloaded bytes.
  /// 下行字节数。
  int downloadBytes = 0;

  /// Total request or message count.
  /// 请求或消息总次数。
  int requestCount = 0;

  /// Failed request or message count.
  /// 失败次数。
  int failureCount = 0;

  /// Retry count caused by retry logic.
  /// 因重试逻辑产生的重试次数。
  int retryCount = 0;

  /// Cache hit count.
  /// 缓存命中次数。
  int cacheHitCount = 0;

  /// Cache miss count.
  /// 缓存未命中次数。
  int cacheMissCount = 0;

  /// Rapid repeated request count used to identify suspicious duplication.
  /// 快速重复请求次数，用于识别可疑重复流量。
  int rapidRepeatCount = 0;

  /// Number of times this aggregate item was observed.
  /// 当前聚合项被记录的出现次数。
  int occurrenceCount = 0;

  /// Recursive total field count of response payloads.
  /// 响应体递归字段总数。
  int responseFieldCount = 0;

  /// Top-level field count of response payloads.
  /// 响应体顶层字段总数。
  int topLevelFieldCount = 0;

  /// Recursive field count inside the `data` field.
  /// `data` 字段内部的递归字段总数。
  int dataInnerFieldCount = 0;

  /// Total field count across array elements.
  /// 数组元素累计字段总数。
  int arrayElementFieldCount = 0;

  /// Total counted array element count.
  /// 已统计的数组元素总数。
  int arrayElementCount = 0;

  /// Optional extra note for limitations or context.
  /// 额外说明，用于记录限制或上下文。
  String? note;

  /// Optional remote path used by assets such as images, files, and videos.
  /// 可选的远程路径，用于图片、文件、短视频等资源。
  String? remoteUrl;

  /// Sum of uploaded and downloaded bytes.
  /// 上下行总字节数。
  int get totalBytes => uploadBytes + downloadBytes;

  /// Average recursive field count per occurrence.
  /// 每次出现对应的平均递归字段数。
  double get averageResponseFieldCount =>
      occurrenceCount == 0 ? 0 : responseFieldCount / occurrenceCount;

  /// Average top-level field count per occurrence.
  /// 每次出现对应的平均顶层字段数。
  double get averageTopLevelFieldCount =>
      occurrenceCount == 0 ? 0 : topLevelFieldCount / occurrenceCount;

  /// Average recursive field count inside `data` per occurrence.
  /// 每次出现对应的 `data` 内平均递归字段数。
  double get averageDataInnerFieldCount =>
      occurrenceCount == 0 ? 0 : dataInnerFieldCount / occurrenceCount;

  /// Average field count per array element.
  /// 每个数组元素对应的平均字段数。
  double get averageArrayElementFieldCount =>
      arrayElementCount == 0 ? 0 : arrayElementFieldCount / arrayElementCount;

  /// Serializes the aggregate into a JSON-friendly map.
  /// 将聚合结果序列化为可持久化的 Map 结构。
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'bucket': bucket.name,
      'label': label,
      'host': host,
      'accuracy': accuracy.name,
      'uploadBytes': uploadBytes,
      'downloadBytes': downloadBytes,
      'totalBytes': totalBytes,
      'requestCount': requestCount,
      'failureCount': failureCount,
      'retryCount': retryCount,
      'cacheHitCount': cacheHitCount,
      'cacheMissCount': cacheMissCount,
      'rapidRepeatCount': rapidRepeatCount,
      'occurrenceCount': occurrenceCount,
      'responseFieldCount': responseFieldCount,
      'averageResponseFieldCount': averageResponseFieldCount,
      'topLevelFieldCount': topLevelFieldCount,
      'averageTopLevelFieldCount': averageTopLevelFieldCount,
      'dataInnerFieldCount': dataInnerFieldCount,
      'averageDataInnerFieldCount': averageDataInnerFieldCount,
      'arrayElementFieldCount': arrayElementFieldCount,
      'arrayElementCount': arrayElementCount,
      'averageArrayElementFieldCount': averageArrayElementFieldCount,
      'note': note,
      'remoteUrl': remoteUrl,
    };
  }

  /// Restores one aggregate item from persisted JSON data.
  /// 从已持久化的 JSON 数据恢复单个聚合项。
  factory TrafficAggregate.fromJson(Map<String, dynamic> json) {
    final aggregate = TrafficAggregate(
      bucket: TrafficBucket.values.byName(json['bucket'] as String),
      label: json['label'] as String? ?? '',
      host: json['host'] as String? ?? '',
      accuracy: TrafficAccuracy.values.byName(json['accuracy'] as String),
    );
    aggregate.uploadBytes = (json['uploadBytes'] as num?)?.toInt() ?? 0;
    aggregate.downloadBytes = (json['downloadBytes'] as num?)?.toInt() ?? 0;
    aggregate.requestCount = (json['requestCount'] as num?)?.toInt() ?? 0;
    aggregate.failureCount = (json['failureCount'] as num?)?.toInt() ?? 0;
    aggregate.retryCount = (json['retryCount'] as num?)?.toInt() ?? 0;
    aggregate.cacheHitCount = (json['cacheHitCount'] as num?)?.toInt() ?? 0;
    aggregate.cacheMissCount = (json['cacheMissCount'] as num?)?.toInt() ?? 0;
    aggregate.rapidRepeatCount =
        (json['rapidRepeatCount'] as num?)?.toInt() ?? 0;
    aggregate.occurrenceCount = (json['occurrenceCount'] as num?)?.toInt() ?? 0;
    aggregate.responseFieldCount =
        (json['responseFieldCount'] as num?)?.toInt() ?? 0;
    aggregate.topLevelFieldCount =
        (json['topLevelFieldCount'] as num?)?.toInt() ?? 0;
    aggregate.dataInnerFieldCount =
        (json['dataInnerFieldCount'] as num?)?.toInt() ?? 0;
    aggregate.arrayElementFieldCount =
        (json['arrayElementFieldCount'] as num?)?.toInt() ?? 0;
    aggregate.arrayElementCount =
        (json['arrayElementCount'] as num?)?.toInt() ?? 0;
    aggregate.note = json['note'] as String?;
    aggregate.remoteUrl = json['remoteUrl'] as String?;
    return aggregate;
  }
}

/// Detailed field-count breakdown for one response payload.
class TrafficFieldStats {
  const TrafficFieldStats({
    required this.totalFieldCount,
    required this.topLevelFieldCount,
    required this.dataInnerFieldCount,
    required this.arrayElementFieldCount,
    required this.arrayElementCount,
  });

  /// Recursive total field count of the whole payload.
  /// 整个 payload 的递归字段总数。
  final int totalFieldCount;

  /// Number of top-level fields.
  /// 顶层字段数量。
  final int topLevelFieldCount;

  /// Recursive field count inside the `data` field.
  /// `data` 字段内部的递归字段总数。
  final int dataInnerFieldCount;

  /// Total field count summed across array elements.
  /// 数组元素累计字段总数。
  final int arrayElementFieldCount;

  /// Number of array elements that participated in counting.
  /// 参与统计的数组元素数量。
  final int arrayElementCount;
}

/// Snapshot object used by the UI/export layer to read current totals.
class TrafficStatsSnapshot {
  TrafficStatsSnapshot({
    required this.generatedAt,
    required this.appVersion,
    required this.totals,
    required this.items,
  });

  /// Time when the snapshot was generated.
  /// 快照生成时间。
  final DateTime generatedAt;

  /// Caller-provided app version attached to this snapshot.
  /// 调用方提供的 App 版本。
  final String? appVersion;

  /// Global totals summary.
  /// 全局汇总统计。
  final Map<String, dynamic> totals;

  /// Flattened aggregate item list.
  /// 扁平化的聚合项列表。
  final List<Map<String, dynamic>> items;

  /// Serializes the snapshot into a JSON-friendly map.
  /// 将快照序列化为可持久化的 Map 结构。
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'generatedAt': generatedAt.toIso8601String(),
      'appVersion': appVersion,
      'totals': totals,
      'items': items,
    };
  }

  /// Restores one snapshot from persisted JSON data.
  /// 从已持久化的 JSON 数据恢复快照。
  factory TrafficStatsSnapshot.fromJson(Map<String, dynamic> json) {
    return TrafficStatsSnapshot(
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      appVersion: json['appVersion'] as String?,
      totals: Map<String, dynamic>.from(
        json['totals'] as Map? ?? const <String, dynamic>{},
      ),
      items: (json['items'] as List? ?? const <dynamic>[])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }
}

/// 宿主侧实现的落盘回调类型。
typedef TrafficStatsPersistCallback = FutureOr<void> Function(
    TrafficStatsSnapshot snapshot);

/// 宿主侧实现的上报回调类型。
typedef TrafficStatsReportCallback = FutureOr<bool> Function(
  TrafficStatsSnapshot snapshot,
  TrafficStatsReportContext context,
);

typedef TrafficStatsLoadReportQuotaCallback = FutureOr<TrafficStatsReportQuota?>
    Function();

typedef TrafficStatsSaveReportQuotaCallback = FutureOr<void> Function(
  TrafficStatsReportQuota quota,
);

/// 上报触发来源。
/// 区分是定时调度还是业务侧主动触发。
enum TrafficStatsReportTrigger { scheduled, manual }

/// 上报时附带的上下文信息。
/// 调用方可以根据触发来源和当日次数决定自己的上报策略。
class TrafficStatsReportContext {
  const TrafficStatsReportContext({
    required this.trigger,
    required this.reportedAt,
    required this.dailyReportCount,
    required this.maxReportsPerDay,
  });

  /// 本次上报的触发来源。
  final TrafficStatsReportTrigger trigger;

  /// 本次实际上报的时间。
  final DateTime reportedAt;

  /// 本次上报完成后，对应的当日累计上报次数。
  final int dailyReportCount;

  /// 当前配置下允许的当日最大上报次数。
  final int maxReportsPerDay;
}

class TrafficStatsReportQuota {
  const TrafficStatsReportQuota({
    required this.quotaDay,
    required this.reportCountToday,
  });

  factory TrafficStatsReportQuota.fromJson(Map<String, dynamic> json) {
    return TrafficStatsReportQuota(
      quotaDay: DateTime.parse(json['quotaDay'] as String),
      reportCountToday: json['reportCountToday'] as int? ?? 0,
    );
  }

  final DateTime quotaDay;
  final int reportCountToday;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'quotaDay': formatQuotaDay(quotaDay),
      'reportCountToday': reportCountToday,
    };
  }
}

/// 诊断明细采集配置。
///
/// 与原有累计统计开关独立：只有宿主显式配置诊断时才会保留事件级明细。
class TrafficStatsDiagnosisConfig {
  const TrafficStatsDiagnosisConfig({
    required this.enabled,
    required this.startedAt,
    required this.expiresAt,
    this.maxEvents = 5000,
    this.maxCacheBytes = 10 * 1024 * 1024,
  });

  /// 是否启用诊断明细采集。
  final bool enabled;

  /// 诊断窗口开始时间，早于该时间的事件不会进入 ring buffer。
  final DateTime startedAt;

  /// 诊断窗口结束时间，晚于该时间的事件不会进入 ring buffer。
  final DateTime expiresAt;

  /// 诊断事件数量上限，超过后淘汰最早事件。
  final int maxEvents;

  /// 诊断事件内存估算上限，超过后淘汰最早事件。
  final int maxCacheBytes;
}

/// 指定时间窗口内的 Flutter 侧流量诊断快照。
///
/// 该快照面向排查问题：包含总量、bucket 汇总和按流量排序的 topItems。
class TrafficStatsDiagnosisSnapshot {
  const TrafficStatsDiagnosisSnapshot({
    required this.startTime,
    required this.endTime,
    required this.generatedAt,
    required this.totals,
    required this.byBucket,
    required this.topItems,
    required this.eventsCount,
  });

  /// 查询窗口开始时间。
  final DateTime startTime;

  /// 查询窗口结束时间。
  final DateTime endTime;

  /// 快照生成时间。
  final DateTime generatedAt;

  /// 窗口内整体流量、次数、失败、重试等汇总。
  final Map<String, dynamic> totals;

  /// 按 TrafficBucket 聚合后的诊断汇总。
  final Map<String, Map<String, dynamic>> byBucket;

  /// 按总流量降序排列的来源列表，用于快速定位高流量来源。
  final List<Map<String, dynamic>> topItems;

  /// 参与聚合的原始诊断事件数量。
  final int eventsCount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'startMillis': startTime.millisecondsSinceEpoch,
      'endMillis': endTime.millisecondsSinceEpoch,
      'generatedAtMillis': generatedAt.millisecondsSinceEpoch,
      'totals': totals,
      'byBucket': byBucket,
      'topItems': topItems,
      'eventsCount': eventsCount,
    };
  }
}

/// 一条事件级诊断记录。
///
/// 只保存排查必需字段，不保存请求体、响应体、token 等敏感信息。
class _TrafficDiagnosisEvent {
  _TrafficDiagnosisEvent({
    required this.timestampMillis,
    required this.bucket,
    required this.label,
    required this.host,
    required this.accuracy,
    this.source = '',
    this.uploadBytes = 0,
    this.downloadBytes = 0,
    this.requestCount = 0,
    this.failureCount = 0,
    this.retryCount = 0,
    this.rapidRepeatCount = 0,
    this.cacheHitCount = 0,
    this.cacheMissCount = 0,
    this.responseFieldCount = 0,
    this.durationMillis,
    this.statusCode,
    this.normalizedUrl,
    this.note,
  });

  /// 事件发生时间，毫秒时间戳。
  final int timestampMillis;

  /// 流量来源大类，例如 api、resource、webSocket、rtcAudio。
  final TrafficBucket bucket;

  /// 可读来源标识，例如接口 path、资源 label、长连 channel、房间 ID。
  final String label;

  /// 关联域名；无域名的来源保持空字符串。
  final String host;

  /// 字节统计精度，用于区分精确、估算和仅计数。
  final TrafficAccuracy accuracy;

  /// 记录来源，例如 dio、download、upload、webSocket、rtc。
  final String source;

  /// 本事件上行字节数。
  final int uploadBytes;

  /// 本事件下行字节数。
  final int downloadBytes;

  /// 本事件代表的请求、消息或采样次数。
  final int requestCount;

  /// 本事件失败次数。
  final int failureCount;

  /// 本事件重试次数。
  final int retryCount;

  /// 短时间重复请求次数，用于识别异常轮询或重复触发。
  final int rapidRepeatCount;

  /// 缓存命中次数。
  final int cacheHitCount;

  /// 缓存未命中次数。
  final int cacheMissCount;

  /// 响应体字段数量，用于识别大结构响应。
  final int responseFieldCount;

  /// 请求耗时，主要用于 API 来源。
  final int? durationMillis;

  /// HTTP 状态码，主要用于 API 来源。
  final int? statusCode;

  /// 去掉 query/fragment 后的 URL，避免日志中包含敏感参数。
  final String? normalizedUrl;

  /// 附加说明，例如 error message、inbound/outbound、countOnly 原因。
  final String? note;

  int get totalBytes => uploadBytes + downloadBytes;

  /// 当前事件 JSON 编码后的近似大小，用于控制诊断缓存内存上限。
  int get estimatedBytes {
    return utf8.encode(jsonEncode(toJson())).length;
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'timestampMillis': timestampMillis,
      'bucket': bucket.name,
      'label': label,
      'host': host,
      'source': source,
      'uploadBytes': uploadBytes,
      'downloadBytes': downloadBytes,
      'totalBytes': totalBytes,
      'accuracy': accuracy.name,
      'requestCount': requestCount,
      'failureCount': failureCount,
      'retryCount': retryCount,
      'rapidRepeatCount': rapidRepeatCount,
      'cacheHitCount': cacheHitCount,
      'cacheMissCount': cacheMissCount,
      'responseFieldCount': responseFieldCount,
    };
    final duration = durationMillis;
    if (duration != null) {
      json['durationMillis'] = duration;
    }
    final status = statusCode;
    if (status != null) {
      json['statusCode'] = status;
    }
    final url = normalizedUrl;
    if (url != null && url.isNotEmpty) {
      json['normalizedUrl'] = url;
    }
    final noteText = note;
    if (noteText != null && noteText.isNotEmpty) {
      json['note'] = noteText;
    }
    return json;
  }
}

/// 落盘调度配置。
/// 用于声明宿主侧的落盘回调和定时落盘间隔。
class TrafficStatsPersistenceConfig {
  TrafficStatsPersistenceConfig({
    required this.onPersist,
    this.interval = const Duration(seconds: 30),
  }) : assert(interval.inMicroseconds > 0);

  /// 30 seconds is a pragmatic default for mobile buffering:
  /// it avoids excessive write amplification while bounding loss on crash.
  /// 默认 30 秒落盘一次。并检查是否有脏数据需要落盘；无变更时不会写文件
  /// 这个频率能兼顾磁盘写入次数和异常退出时的数据损失窗口。
  final Duration interval;

  /// 具体怎么落盘由宿主实现，例如写文件、数据库或自定义缓存。
  final TrafficStatsPersistCallback onPersist;
}

/// 上报调度配置。
/// 用于声明宿主侧的上报回调、定时上报间隔和每日上限。
class TrafficStatsReportingConfig {
  TrafficStatsReportingConfig({
    required this.onReport,
    this.interval = const Duration(minutes: 30),
    this.maxReportsPerDay = 3,
    this.loadReportQuota,
    this.saveReportQuota,
  })  : assert(interval.inMicroseconds > 0),
        assert(maxReportsPerDay > 0);

  /// 自动上报的时间间隔，默认 30 分钟。
  final Duration interval;

  /// 每自然日允许成功上报的最大次数，默认 3 次。
  final int maxReportsPerDay;

  /// 具体怎么上报由宿主实现。
  /// 回调会拿到当前内存快照，宿主可在本地文件缺失时直接兜底上报这份数据。
  final TrafficStatsReportCallback onReport;

  /// Loads the persisted daily report quota before checking the daily limit.
  /// 读取宿主侧持久化的当日上报配额。
  final TrafficStatsLoadReportQuotaCallback? loadReportQuota;

  /// Saves the daily report quota after a successful report.
  /// 成功上报后保存当日上报配额。
  final TrafficStatsSaveReportQuotaCallback? saveReportQuota;
}

/// In-memory store for all traffic statistics collected in the current session.
class TrafficStatsStore extends ChangeNotifier {
  TrafficStatsStore._();

  static final TrafficStatsStore I = TrafficStatsStore._();

  static const String _requestSeenKey = '_traffic_request_seen';
  static const String _responseRecordedKey = '_traffic_response_recorded';

  /// 当前会话内的全部聚合统计项。
  final Map<String, TrafficAggregate> _items = <String, TrafficAggregate>{};

  /// 记录每个接口最近一次请求时间，用于识别短时间重复请求。
  final Map<String, DateTime> _lastApiRequestAt = <String, DateTime>{};

  /// 诊断态专用的接口最近请求时间，避免诊断开启时污染原累计统计状态。
  final Map<String, DateTime> _lastDiagnosisApiRequestAt = <String, DateTime>{};

  /// 记录 RTC 房间最近一次累计收发字节数，用于计算增量。
  final Map<String, ({int tx, int rx})> _rtcTotals =
      <String, ({int tx, int rx})>{};

  /// 诊断态专用的 RTC 累计计数，用于在原统计关闭时仍能计算诊断 delta。
  final Map<String, ({int tx, int rx})> _diagnosisRtcTotals =
      <String, ({int tx, int rx})>{};

  /// 宿主侧提供的落盘配置。
  TrafficStatsPersistenceConfig? _persistenceConfig;

  /// 宿主侧提供的上报配置。
  TrafficStatsReportingConfig? _reportingConfig;

  /// 定时落盘任务。
  Timer? _persistenceTimer;

  /// 定时上报任务。
  Timer? _reportingTimer;

  /// 当前内存数据是否存在尚未落盘的变更。
  bool _dirty = false;

  /// 当前是否正在执行落盘。
  bool _isPersisting = false;

  /// 落盘过程中是否又产生了新的待落盘任务。
  bool _persistQueued = false;

  /// 当前是否正在执行上报。
  bool _isReporting = false;

  /// 上报过程中是否又收到新的上报请求。
  bool _reportQueued = false;

  /// 当前上报配额所属的自然日。
  DateTime? _reportQuotaDay;

  /// 当前诊断采集配置；为空表示不保留事件级明细。
  TrafficStatsDiagnosisConfig? _diagnosisConfig;

  /// 诊断态事件 ring buffer，只在 `_diagnosisConfig.enabled` 时追加。
  final List<_TrafficDiagnosisEvent> _diagnosisEvents =
      <_TrafficDiagnosisEvent>[];

  /// ring buffer 当前估算字节数，用于控制诊断态内存占用。
  int _diagnosisCacheBytes = 0;

  /// 当前自然日内已经成功上报的次数。
  int _reportCountToday = 0;

  /// 当前内存中的上报配额是否已经尝试从宿主持久化读取。
  bool _reportQuotaLoaded = false;

  /// 当前时间提供者，默认取系统时间，测试时可替换。
  DateTime Function() _now = DateTime.now;

  /// 当前采集开关状态。
  bool _enabled = false;

  /// 调用方提供的 App 版本，会写入快照顶层字段。
  String? _appVersion;

  /// Whether traffic collection is currently enabled.
  /// 当前是否启用了流量采集。
  bool get enabled => _enabled;

  /// Caller-provided app version included in generated snapshots.
  /// 当前快照中携带的调用方 App 版本。
  String? get appVersion => _appVersion;

  /// Enables or disables collection, and optionally clears existing stats when disabling.
  /// 开启或关闭采集，并可在关闭时清空已有统计数据。
  void setEnabled(bool value, {bool clearOnDisable = false}) {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    if (!_enabled && clearOnDisable) {
      _items.clear();
      _lastApiRequestAt.clear();
      _rtcTotals.clear();
      _markDirty();
    }
    notifyListeners();
  }

  /// Sets the caller-provided app version included in generated snapshots.
  /// 设置调用方提供的 App 版本，后续快照会写入顶层 appVersion 字段。
  void setAppVersion(String? value) {
    final next = value?.trim();
    final normalized = next == null || next.isEmpty ? null : next;
    if (_appVersion == normalized) {
      return;
    }
    _appVersion = normalized;
    _markDirty();
    notifyListeners();
  }

  /// Returns all aggregate items sorted by total traffic in descending order.
  /// 返回按总流量从高到低排序后的聚合结果列表。
  List<TrafficAggregate> get items {
    final values = _items.values.toList();
    values.sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
    return values;
  }

  /// Clears all collected statistics for the current session.
  /// 清空当前会话内已采集的全部统计数据。
  void clear() {
    _items.clear();
    _lastApiRequestAt.clear();
    _rtcTotals.clear();
    _markDirty();
    notifyListeners();
  }

  /// Restores aggregates from a previously persisted snapshot payload.
  /// 从外部快照恢复内存中的统计数据。
  void restoreFromSnapshot(TrafficStatsSnapshot snapshot,
      {bool merge = false}) {
    final restoredItems = <String, TrafficAggregate>{};
    for (final item in snapshot.items) {
      final aggregate = TrafficAggregate.fromJson(item);
      final key =
          '${aggregate.bucket.name}|${aggregate.host}|${aggregate.label}';
      restoredItems[key] = aggregate;
    }
    if (!merge) {
      _items
        ..clear()
        ..addAll(restoredItems);
      _lastApiRequestAt.clear();
      _rtcTotals.clear();
    } else {
      for (final entry in restoredItems.entries) {
        final current = _items[entry.key];
        if (current == null) {
          _items[entry.key] = entry.value;
          continue;
        }
        _mergeAggregate(current, entry.value);
      }
    }
    _dirty = false;
    notifyListeners();
  }

  /// 从 JSON 数据恢复内存中的统计快照。
  void restoreFromJson(Map<String, dynamic> json, {bool merge = false}) {
    restoreFromSnapshot(TrafficStatsSnapshot.fromJson(json), merge: merge);
  }

  /// 从当前内存数据中扣减一份已经成功上报过的快照。
  void consumeReportedSnapshot(TrafficStatsSnapshot snapshot) {
    for (final item in snapshot.items) {
      final aggregate = TrafficAggregate.fromJson(item);
      final key =
          '${aggregate.bucket.name}|${aggregate.host}|${aggregate.label}';
      final current = _items[key];
      if (current == null) {
        continue;
      }
      _subtractAggregate(current, aggregate);
      if (_isAggregateEmpty(current)) {
        _items.remove(key);
      }
    }
    _markDirty();
    notifyListeners();
  }

  /// 配置定时落盘逻辑。
  void configurePersistence(TrafficStatsPersistenceConfig? config) {
    _persistenceConfig = config;
    _persistenceTimer?.cancel();
    _persistenceTimer = null;
    if (config == null) {
      return;
    }
    _persistenceTimer = Timer.periodic(
      config.interval,
      (_) => unawaited(_flushPersistenceIfNeeded()),
    );
  }

  /// 配置定时上报逻辑。
  void configureReporting(TrafficStatsReportingConfig? config) {
    _reportingConfig = config;
    _reportingTimer?.cancel();
    _reportingTimer = null;
    _reportQuotaDay = null;
    _reportCountToday = 0;
    _reportQuotaLoaded = false;
    if (config == null) {
      return;
    }
    _reportingTimer = Timer.periodic(
      config.interval,
      (_) => unawaited(reportNow(trigger: TrafficStatsReportTrigger.scheduled)),
    );
  }

  /// 配置诊断事件采集。
  ///
  /// 每次配置都会先清空旧诊断事件，避免不同用户或不同 session 的数据混在一起。
  void configureDiagnosis(TrafficStatsDiagnosisConfig? config) {
    clearDiagnosis();
    _diagnosisConfig = config;
  }

  /// 清空诊断事件缓存，不影响原有累计统计项。
  void clearDiagnosis() {
    _diagnosisEvents.clear();
    _lastDiagnosisApiRequestAt.clear();
    _diagnosisRtcTotals.clear();
    _diagnosisCacheBytes = 0;
  }

  /// 生成指定时间窗口内的诊断聚合快照。
  ///
  /// 这里不读取原有累计 snapshot，而是只聚合 `_diagnosisEvents`，
  /// 因此可以回答“最近半小时哪些来源流量最大”。
  TrafficStatsDiagnosisSnapshot diagnosisSnapshotBetween({
    required DateTime startTime,
    required DateTime endTime,
    int topN = 50,
  }) {
    final startMillis = startTime.millisecondsSinceEpoch;
    final endMillis = endTime.millisecondsSinceEpoch;
    final events = _diagnosisEvents.where((event) {
      return event.timestampMillis >= startMillis &&
          event.timestampMillis <= endMillis;
    }).toList();
    final totals = <String, dynamic>{
      'uploadBytes': 0,
      'downloadBytes': 0,
      'totalBytes': 0,
      'requestCount': 0,
      'failureCount': 0,
      'retryCount': 0,
      'rapidRepeatCount': 0,
      'cacheHitCount': 0,
      'cacheMissCount': 0,
      'responseFieldCount': 0,
    };
    final byBucket = <String, Map<String, dynamic>>{};
    final byItem = <String, Map<String, dynamic>>{};
    for (final event in events) {
      _mergeDiagnosisTotals(totals, event);
      // 先按 bucket 汇总，方便判断 API、资源、RTC 等大类占比。
      final bucket = byBucket.putIfAbsent(
        event.bucket.name,
        _emptyDiagnosisTotals,
      );
      _mergeDiagnosisTotals(bucket, event);
      final key = '${event.bucket.name}|${event.host}|${event.label}';
      // 再按 bucket + host + label 聚合成可排查的具体来源。
      final item = byItem.putIfAbsent(key, () {
        return <String, dynamic>{
          'bucket': event.bucket.name,
          'label': event.label,
          'host': event.host,
          'source': event.source,
          'uploadBytes': 0,
          'downloadBytes': 0,
          'totalBytes': 0,
          'requestCount': 0,
          'failureCount': 0,
          'retryCount': 0,
          'rapidRepeatCount': 0,
          'cacheHitCount': 0,
          'cacheMissCount': 0,
          'responseFieldCount': 0,
          'maxDurationMillis': 0,
          'maxResponseBytes': 0,
          'accuracy': event.accuracy.name,
          'reasonHints': <String>[],
        };
      });
      _mergeDiagnosisItem(item, event);
    }
    final topItems = byItem.values.toList();
    // 按总流量降序输出，报告第一页就能看到最可能的问题来源。
    topItems.sort(
        (a, b) => (b['totalBytes'] as int).compareTo(a['totalBytes'] as int));
    for (var i = 0; i < topItems.length; i++) {
      topItems[i]['rank'] = i + 1;
      topItems[i]['reasonHints'] = _reasonHints(topItems[i]);
    }
    return TrafficStatsDiagnosisSnapshot(
      startTime: startTime,
      endTime: endTime,
      generatedAt: _now(),
      totals: totals,
      byBucket: byBucket,
      topItems: topItems.take(topN).toList(),
      eventsCount: events.length,
    );
  }

  /// 立即将当前快照交给宿主执行一次落盘。
  Future<void> persistNow() => _persistSnapshot(snapshot());

  /// 立即执行一次上报。
  /// 返回 `true` 表示本次真正触发了上报，`false` 表示未触发
  /// （例如未配置回调、命中当日上限或当前已有上报在进行中）。
  Future<bool> reportNow({
    TrafficStatsReportTrigger trigger = TrafficStatsReportTrigger.manual,
    bool ignoreDailyLimit = false,
  }) async {
    if (!_enabled) {
      return false;
    }
    final config = _reportingConfig;
    if (config == null) {
      return false;
    }
    await _loadReportQuotaIfNeeded(config);
    _resetReportQuotaIfNeeded();
    if (!ignoreDailyLimit && _reportCountToday >= config.maxReportsPerDay) {
      return false;
    }
    if (_isReporting) {
      _reportQueued = true;
      return false;
    }
    _isReporting = true;
    final reportedAt = _now();
    try {
      final nextCount =
          ignoreDailyLimit ? _reportCountToday : _reportCountToday + 1;
      final didReport = await config.onReport(
        snapshot(),
        TrafficStatsReportContext(
          trigger: trigger,
          reportedAt: reportedAt,
          dailyReportCount: nextCount,
          maxReportsPerDay: config.maxReportsPerDay,
        ),
      );
      if (!didReport) {
        return false;
      }
      if (!ignoreDailyLimit) {
        _reportCountToday = nextCount;
        await _saveReportQuota(config);
      }
      return true;
    } finally {
      _isReporting = false;
      if (_reportQueued) {
        _reportQueued = false;
        unawaited(
            reportNow(trigger: trigger, ignoreDailyLimit: ignoreDailyLimit));
      }
    }
  }

  /// Checks whether a response for the request has already been accounted for.
  /// 检查当前请求的响应是否已经被统计过。
  bool wasResponseRecorded(RequestOptions options) {
    return options.extra[_responseRecordedKey] == true;
  }

  /// Builds a read-only snapshot containing totals and flattened item data.
  /// 生成一个只读快照，包含总计信息和扁平化后的条目列表。
  TrafficStatsSnapshot snapshot() {
    final generatedAt = _now();
    final totals = <String, dynamic>{
      'uploadBytes': 0,
      'downloadBytes': 0,
      'totalBytes': 0,
      'requestCount': 0,
      'failureCount': 0,
      'retryCount': 0,
      'cacheHitCount': 0,
      'cacheMissCount': 0,
      'rapidRepeatCount': 0,
      'occurrenceCount': 0,
      'responseFieldCount': 0,
      'topLevelFieldCount': 0,
      'dataInnerFieldCount': 0,
      'arrayElementFieldCount': 0,
      'arrayElementCount': 0,
    };
    final byBucket = <String, Map<String, dynamic>>{};

    for (final item in _items.values) {
      totals['uploadBytes'] = (totals['uploadBytes'] as int) + item.uploadBytes;
      totals['downloadBytes'] =
          (totals['downloadBytes'] as int) + item.downloadBytes;
      totals['totalBytes'] = (totals['totalBytes'] as int) + item.totalBytes;
      totals['requestCount'] =
          (totals['requestCount'] as int) + item.requestCount;
      totals['failureCount'] =
          (totals['failureCount'] as int) + item.failureCount;
      totals['retryCount'] = (totals['retryCount'] as int) + item.retryCount;
      totals['cacheHitCount'] =
          (totals['cacheHitCount'] as int) + item.cacheHitCount;
      totals['cacheMissCount'] =
          (totals['cacheMissCount'] as int) + item.cacheMissCount;
      totals['rapidRepeatCount'] =
          (totals['rapidRepeatCount'] as int) + item.rapidRepeatCount;
      totals['occurrenceCount'] =
          (totals['occurrenceCount'] as int) + item.occurrenceCount;
      totals['responseFieldCount'] =
          (totals['responseFieldCount'] as int) + item.responseFieldCount;
      totals['topLevelFieldCount'] =
          (totals['topLevelFieldCount'] as int) + item.topLevelFieldCount;
      totals['dataInnerFieldCount'] =
          (totals['dataInnerFieldCount'] as int) + item.dataInnerFieldCount;
      totals['arrayElementFieldCount'] =
          (totals['arrayElementFieldCount'] as int) +
              item.arrayElementFieldCount;
      totals['arrayElementCount'] =
          (totals['arrayElementCount'] as int) + item.arrayElementCount;

      final bucket = byBucket.putIfAbsent(item.bucket.name, () {
        return <String, dynamic>{
          'uploadBytes': 0,
          'downloadBytes': 0,
          'totalBytes': 0,
          'requestCount': 0,
          'failureCount': 0,
          'retryCount': 0,
          'cacheHitCount': 0,
          'cacheMissCount': 0,
          'rapidRepeatCount': 0,
          'occurrenceCount': 0,
          'responseFieldCount': 0,
          'topLevelFieldCount': 0,
          'dataInnerFieldCount': 0,
          'arrayElementFieldCount': 0,
          'arrayElementCount': 0,
        };
      });
      bucket['uploadBytes'] = (bucket['uploadBytes'] as int) + item.uploadBytes;
      bucket['downloadBytes'] =
          (bucket['downloadBytes'] as int) + item.downloadBytes;
      bucket['totalBytes'] = (bucket['totalBytes'] as int) + item.totalBytes;
      bucket['requestCount'] =
          (bucket['requestCount'] as int) + item.requestCount;
      bucket['failureCount'] =
          (bucket['failureCount'] as int) + item.failureCount;
      bucket['retryCount'] = (bucket['retryCount'] as int) + item.retryCount;
      bucket['cacheHitCount'] =
          (bucket['cacheHitCount'] as int) + item.cacheHitCount;
      bucket['cacheMissCount'] =
          (bucket['cacheMissCount'] as int) + item.cacheMissCount;
      bucket['rapidRepeatCount'] =
          (bucket['rapidRepeatCount'] as int) + item.rapidRepeatCount;
      bucket['occurrenceCount'] =
          (bucket['occurrenceCount'] as int) + item.occurrenceCount;
      bucket['responseFieldCount'] =
          (bucket['responseFieldCount'] as int) + item.responseFieldCount;
      bucket['topLevelFieldCount'] =
          (bucket['topLevelFieldCount'] as int) + item.topLevelFieldCount;
      bucket['dataInnerFieldCount'] =
          (bucket['dataInnerFieldCount'] as int) + item.dataInnerFieldCount;
      bucket['arrayElementFieldCount'] =
          (bucket['arrayElementFieldCount'] as int) +
              item.arrayElementFieldCount;
      bucket['arrayElementCount'] =
          (bucket['arrayElementCount'] as int) + item.arrayElementCount;
    }

    totals['averageResponseFieldCount'] =
        (totals['occurrenceCount'] as int) == 0
            ? 0
            : ((totals['responseFieldCount'] as int) /
                (totals['occurrenceCount'] as int));
    totals['averageTopLevelFieldCount'] =
        (totals['occurrenceCount'] as int) == 0
            ? 0
            : ((totals['topLevelFieldCount'] as int) /
                (totals['occurrenceCount'] as int));
    totals['averageDataInnerFieldCount'] =
        (totals['occurrenceCount'] as int) == 0
            ? 0
            : ((totals['dataInnerFieldCount'] as int) /
                (totals['occurrenceCount'] as int));
    totals['averageArrayElementFieldCount'] =
        (totals['arrayElementCount'] as int) == 0
            ? 0
            : ((totals['arrayElementFieldCount'] as int) /
                (totals['arrayElementCount'] as int));
    totals['byBucket'] = byBucket;
    final itemList = items.map((item) => item.toJson()).toList();
    final snapshotBytes = utf8
        .encode(
          jsonEncode(<String, dynamic>{
            'generatedAt': generatedAt.toIso8601String(),
            'appVersion': _appVersion,
            'totals': totals,
            'items': itemList,
          }),
        )
        .length;
    totals['snapshotBytes'] = snapshotBytes;
    return TrafficStatsSnapshot(
      generatedAt: generatedAt,
      appVersion: _appVersion,
      totals: totals,
      items: itemList,
    );
  }

  /// Exports the current snapshot as formatted JSON text.
  /// 将当前快照导出为格式化后的 JSON 字符串。
  String exportPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(snapshot().toJson());
  }

  /// Records one HTTP request and estimates its uploaded bytes.
  /// 记录一次 HTTP 请求，并估算其上行字节数。
  void recordHttpRequest(RequestOptions options) {
    final canRecordStats = _enabled;
    final canRecordDiagnosis = _canRecordDiagnosis();
    if (!canRecordStats && !canRecordDiagnosis) {
      return;
    }

    final isRetry = options.extra[_requestSeenKey] == true;
    options.extra[_requestSeenKey] = true;
    final now = DateTime.now();

    if (canRecordStats) {
      final aggregate = _aggregateForHttp(options);
      aggregate.requestCount += 1;
      aggregate.occurrenceCount += 1;
      aggregate.uploadBytes += estimateRequestBytes(options);
      aggregate.accuracy = TrafficAccuracy.estimated;
      if (isRetry) {
        aggregate.retryCount += 1;
      }

      final lastRequestAt = _lastApiRequestAt[aggregate.label];
      if (lastRequestAt != null &&
          now.difference(lastRequestAt) <= const Duration(seconds: 5) &&
          !isRetry) {
        aggregate.rapidRepeatCount += 1;
      }
      _lastApiRequestAt[aggregate.label] = now;
      notifyListeners();
      _markDirty();
    }

    if (canRecordDiagnosis) {
      final label = '${options.method.toUpperCase()} ${options.path}';
      final host = _hostFromUrl(options.baseUrl);
      final lastRequestAt = _lastDiagnosisApiRequestAt[label];
      final rapidRepeat = lastRequestAt != null &&
          now.difference(lastRequestAt) <= const Duration(seconds: 5) &&
          !isRetry;
      _lastDiagnosisApiRequestAt[label] = now;
      if (rapidRepeat) {
        // 单独记录快速重复请求，便于诊断报告提示 repeat_request。
        _appendDiagnosisEvent(
          _TrafficDiagnosisEvent(
            timestampMillis: now.millisecondsSinceEpoch,
            bucket: TrafficBucket.api,
            label: label,
            host: host,
            accuracy: TrafficAccuracy.estimated,
            source: 'dio',
            rapidRepeatCount: 1,
          ),
        );
      }
      // 记录请求侧诊断事件，只保存估算上行字节和 path，不保存 headers/body。
      _appendDiagnosisEvent(
        _TrafficDiagnosisEvent(
          timestampMillis: now.millisecondsSinceEpoch,
          bucket: TrafficBucket.api,
          label: label,
          host: host,
          accuracy: TrafficAccuracy.estimated,
          source: 'dio',
          uploadBytes: estimateRequestBytes(options),
          requestCount: 1,
          retryCount: isRetry ? 1 : 0,
          normalizedUrl: options.path,
        ),
      );
    }
  }

  /// Records one HTTP response, including estimated download bytes and field stats.
  /// 记录一次 HTTP 响应，并统计估算下行字节数和字段信息。
  void recordHttpResponse(Response response, {required bool success}) {
    final canRecordStats = _enabled;
    final canRecordDiagnosis = _canRecordDiagnosis();
    if (!canRecordStats && !canRecordDiagnosis) {
      return;
    }
    if (canRecordStats) {
      final aggregate = _aggregateForHttp(response.requestOptions);
      aggregate.downloadBytes += estimateResponseBytes(response);
      _mergeFieldStats(aggregate, analyzeFields(response.data));
      if (!success) {
        aggregate.failureCount += 1;
      }
      notifyListeners();
      _markDirty();
    }
    if (canRecordDiagnosis) {
      final startTime = response.requestOptions.headers['startTime'];
      final now = _now();
      // 记录响应侧诊断事件，用状态码、耗时、响应大小和字段数定位大响应或慢接口。
      _appendDiagnosisEvent(
        _TrafficDiagnosisEvent(
          timestampMillis: now.millisecondsSinceEpoch,
          bucket: TrafficBucket.api,
          label:
              '${response.requestOptions.method.toUpperCase()} ${response.requestOptions.path}',
          host: _hostFromUrl(response.requestOptions.baseUrl),
          accuracy: TrafficAccuracy.estimated,
          source: 'dio',
          downloadBytes: estimateResponseBytes(response),
          failureCount: success ? 0 : 1,
          responseFieldCount:
              TrafficStatsStore.analyzeFields(response.data).totalFieldCount,
          durationMillis:
              startTime is int ? now.millisecondsSinceEpoch - startTime : null,
          statusCode: response.statusCode,
          normalizedUrl: response.requestOptions.path,
        ),
      );
    }
    response.requestOptions.extra[_responseRecordedKey] = true;
  }

  /// Records a failed HTTP request and merges response data when available.
  /// 记录一次失败的 HTTP 请求；如果有响应数据也一并合并统计。
  void recordHttpError(DioException error) {
    final canRecordStats = _enabled;
    final canRecordDiagnosis = _canRecordDiagnosis();
    if (!canRecordStats && !canRecordDiagnosis) {
      return;
    }
    if (canRecordStats) {
      final aggregate = _aggregateForHttp(error.requestOptions);
      if (!wasResponseRecorded(error.requestOptions) &&
          error.response != null) {
        aggregate.downloadBytes += estimateResponseBytes(error.response!);
        _mergeFieldStats(aggregate, analyzeFields(error.response!.data));
      }
      aggregate.failureCount += 1;
      notifyListeners();
      _markDirty();
    }
    if (canRecordDiagnosis) {
      final response = error.response;
      final startTime = error.requestOptions.headers['startTime'];
      final now = _now();
      // 错误也进入诊断明细，帮助识别失败重试导致的额外流量。
      _appendDiagnosisEvent(
        _TrafficDiagnosisEvent(
          timestampMillis: now.millisecondsSinceEpoch,
          bucket: TrafficBucket.api,
          label:
              '${error.requestOptions.method.toUpperCase()} ${error.requestOptions.path}',
          host: _hostFromUrl(error.requestOptions.baseUrl),
          accuracy: TrafficAccuracy.estimated,
          source: 'dio',
          downloadBytes: response == null ? 0 : estimateResponseBytes(response),
          failureCount: 1,
          responseFieldCount: response == null
              ? 0
              : TrafficStatsStore.analyzeFields(response.data).totalFieldCount,
          durationMillis:
              startTime is int ? now.millisecondsSinceEpoch - startTime : null,
          statusCode: response?.statusCode,
          normalizedUrl: error.requestOptions.path,
          note: error.message,
        ),
      );
    }
  }

  /// Records a download with explicit byte size information.
  /// 在已知精确或外部提供字节数时，记录一次下载流量。
  void recordDownload({
    required TrafficBucket bucket,
    required String url,
    required int bytes,
    required TrafficAccuracy accuracy,
    String? label,
    String? note,
  }) {
    final canRecordStats = _enabled;
    final canRecordDiagnosis = _canRecordDiagnosis();
    if (!canRecordStats && !canRecordDiagnosis) {
      return;
    }
    if (canRecordStats) {
      final aggregate = _aggregate(
        bucket: bucket,
        label: label ?? url,
        host: _hostFromUrl(url),
        accuracy: accuracy,
      );
      aggregate.downloadBytes += bytes;
      aggregate.requestCount += 1;
      aggregate.occurrenceCount += 1;
      aggregate.note = note ?? aggregate.note;
      aggregate.remoteUrl = url;
      notifyListeners();
      _markDirty();
    }
    if (canRecordDiagnosis) {
      // 资源下载记录归一化 URL，去掉 query 后仍能定位 CDN/文件类型。
      _appendDiagnosisEvent(
        _TrafficDiagnosisEvent(
          timestampMillis: _now().millisecondsSinceEpoch,
          bucket: bucket,
          label: label ?? _normalizeUrl(url),
          host: _hostFromUrl(url),
          accuracy: accuracy,
          source: 'download',
          downloadBytes: bytes,
          requestCount: 1,
          normalizedUrl: _normalizeUrl(url),
          note: note,
        ),
      );
    }
  }

  /// Records an upload with explicit byte size information.
  /// 在已知精确或外部提供字节数时，记录一次上传流量。
  void recordUpload({
    required TrafficBucket bucket,
    required String label,
    required int bytes,
    required TrafficAccuracy accuracy,
    String? host,
    String? note,
  }) {
    final canRecordStats = _enabled;
    final canRecordDiagnosis = _canRecordDiagnosis();
    if (!canRecordStats && !canRecordDiagnosis) {
      return;
    }
    if (canRecordStats) {
      final aggregate = _aggregate(
        bucket: bucket,
        label: label,
        host: host ?? '',
        accuracy: accuracy,
      );
      aggregate.uploadBytes += bytes;
      aggregate.requestCount += 1;
      aggregate.occurrenceCount += 1;
      aggregate.note = note ?? aggregate.note;
      notifyListeners();
      _markDirty();
    }
    if (canRecordDiagnosis) {
      // 上传仅记录 label 和字节数，不记录本地文件路径或敏感文件名。
      _appendDiagnosisEvent(
        _TrafficDiagnosisEvent(
          timestampMillis: _now().millisecondsSinceEpoch,
          bucket: bucket,
          label: label,
          host: host ?? '',
          accuracy: accuracy,
          source: 'upload',
          uploadBytes: bytes,
          requestCount: 1,
          note: note,
        ),
      );
    }
  }

  /// Records one cache hit for the specified traffic item.
  /// 为指定流量项记录一次缓存命中。
  void recordCacheHit({
    required TrafficBucket bucket,
    required String label,
    String host = '',
  }) {
    final canRecordStats = _enabled;
    final canRecordDiagnosis = _canRecordDiagnosis();
    if (!canRecordStats && !canRecordDiagnosis) {
      return;
    }
    if (canRecordStats) {
      final aggregate = _aggregate(
        bucket: bucket,
        label: label,
        host: host,
        accuracy: TrafficAccuracy.exact,
      );
      aggregate.cacheHitCount += 1;
      aggregate.occurrenceCount += 1;
      notifyListeners();
      _markDirty();
    }
    if (canRecordDiagnosis) {
      // 缓存命中/未命中单独记录，报告中可以识别 cache_miss_burst。
      _appendDiagnosisEvent(
        _TrafficDiagnosisEvent(
          timestampMillis: _now().millisecondsSinceEpoch,
          bucket: bucket,
          label: label,
          host: host,
          accuracy: TrafficAccuracy.exact,
          source: 'cache',
          cacheHitCount: 1,
        ),
      );
    }
  }

  /// Records one cache miss for the specified traffic item.
  /// 为指定流量项记录一次缓存未命中。
  void recordCacheMiss({
    required TrafficBucket bucket,
    required String label,
    String host = '',
  }) {
    final canRecordStats = _enabled;
    final canRecordDiagnosis = _canRecordDiagnosis();
    if (!canRecordStats && !canRecordDiagnosis) {
      return;
    }
    if (canRecordStats) {
      final aggregate = _aggregate(
        bucket: bucket,
        label: label,
        host: host,
        accuracy: TrafficAccuracy.exact,
      );
      aggregate.cacheMissCount += 1;
      aggregate.occurrenceCount += 1;
      notifyListeners();
      _markDirty();
    }
    if (canRecordDiagnosis) {
      // 缓存未命中会和下载事件一起解释资源流量突增原因。
      _appendDiagnosisEvent(
        _TrafficDiagnosisEvent(
          timestampMillis: _now().millisecondsSinceEpoch,
          bucket: bucket,
          label: label,
          host: host,
          accuracy: TrafficAccuracy.exact,
          source: 'cache',
          cacheMissCount: 1,
        ),
      );
    }
  }

  /// Records one WebSocket message and attributes bytes by direction.
  /// 记录一条 WebSocket 消息，并按方向计入上下行字节数。
  void recordWebSocketMessage({
    required String channel,
    required int bytes,
    required bool inbound,
    Object? payload,
  }) {
    final canRecordStats = _enabled;
    final canRecordDiagnosis = _canRecordDiagnosis();
    if (!canRecordStats && !canRecordDiagnosis) {
      return;
    }
    final fieldStats = analyzeFields(payload);
    if (canRecordStats) {
      final aggregate = _aggregate(
        bucket: TrafficBucket.webSocket,
        label: channel,
        host: '',
        accuracy: TrafficAccuracy.exact,
      );
      aggregate.requestCount += 1;
      aggregate.occurrenceCount += 1;
      if (inbound) {
        aggregate.downloadBytes += bytes;
      } else {
        aggregate.uploadBytes += bytes;
      }
      _mergeFieldStats(aggregate, fieldStats);
      notifyListeners();
      _markDirty();
    }
    if (canRecordDiagnosis) {
      // 长连按方向记录消息字节数，payload 只参与字段计数，不落完整内容。
      _appendDiagnosisEvent(
        _TrafficDiagnosisEvent(
          timestampMillis: _now().millisecondsSinceEpoch,
          bucket: TrafficBucket.webSocket,
          label: channel,
          host: '',
          accuracy: TrafficAccuracy.exact,
          source: 'webSocket',
          uploadBytes: inbound ? 0 : bytes,
          downloadBytes: inbound ? bytes : 0,
          requestCount: 1,
          responseFieldCount: fieldStats.totalFieldCount,
          note: inbound ? 'inbound' : 'outbound',
        ),
      );
    }
  }

  /// Records short-video playback as count-only because native byte stats are unavailable.
  /// 由于原生播放器无法暴露字节数，因此短视频播放只记录次数。
  void recordShortVideoPlayback(String url, {String? note}) {
    recordCountOnly(
      bucket: TrafficBucket.shortVideo,
      label: url,
      host: _hostFromUrl(url),
      remoteUrl: url,
      note: note ?? 'video_player native download bytes are not exposed',
    );
  }

  /// Records only the occurrence count for a traffic item when actual bytes are unknown.
  /// 当无法获知真实字节数时，仅记录该流量项的出现次数。
  void recordCountOnly({
    required TrafficBucket bucket,
    required String label,
    String host = '',
    String? remoteUrl,
    String? note,
  }) {
    final canRecordStats = _enabled;
    final canRecordDiagnosis = _canRecordDiagnosis();
    if (!canRecordStats && !canRecordDiagnosis) {
      return;
    }
    if (canRecordStats) {
      final aggregate = _aggregate(
        bucket: bucket,
        label: label,
        host: host,
        accuracy: TrafficAccuracy.countOnly,
      );
      aggregate.occurrenceCount += 1;
      aggregate.requestCount += 1;
      aggregate.note = note ?? aggregate.note;
      aggregate.remoteUrl = remoteUrl ?? aggregate.remoteUrl;
      notifyListeners();
      _markDirty();
    }
    if (canRecordDiagnosis) {
      // 无法拿到真实字节的来源仍记录次数，避免诊断报告完全看不到该行为。
      _appendDiagnosisEvent(
        _TrafficDiagnosisEvent(
          timestampMillis: _now().millisecondsSinceEpoch,
          bucket: bucket,
          label: label,
          host: host,
          accuracy: TrafficAccuracy.countOnly,
          source: 'countOnly',
          requestCount: 1,
          normalizedUrl: remoteUrl == null ? null : _normalizeUrl(remoteUrl),
          note: note,
        ),
      );
    }
  }

  /// Records RTC traffic using cumulative SDK counters and stores only positive deltas.
  /// 使用 SDK 的累计字节数记录 RTC 流量，并只累计正向增量。
  void recordRtcStats({
    required String roomId,
    required int txBytes,
    required int rxBytes,
  }) {
    final canRecordStats = _enabled;
    final canRecordDiagnosis = _canRecordDiagnosis();
    if (!canRecordStats && !canRecordDiagnosis) {
      return;
    }
    if (canRecordStats) {
      final previous = _rtcTotals[roomId];
      final deltaTx = previous == null ? txBytes : txBytes - previous.tx;
      final deltaRx = previous == null ? rxBytes : rxBytes - previous.rx;
      _rtcTotals[roomId] = (tx: txBytes, rx: rxBytes);

      final aggregate = _aggregate(
        bucket: TrafficBucket.rtcAudio,
        label: roomId.isEmpty ? 'global-room' : roomId,
        host: 'agora',
        accuracy: TrafficAccuracy.exact,
      );
      if (deltaTx > 0) {
        aggregate.uploadBytes += deltaTx;
      }
      if (deltaRx > 0) {
        aggregate.downloadBytes += deltaRx;
      }
      aggregate.requestCount += 1;
      aggregate.occurrenceCount += 1;
      notifyListeners();
      _markDirty();
    }
    if (canRecordDiagnosis) {
      final previous = _diagnosisRtcTotals[roomId];
      _diagnosisRtcTotals[roomId] = (tx: txBytes, rx: rxBytes);
      if (previous == null) {
        // 诊断可能在房间中途开启；第一次采样只作为基准，避免把开启前累计流量算进诊断窗口。
        return;
      }
      final deltaTx = txBytes - previous.tx;
      final deltaRx = rxBytes - previous.rx;
      // RTC SDK 给的是累计计数，这里记录正向 delta，归因到房间 ID。
      _appendDiagnosisEvent(
        _TrafficDiagnosisEvent(
          timestampMillis: _now().millisecondsSinceEpoch,
          bucket: TrafficBucket.rtcAudio,
          label: roomId.isEmpty ? 'global-room' : roomId,
          host: 'agora',
          accuracy: TrafficAccuracy.exact,
          source: 'rtc',
          uploadBytes: deltaTx > 0 ? deltaTx : 0,
          downloadBytes: deltaRx > 0 ? deltaRx : 0,
          requestCount: 1,
        ),
      );
    }
  }

  /// Estimates request size from URL, headers, and request payload.
  /// 根据 URL、请求头和请求体估算请求大小。
  static int estimateRequestBytes(RequestOptions options) {
    var total = 0;

    final uri = options.uri.toString();
    total += utf8.encode(uri).length;
    total += _estimateHeaderBytes(options.headers);

    final data = options.data;
    if (data == null) {
      return total;
    }
    if (data is String) {
      total += utf8.encode(data).length;
      return total;
    }
    if (data is List<int>) {
      total += data.length;
      return total;
    }
    if (data is FormData) {
      for (final field in data.fields) {
        total += utf8.encode(field.key).length;
        total += utf8.encode(field.value).length;
      }
      for (final file in data.files) {
        total += utf8.encode(file.key).length;
        total += file.value.length;
      }
      return total;
    }

    total += _estimateObjectBytes(data);
    return total;
  }

  /// Estimates response size from content-length or serialized response data.
  /// 根据 content-length 或响应体序列化结果估算响应大小。
  static int estimateResponseBytes(Response response) {
    final contentLengthHeader = response.headers.value('content-length');
    if (contentLengthHeader != null) {
      final contentLength = int.tryParse(contentLengthHeader);
      if (contentLength != null && contentLength >= 0) {
        return contentLength;
      }
    }

    final data = response.data;
    if (data is String) {
      return utf8.encode(data).length;
    }
    if (data is List<int>) {
      return data.length;
    }
    return _estimateObjectBytes(data);
  }

  /// Analyzes response payload structure and returns field-count statistics.
  /// 分析响应数据结构，并返回字段数量统计结果。
  static TrafficFieldStats analyzeFields(Object? data) {
    final totalFieldCount = _countFieldsRecursive(data);
    final topLevelFieldCount = data is Map ? data.length : 0;
    final dataValue = data is Map ? data['data'] : null;
    final dataInnerFieldCount = _countFieldsRecursive(dataValue);
    final arrayStats = _analyzeArrayElements(dataValue);
    return TrafficFieldStats(
      totalFieldCount: totalFieldCount,
      topLevelFieldCount: topLevelFieldCount,
      dataInnerFieldCount: dataInnerFieldCount,
      arrayElementFieldCount: arrayStats.fieldCount,
      arrayElementCount: arrayStats.elementCount,
    );
  }

  /// Recursively counts fields inside maps and iterables.
  /// 递归统计 Map 或可迭代对象中的字段数量。
  static int _countFieldsRecursive(Object? data) {
    if (data == null) {
      return 0;
    }
    if (data is Map) {
      var total = data.length;
      for (final value in data.values) {
        total += _countFieldsRecursive(value);
      }
      return total;
    }
    if (data is Iterable) {
      var total = 0;
      for (final item in data) {
        total += _countFieldsRecursive(item);
      }
      return total;
    }
    return 0;
  }

  /// Counts nested fields and element count for iterable items inside `data`.
  /// 统计 `data` 中可迭代元素里的嵌套字段数和元素个数。
  static ({int fieldCount, int elementCount}) _analyzeArrayElements(
      Object? data) {
    if (data is! Iterable) {
      return (fieldCount: 0, elementCount: 0);
    }
    var fieldCount = 0;
    var elementCount = 0;
    for (final item in data) {
      if (item is Map || item is Iterable) {
        fieldCount += _countFieldsRecursive(item);
        elementCount += 1;
      }
    }
    return (fieldCount: fieldCount, elementCount: elementCount);
  }

  /// Merges field statistics into the target aggregate.
  /// 将字段统计结果合并到目标聚合项中。
  static void _mergeFieldStats(
    TrafficAggregate aggregate,
    TrafficFieldStats stats,
  ) {
    aggregate.responseFieldCount += stats.totalFieldCount;
    aggregate.topLevelFieldCount += stats.topLevelFieldCount;
    aggregate.dataInnerFieldCount += stats.dataInnerFieldCount;
    aggregate.arrayElementFieldCount += stats.arrayElementFieldCount;
    aggregate.arrayElementCount += stats.arrayElementCount;
  }

  /// Returns the aggregate bucket used for standard HTTP requests.
  /// 返回标准 HTTP 请求对应的聚合项。
  TrafficAggregate _aggregateForHttp(RequestOptions options) {
    return _aggregate(
      bucket: TrafficBucket.api,
      label: '${options.method.toUpperCase()} ${options.path}',
      host: _hostFromUrl(options.baseUrl),
      accuracy: TrafficAccuracy.estimated,
    );
  }

  /// Returns an existing aggregate or creates one using bucket, host, and label as key.
  /// 使用 bucket、host 和 label 作为 key 获取或创建聚合项。
  TrafficAggregate _aggregate({
    required TrafficBucket bucket,
    required String label,
    required String host,
    required TrafficAccuracy accuracy,
  }) {
    final key = '${bucket.name}|$host|$label';
    final current = _items.putIfAbsent(
      key,
      () => TrafficAggregate(
        bucket: bucket,
        label: label,
        host: host,
        accuracy: accuracy,
      ),
    );
    if (accuracy.index < current.accuracy.index) {
      current.accuracy = accuracy;
    }
    return current;
  }

  void _appendDiagnosisEvent(_TrafficDiagnosisEvent event) {
    final config = _diagnosisConfig;
    if (config == null || !config.enabled) {
      return;
    }
    if (event.timestampMillis < config.startedAt.millisecondsSinceEpoch ||
        event.timestampMillis > config.expiresAt.millisecondsSinceEpoch) {
      return;
    }
    _diagnosisEvents.add(event);
    _diagnosisCacheBytes += event.estimatedBytes;
    final maxEvents = config.maxEvents <= 0 ? 5000 : config.maxEvents;
    final maxCacheBytes =
        config.maxCacheBytes <= 0 ? 1024 * 1024 : config.maxCacheBytes;
    // 诊断态只保留最近一段明细；按事件数和估算字节数双重限制内存占用。
    while (_diagnosisEvents.length > maxEvents ||
        _diagnosisCacheBytes > maxCacheBytes) {
      final removed = _diagnosisEvents.removeAt(0);
      _diagnosisCacheBytes -= removed.estimatedBytes;
      if (_diagnosisCacheBytes < 0) {
        _diagnosisCacheBytes = 0;
      }
    }
  }

  static Map<String, dynamic> _emptyDiagnosisTotals() {
    return <String, dynamic>{
      'uploadBytes': 0,
      'downloadBytes': 0,
      'totalBytes': 0,
      'requestCount': 0,
      'failureCount': 0,
      'retryCount': 0,
      'rapidRepeatCount': 0,
      'cacheHitCount': 0,
      'cacheMissCount': 0,
      'responseFieldCount': 0,
    };
  }

  static void _mergeDiagnosisTotals(
    Map<String, dynamic> target,
    _TrafficDiagnosisEvent event,
  ) {
    // 统一累加诊断事件里的排查指标，供 totals、byBucket、topItems 共用。
    target['uploadBytes'] = (target['uploadBytes'] as int) + event.uploadBytes;
    target['downloadBytes'] =
        (target['downloadBytes'] as int) + event.downloadBytes;
    target['totalBytes'] = (target['totalBytes'] as int) + event.totalBytes;
    target['requestCount'] =
        (target['requestCount'] as int) + event.requestCount;
    target['failureCount'] =
        (target['failureCount'] as int) + event.failureCount;
    target['retryCount'] = (target['retryCount'] as int) + event.retryCount;
    target['rapidRepeatCount'] =
        (target['rapidRepeatCount'] as int) + event.rapidRepeatCount;
    target['cacheHitCount'] =
        (target['cacheHitCount'] as int) + event.cacheHitCount;
    target['cacheMissCount'] =
        (target['cacheMissCount'] as int) + event.cacheMissCount;
    target['responseFieldCount'] =
        (target['responseFieldCount'] as int) + event.responseFieldCount;
  }

  static void _mergeDiagnosisItem(
    Map<String, dynamic> item,
    _TrafficDiagnosisEvent event,
  ) {
    _mergeDiagnosisTotals(item, event);
    final duration = event.durationMillis;
    if (duration != null && duration > (item['maxDurationMillis'] as int)) {
      item['maxDurationMillis'] = duration;
    }
    // maxResponseBytes 用于快速发现单次响应或下载特别大的来源。
    if (event.downloadBytes > (item['maxResponseBytes'] as int)) {
      item['maxResponseBytes'] = event.downloadBytes;
    }
    if (event.normalizedUrl != null) {
      item['normalizedUrl'] = event.normalizedUrl;
    }
    if (event.note != null) {
      item['note'] = event.note;
    }
  }

  static List<String> _reasonHints(Map<String, dynamic> item) {
    final hints = <String>[];
    // 这些 hint 是给日志阅读者的初筛标签，不参与业务逻辑判断。
    if ((item['downloadBytes'] as int) >= 1024 * 1024) {
      hints.add('large_download');
    }
    if ((item['uploadBytes'] as int) >= 1024 * 1024) {
      hints.add('large_upload');
    }
    if ((item['rapidRepeatCount'] as int) > 0) {
      hints.add('repeat_request');
    }
    if ((item['failureCount'] as int) > 0 || (item['retryCount'] as int) > 0) {
      hints.add('high_failure_retry');
    }
    if ((item['cacheMissCount'] as int) > 0 &&
        (item['cacheHitCount'] as int) == 0) {
      hints.add('cache_miss_burst');
    }
    if ((item['responseFieldCount'] as int) >= 1000) {
      hints.add('large_response_shape');
    }
    return hints;
  }

  void _markDirty() {
    _dirty = true;
  }

  /// 定时器触发时只在有脏数据时才真正调用落盘，避免空写。
  Future<void> _flushPersistenceIfNeeded() async {
    if (!_enabled || !_dirty) {
      return;
    }
    await _persistSnapshot(snapshot());
  }

  /// 将当前快照交给宿主执行一次真正的落盘。
  Future<void> _persistSnapshot(TrafficStatsSnapshot snapshot) async {
    if (!_enabled) {
      return;
    }
    final config = _persistenceConfig;
    if (config == null) {
      return;
    }
    if (_isPersisting) {
      _persistQueued = true;
      return;
    }
    _isPersisting = true;
    try {
      await config.onPersist(snapshot);
      _dirty = false;
    } finally {
      _isPersisting = false;
      if (_persistQueued) {
        _persistQueued = false;
        unawaited(_flushPersistenceIfNeeded());
      }
    }
  }

  /// 跨天后重置每日上报计数。
  void _resetReportQuotaIfNeeded() {
    final now = _now();
    final today = _dateOnly(now);
    if (_reportQuotaDay == today) {
      return;
    }
    _reportQuotaDay = today;
    _reportCountToday = 0;
  }

  Future<void> _loadReportQuotaIfNeeded(
      TrafficStatsReportingConfig config) async {
    if (_reportQuotaLoaded) {
      return;
    }
    final loadReportQuota = config.loadReportQuota;
    if (loadReportQuota == null) {
      _reportQuotaLoaded = true;
      return;
    }
    final quota = await loadReportQuota();
    _reportQuotaLoaded = true;
    if (quota == null) {
      return;
    }
    _reportQuotaDay = _dateOnly(quota.quotaDay);
    _reportCountToday = quota.reportCountToday < 0 ? 0 : quota.reportCountToday;
  }

  Future<void> _saveReportQuota(TrafficStatsReportingConfig config) async {
    final saveReportQuota = config.saveReportQuota;
    if (saveReportQuota == null || _reportQuotaDay == null) {
      return;
    }
    await saveReportQuota(
      TrafficStatsReportQuota(
        quotaDay: _reportQuotaDay!,
        reportCountToday: _reportCountToday,
      ),
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _canRecordDiagnosis() {
    final config = _diagnosisConfig;
    if (config == null || !config.enabled) {
      return false;
    }
    final now = _now();
    // 只判断诊断窗口是否有效；原累计统计由各 record 方法单独判断 `_enabled`。
    return !now.isBefore(config.startedAt) && !now.isAfter(config.expiresAt);
  }

  /// 将恢复出来的聚合项合并到现有聚合项中。
  static void _mergeAggregate(
      TrafficAggregate target, TrafficAggregate source) {
    target.accuracy = source.accuracy.index < target.accuracy.index
        ? source.accuracy
        : target.accuracy;
    target.uploadBytes += source.uploadBytes;
    target.downloadBytes += source.downloadBytes;
    target.requestCount += source.requestCount;
    target.failureCount += source.failureCount;
    target.retryCount += source.retryCount;
    target.cacheHitCount += source.cacheHitCount;
    target.cacheMissCount += source.cacheMissCount;
    target.rapidRepeatCount += source.rapidRepeatCount;
    target.occurrenceCount += source.occurrenceCount;
    target.responseFieldCount += source.responseFieldCount;
    target.topLevelFieldCount += source.topLevelFieldCount;
    target.dataInnerFieldCount += source.dataInnerFieldCount;
    target.arrayElementFieldCount += source.arrayElementFieldCount;
    target.arrayElementCount += source.arrayElementCount;
    target.note = source.note ?? target.note;
    target.remoteUrl = source.remoteUrl ?? target.remoteUrl;
  }

  static void _subtractAggregate(
      TrafficAggregate target, TrafficAggregate source) {
    target.uploadBytes = _clampSubtract(target.uploadBytes, source.uploadBytes);
    target.downloadBytes =
        _clampSubtract(target.downloadBytes, source.downloadBytes);
    target.requestCount =
        _clampSubtract(target.requestCount, source.requestCount);
    target.failureCount =
        _clampSubtract(target.failureCount, source.failureCount);
    target.retryCount = _clampSubtract(target.retryCount, source.retryCount);
    target.cacheHitCount =
        _clampSubtract(target.cacheHitCount, source.cacheHitCount);
    target.cacheMissCount =
        _clampSubtract(target.cacheMissCount, source.cacheMissCount);
    target.rapidRepeatCount =
        _clampSubtract(target.rapidRepeatCount, source.rapidRepeatCount);
    target.occurrenceCount =
        _clampSubtract(target.occurrenceCount, source.occurrenceCount);
    target.responseFieldCount =
        _clampSubtract(target.responseFieldCount, source.responseFieldCount);
    target.topLevelFieldCount =
        _clampSubtract(target.topLevelFieldCount, source.topLevelFieldCount);
    target.dataInnerFieldCount =
        _clampSubtract(target.dataInnerFieldCount, source.dataInnerFieldCount);
    target.arrayElementFieldCount = _clampSubtract(
      target.arrayElementFieldCount,
      source.arrayElementFieldCount,
    );
    target.arrayElementCount =
        _clampSubtract(target.arrayElementCount, source.arrayElementCount);
  }

  static int _clampSubtract(int current, int subtract) {
    final next = current - subtract;
    return next < 0 ? 0 : next;
  }

  static bool _isAggregateEmpty(TrafficAggregate aggregate) {
    return aggregate.uploadBytes == 0 &&
        aggregate.downloadBytes == 0 &&
        aggregate.requestCount == 0 &&
        aggregate.failureCount == 0 &&
        aggregate.retryCount == 0 &&
        aggregate.cacheHitCount == 0 &&
        aggregate.cacheMissCount == 0 &&
        aggregate.rapidRepeatCount == 0 &&
        aggregate.occurrenceCount == 0 &&
        aggregate.responseFieldCount == 0 &&
        aggregate.topLevelFieldCount == 0 &&
        aggregate.dataInnerFieldCount == 0 &&
        aggregate.arrayElementFieldCount == 0 &&
        aggregate.arrayElementCount == 0;
  }

  @visibleForTesting

  /// 测试中注入自定义时间。
  void debugSetNow(DateTime Function() now) {
    _now = now;
  }

  @visibleForTesting

  /// 测试中手动触发一次落盘定时器逻辑。
  Future<void> debugFlushPersistenceTick() => _flushPersistenceIfNeeded();

  @visibleForTesting

  /// 测试中手动触发一次定时上报逻辑。
  Future<bool> debugRunScheduledReportTick() {
    return reportNow(trigger: TrafficStatsReportTrigger.scheduled);
  }

  /// Estimates header byte size by summing encoded key and value lengths.
  /// 通过累加请求头键和值的编码长度来估算请求头大小。
  static int _estimateHeaderBytes(Map<String, dynamic> headers) {
    var total = 0;
    headers.forEach((key, value) {
      total += utf8.encode(key).length;
      total += utf8.encode(value.toString()).length;
    });
    return total;
  }

  /// Estimates object byte size using JSON encoding with a string fallback.
  /// 优先通过 JSON 编码估算对象大小，失败时退化为字符串长度。
  static int _estimateObjectBytes(Object? data) {
    if (data == null) {
      return 0;
    }
    try {
      return utf8.encode(jsonEncode(data)).length;
    } catch (_) {
      return utf8.encode(data.toString()).length;
    }
  }

  /// Extracts the host part from a URL string.
  /// 从 URL 字符串中提取 host 部分。
  static String _hostFromUrl(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    try {
      return Uri.parse(value).host;
    } catch (_) {
      return '';
    }
  }

  static String _normalizeUrl(String value) {
    try {
      final uri = Uri.parse(value);
      if (uri.host.isEmpty) {
        return value;
      }
      // 去掉 query/fragment，降低日志泄露参数和 token 的风险。
      return uri.replace(query: '', fragment: '').toString();
    } catch (_) {
      return value;
    }
  }
}
