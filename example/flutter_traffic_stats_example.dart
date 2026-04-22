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



  // traffic_stats_service_example.dart
  // 启动时，输入落盘和上报实现
  // NadyTrafficStatsService().configure();

  // 拿到开关配置后设置
  // NadyTrafficStatsService().setEnabled(_enableTrafficStatistics);

  // 进入首页后主动上报一次流量统计，失败不影响主流程。
  // unawaited(NadyTrafficStatsService().reportAfterEnterMainPage());

}

/// Source:
/// - `lib/pages/app_starter/nady_app_starter_provider.dart`
void projectBootExample() {
  // Enable traffic stats at app startup.
  FlutterTrafficStats.setEnabled(true);

  // Persist the in-memory snapshot every 30 seconds by default.
  // 默认情况下，每 30 秒保存一次内存中的快照。
  FlutterTrafficStats.configurePersistence(
    TrafficStatsPersistenceConfig(
      onPersist: (snapshot) async {
        // Caller owns the actual local storage implementation.
        // 调用方实现本地存储实现。

        // await yourLocalStore.write(snapshot.toJson());
      },
    ),
  );

  // Report every 30 minutes by default, capped at 3 times per day.
  // 默认情况下每 30 分钟报告一次，每天最多报告 3 次。
  FlutterTrafficStats.configureReporting(
    TrafficStatsReportingConfig(
      onReport: (snapshot, context) async {
        // Caller owns the actual upload/report implementation.
        // The callback always receives the latest in-memory snapshot.
        // 调用方负责实现上传/报告。
        // 回调函数始终会接收到最新的内存中快照。

        // await yourReporter.report(snapshot.toJson(), context.trigger.name);
      },
    ),
  );

  // Restore persisted data on startup if needed.
  // 如果需要，会在启动时恢复已保存的数据。
  // final localJson = await yourLocalStore.read();
  // if (localJson != null) {
  //   FlutterTrafficStats.restoreFromJson(localJson);
  // }

  // Trigger one report actively, for example right after login.
  // 主动触发一份报告，例如在登录后立即触发。
  // await FlutterTrafficStats.reportNow();
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
