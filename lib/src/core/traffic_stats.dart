import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// High-level traffic source categories used for aggregation.
enum TrafficBucket {
  /// Standard HTTP/HTTPS API traffic.
  /// 普通 HTTP/HTTPS 接口流量。
  api,

  /// Image loading traffic.
  /// 图片加载流量。
  image,

  /// Generic file download traffic.
  /// 通用文件下载流量。
  fileDownload,

  /// Generic file upload traffic.
  /// 通用文件上传流量。
  fileUpload,

  /// WebSocket or long-link traffic.
  /// WebSocket 或长连接流量。
  webSocket,

  /// Realtime voice/audio streaming traffic.
  /// 实时语音/音频流量。
  rtcAudio,

  /// Short video playback traffic.
  /// 短视频播放流量。
  shortVideo,

  /// Other remote resource traffic.
  /// 其他远程资源流量。
  resource,

  /// Instant messaging traffic.
  /// 即时消息流量。
  im,
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
    };
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
    required this.totals,
    required this.items,
  });

  /// Time when the snapshot was generated.
  /// 快照生成时间。
  final DateTime generatedAt;

  /// Global totals summary.
  /// 全局汇总统计。
  final Map<String, dynamic> totals;

  /// Flattened aggregate item list.
  /// 扁平化的聚合项列表。
  final List<Map<String, dynamic>> items;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'generatedAt': generatedAt.toIso8601String(),
      'totals': totals,
      'items': items,
    };
  }
}

/// In-memory store for all traffic statistics collected in the current session.
class TrafficStatsStore extends ChangeNotifier {
  TrafficStatsStore._();

  static final TrafficStatsStore I = TrafficStatsStore._();

  static const String _requestSeenKey = '_traffic_request_seen';
  static const String _responseRecordedKey = '_traffic_response_recorded';

  final Map<String, TrafficAggregate> _items = <String, TrafficAggregate>{};
  final Map<String, DateTime> _lastApiRequestAt = <String, DateTime>{};
  final Map<String, ({int tx, int rx})> _rtcTotals =
      <String, ({int tx, int rx})>{};
  bool _enabled = true;

  bool get enabled => _enabled;

  void setEnabled(bool value, {bool clearOnDisable = false}) {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    if (!_enabled && clearOnDisable) {
      _items.clear();
      _lastApiRequestAt.clear();
      _rtcTotals.clear();
    }
    notifyListeners();
  }

  List<TrafficAggregate> get items {
    final values = _items.values.toList();
    values.sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
    return values;
  }

  void clear() {
    _items.clear();
    _lastApiRequestAt.clear();
    _rtcTotals.clear();
    notifyListeners();
  }

  bool wasResponseRecorded(RequestOptions options) {
    return options.extra[_responseRecordedKey] == true;
  }

  TrafficStatsSnapshot snapshot() {
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
    return TrafficStatsSnapshot(
      generatedAt: DateTime.now(),
      totals: totals,
      items: items.map((item) => item.toJson()).toList(),
    );
  }

