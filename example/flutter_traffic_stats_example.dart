import 'package:flutter_traffic_stats/flutter_traffic_stats.dart';

/// This file collects every traffic-stats usage pattern found in the host app.
///
/// Rule used here:
/// - Only `flutter_traffic_stats` is imported.
/// - If a scenario depends on other packages/framework code, the snippet stays
///   commented so other projects can copy it on demand.
void main() {
  projectBootExample();
  directStoreExamples();
}

/// Source:
/// - `lib/pages/app_starter/nady_app_starter_provider.dart`
void projectBootExample() {
  // Enable traffic stats at app startup.
  FlutterTrafficStats.setEnabled(true);

  // Disable in production, or clear existing stats when turning it off.
  // FlutterTrafficStats.setEnabled(!isProdEnv);
  // FlutterTrafficStats.setEnabled(false, clearOnDisable: true);
}

/// Direct store examples copied from real project integrations.
void directStoreExamples() {
  // 1. Generic resource cache hit / miss / download.
  //
  // Source:
  // - `lib/services/cache_manager/nady_res_loader.dart`
  TrafficStatsStore.I.recordCacheHit(
    bucket: TrafficBucket.resource,
    label: 'https://cdn.example.com/resource.svga',
    host: 'memory',
  );
  TrafficStatsStore.I.recordCacheMiss(
    bucket: TrafficBucket.resource,
    label: 'https://cdn.example.com/resource.svga',
    host: 'disk',
  );
  TrafficStatsStore.I.recordDownload(
    bucket: TrafficBucket.resource,
    url: 'https://cdn.example.com/resource.svga',
    bytes: 128 * 1024,
    accuracy: TrafficAccuracy.exact,
  );

  // 2. Generic file download cache hit / miss / download.
  //
  // Source:
  // - `lib/widgets/svga_payler/nady_file_downloader.dart`
  TrafficStatsStore.I.recordCacheHit(
    bucket: TrafficBucket.fileDownload,
    label: 'https://cdn.example.com/file.zip',
    host: 'default_cache',
  );
  TrafficStatsStore.I.recordCacheMiss(
    bucket: TrafficBucket.fileDownload,
    label: 'https://cdn.example.com/file.zip',
    host: 'default_cache',
  );
  TrafficStatsStore.I.recordDownload(
    bucket: TrafficBucket.fileDownload,
    url: 'https://cdn.example.com/file.zip',
    bytes: 4 * 1024 * 1024,
    accuracy: TrafficAccuracy.exact,
  );

  // 3. Image download counted from the real response bytes.
  //
  // Source:
  // - `lib/services/cache_manager/nady_cache_manager.dart`
  TrafficStatsStore.I.recordDownload(
    bucket: TrafficBucket.image,
    url: 'https://cdn.example.com/image.webp',
    bytes: 320 * 1024,
    accuracy: TrafficAccuracy.exact,
    note: 'cached_network_image via cache manager',
  );

  // 4. WebSocket / long-link inbound message.
  //
  // Source:
  // - `lib/services/long_link/handler/nady_long_link_handler.dart`
  TrafficStatsStore.I.recordWebSocketMessage(
    channel: 'room:10001',
    bytes: 2048,
    inbound: true,
    payload: <String, dynamic>{
      'event': 'message',
      'data': <String, dynamic>{'text': 'hello'},
    },
  );

  // 5. Upload bytes, for example OSS / S3 / CDN object upload.
  //
  // Source:
  // - `lib/services/traffic_stats/traffic_aware_oss_uploader.dart`
  TrafficStatsStore.I.recordUpload(
    bucket: TrafficBucket.fileUpload,
    label: 'uploads/avatar.webp',
    host: 'oss-cn-example.aliyuncs.com',
    bytes: 512 * 1024,
    accuracy: TrafficAccuracy.exact,
  );

  // 6. RTC cumulative byte stats.
  //
  // Source:
  // - `lib/services/room_manager/rtc/agora_rtc_manager.dart`
  TrafficStatsStore.I.recordRtcStats(
    roomId: 'room-10001',
    txBytes: 1024 * 1024,
    rxBytes: 2048 * 1024,
  );

  // 7. Count-only traffic when real bytes are not available.
  //
  // This method exists in the package. The current host app uses the
  // specialized `recordShortVideoPlayback`, which internally calls it.
  TrafficStatsStore.I.recordCountOnly(
    bucket: TrafficBucket.shortVideo,
    label: 'https://cdn.example.com/video.mp4',
    host: 'cdn.example.com',
    remoteUrl: 'https://cdn.example.com/video.mp4',
    note: 'native player download bytes are not exposed',
  );
}

