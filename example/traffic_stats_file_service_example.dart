// import 'dart:async';
//
// import 'package:flutter_cache_manager/flutter_cache_manager.dart';
//
// import '../core/traffic_stats.dart';
//
// /// Wraps a [FileService] and records downloaded bytes into [TrafficStatsStore].
// ///
// /// This is intended for integrations such as `cached_network_image`, which
// /// fetch remote files through `flutter_cache_manager`.
// class TrafficStatsFileService extends FileService {
//   TrafficStatsFileService({
//     required FileService delegate,
//     this.bucket = TrafficBucket.image,
//     this.note,
//   }) : _delegate = delegate;
//
//   final FileService _delegate;
//   final TrafficBucket bucket;
//   final String? note;
//
//   @override
//   Future<FileServiceResponse> get(
//     String url, {
//     Map<String, String>? headers,
//   }) async {
//     final response = await _delegate.get(url, headers: headers);
//     return _TrafficStatsFileServiceResponse(
//       url: url,
//       bucket: bucket,
//       note: note,
//       delegate: response,
//     );
//   }
// }
//
// class _TrafficStatsFileServiceResponse implements FileServiceResponse {
//   _TrafficStatsFileServiceResponse({
//     required this.url,
//     required this.bucket,
//     required this.delegate,
//     this.note,
//   });
//
//   final String url;
//   final TrafficBucket bucket;
//   final String? note;
//   final FileServiceResponse delegate;
//
//   bool _recorded = false;
//
//   @override
//   Stream<List<int>> get content {
//     var bytes = 0;
//     return delegate.content.transform(
//       StreamTransformer<List<int>, List<int>>.fromHandlers(
//         handleData: (chunk, sink) {
//           bytes += chunk.length;
//           sink.add(chunk);
//         },
//         handleDone: (sink) {
//           _recordDownload(bytes);
//           sink.close();
//         },
//       ),
//     );
//   }
//
//   @override
//   int? get contentLength => delegate.contentLength;
//
//   @override
//   int get statusCode => delegate.statusCode;
//
//   @override
//   DateTime get validTill => delegate.validTill;
//
//   @override
//   String? get eTag => delegate.eTag;
//
//   @override
//   String get fileExtension => delegate.fileExtension;
//
//   void _recordDownload(int streamedBytes) {
//     if (_recorded || statusCode < 200 || statusCode >= 300) {
//       return;
//     }
//     _recorded = true;
//     final bytes = streamedBytes > 0 ? streamedBytes : (contentLength ?? 0);
//     if (bytes <= 0) {
//       return;
//     }
//     TrafficStatsStore.I.recordDownload(
//       bucket: bucket,
//       url: url,
//       bytes: bytes,
//       accuracy: TrafficAccuracy.exact,
//       note: note,
//     );
//   }
// }