  String exportPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(snapshot().toJson());
  }

  void recordHttpRequest(RequestOptions options) {
    if (!_enabled) {
      return;
    }
    final aggregate = _aggregateForHttp(options);
    aggregate.requestCount += 1;
    aggregate.occurrenceCount += 1;
    aggregate.uploadBytes += estimateRequestBytes(options);
    aggregate.accuracy = TrafficAccuracy.estimated;

    final isRetry = options.extra[_requestSeenKey] == true;
    if (isRetry) {
      aggregate.retryCount += 1;
    }
    options.extra[_requestSeenKey] = true;

    final lastRequestAt = _lastApiRequestAt[aggregate.label];
    final now = DateTime.now();
    if (lastRequestAt != null &&
        now.difference(lastRequestAt) <= const Duration(seconds: 5) &&
        !isRetry) {
      aggregate.rapidRepeatCount += 1;
    }
    _lastApiRequestAt[aggregate.label] = now;

    notifyListeners();
  }

  void recordHttpResponse(Response response, {required bool success}) {
    if (!_enabled) {
      return;
    }
    final aggregate = _aggregateForHttp(response.requestOptions);
    aggregate.downloadBytes += estimateResponseBytes(response);
    _mergeFieldStats(aggregate, analyzeFields(response.data));
    if (!success) {
      aggregate.failureCount += 1;
    }
    response.requestOptions.extra[_responseRecordedKey] = true;
    notifyListeners();
  }

  void recordHttpError(DioException error) {
    if (!_enabled) {
      return;
    }
    final aggregate = _aggregateForHttp(error.requestOptions);
    if (!wasResponseRecorded(error.requestOptions) && error.response != null) {
      aggregate.downloadBytes += estimateResponseBytes(error.response!);
      _mergeFieldStats(aggregate, analyzeFields(error.response!.data));
    }
    aggregate.failureCount += 1;
    notifyListeners();
  }

  void recordDownload({
    required TrafficBucket bucket,
    required String url,
    required int bytes,
    required TrafficAccuracy accuracy,
    String? label,
    String? note,
  }) {
    if (!_enabled) {
      return;
    }
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
    notifyListeners();
  }

  void recordUpload({
    required TrafficBucket bucket,
    required String label,
    required int bytes,
    required TrafficAccuracy accuracy,
    String? host,
    String? note,
  }) {
    if (!_enabled) {
      return;
    }
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
  }

  void recordCacheHit({
    required TrafficBucket bucket,
    required String label,
    String host = '',
  }) {
    if (!_enabled) {
      return;
    }
    final aggregate = _aggregate(
      bucket: bucket,
      label: label,
      host: host,
      accuracy: TrafficAccuracy.exact,
    );
    aggregate.cacheHitCount += 1;
    aggregate.occurrenceCount += 1;
    notifyListeners();
  }

  void recordCacheMiss({
    required TrafficBucket bucket,
    required String label,
    String host = '',
  }) {
    if (!_enabled) {
      return;
    }
    final aggregate = _aggregate(
      bucket: bucket,
      label: label,
      host: host,
      accuracy: TrafficAccuracy.exact,
    );
    aggregate.cacheMissCount += 1;
    aggregate.occurrenceCount += 1;
    notifyListeners();
  }

  void recordWebSocketMessage({
    required String channel,
    required int bytes,
    required bool inbound,
    Object? payload,
  }) {
    if (!_enabled) {
      return;
    }
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
    _mergeFieldStats(aggregate, analyzeFields(payload));
    notifyListeners();
  }

  void recordShortVideoPlayback(String url, {String? note}) {
    recordCountOnly(
      bucket: TrafficBucket.shortVideo,
      label: url,
      host: _hostFromUrl(url),
      note: note ?? 'video_player native download bytes are not exposed',
    );
  }

  void recordCountOnly({
    required TrafficBucket bucket,
    required String label,
    String host = '',
    String? note,
  }) {
    if (!_enabled) {
      return;
    }
    final aggregate = _aggregate(
      bucket: bucket,
      label: label,
      host: host,
      accuracy: TrafficAccuracy.countOnly,
    );
    aggregate.occurrenceCount += 1;
    aggregate.requestCount += 1;
    aggregate.note = note ?? aggregate.note;
    notifyListeners();
  }

  void recordRtcStats({
    required String roomId,
    required int txBytes,
    required int rxBytes,
  }) {
    if (!_enabled) {
      return;
    }
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
  }

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

  TrafficAggregate _aggregateForHttp(RequestOptions options) {
    return _aggregate(
      bucket: TrafficBucket.api,
      label: '${options.method.toUpperCase()} ${options.path}',
      host: _hostFromUrl(options.baseUrl),
      accuracy: TrafficAccuracy.estimated,
    );
  }

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

  static int _estimateHeaderBytes(Map<String, dynamic> headers) {
    var total = 0;
    headers.forEach((key, value) {
      total += utf8.encode(key).length;
      total += utf8.encode(value.toString()).length;
    });
    return total;
  }

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
}