// ============================================================================
// UI usage
// ============================================================================

// Open the built-in traffic stats page.
//
// Source:
// - `lib/pages/settings/nady_setting_page.dart`
//
// ```dart
// Navigator.of(context).push(
//   MaterialPageRoute<void>(
//     builder: (_) => const TrafficStatsPage(),
//   ),
// );
// ```

// Show / hide the floating widget.
//
// Source:
// - `packages/flutter_traffic_stats/lib/src/pages/traffic_stats_page.dart`
//
// ```dart
// FlutterTrafficStats.showFloatingWidget(context);
// FlutterTrafficStats.hideFloatingWidget();
// final isVisible = FlutterTrafficStats.isFloatingVisible;
// final visibility = FlutterTrafficStats.floatingVisibility;
// ```

// ============================================================================
// HTTP interceptor usage
// ============================================================================

// Source:
// - `lib/services/http/request_interceptor.dart`
//
// The package depends on Dio, but this example intentionally avoids importing
// extra libraries. Copy the commented snippet into your own interceptor.
//
// ```dart
// @override
// void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
//   TrafficStatsStore.I.recordHttpRequest(options);
//   super.onRequest(options, handler);
// }
//
// @override
// void onResponse(Response response, ResponseInterceptorHandler handler) {
//   final isSuccess = response.statusCode == 200;
//   TrafficStatsStore.I.recordHttpResponse(response, success: isSuccess);
//   super.onResponse(response, handler);
// }
//
// @override
// void onError(DioException err, ErrorInterceptorHandler handler) {
//   if (!TrafficStatsStore.I.wasResponseRecorded(err.requestOptions)) {
//     TrafficStatsStore.I.recordHttpError(err);
//   }
//   super.onError(err, handler);
// }
// ```

// ============================================================================
// cached_network_image / flutter_cache_manager usage
// ============================================================================

// Source:
// - `lib/main.dart`
// - `lib/services/cache_manager/nady_cache_manager.dart`
// - `packages/flutter_traffic_stats/lib/src/integrations/traffic_stats_file_service.dart`
//
// ```dart
// CachedNetworkImageProvider.defaultCacheManager = CacheManager(
//   Config(
//     'nady_cache_manager',
//     maxNrOfCacheObjects: 1000,
//     fileService: TrafficStatsFileService(
//       delegate: YourFileService(),
//       bucket: TrafficBucket.image,
//       note: 'cached_network_image via cache manager',
//     ),
//   ),
// );
// ```

// ============================================================================
// Snapshot / export / maintenance usage
// ============================================================================

void maintenanceExamples() {
  final snapshot = TrafficStatsStore.I.snapshot();
  final items = TrafficStatsStore.I.items;
  final json = TrafficStatsStore.I.exportPrettyJson();
  final enabled = TrafficStatsStore.I.enabled;

  // Prevent unused local warnings inside the example file.
  if (snapshot.items.isNotEmpty && items.isNotEmpty && json.isNotEmpty) {
    if (!enabled) {
      TrafficStatsStore.I.setEnabled(true);
    }
  }

  // Clear all in-memory stats.
  TrafficStatsStore.I.clear();
}
