import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_traffic_stats_plus/flutter_traffic_stats_plus.dart';

void main() {
  final store = TrafficStatsStore.I;
  DateTime now = DateTime(2026, 1, 1, 9);

  setUp(() {
    now = DateTime(2026, 1, 1, 9);
    store.clear();
    store.setEnabled(true);
    store.configurePersistence(null);
    store.configureReporting(null);
    store.setAppVersion(null);
    store.debugSetNow(() => now);
    store.restoreFromSnapshot(store.snapshot());
  });

  test('snapshot includes caller-provided app version', () {
    FlutterTrafficStats.setAppVersion('  1.2.3+45  ');

    final snapshot = store.snapshot();
    final json = snapshot.toJson();
    final restored = TrafficStatsSnapshot.fromJson(json);

    expect(snapshot.appVersion, '1.2.3+45');
    expect(json['appVersion'], '1.2.3+45');
    expect(restored.appVersion, '1.2.3+45');
    expect(json.keys.toList().take(2), ['generatedAt', 'appVersion']);
  });

  test('snapshot includes estimated stats size', () {
    store.recordDownload(
      bucket: TrafficBucket.image,
      url: 'https://cdn.example.com/image.png',
      bytes: 2048,
      accuracy: TrafficAccuracy.exact,
    );

    final snapshot = store.snapshot();

    expect(snapshot.totals['snapshotBytes'], isA<int>());
    expect(snapshot.totals['snapshotBytes'], greaterThan(0));
  });

  test('recorded asset traffic retains remote url', () {
    store.recordDownload(
      bucket: TrafficBucket.resource,
      url: 'https://cdn.example.com/resource.json',
      label: 'homepage-feed',
      bytes: 1024,
      accuracy: TrafficAccuracy.exact,
    );

    final item = store.items.single;

    expect(item.label, 'homepage-feed');
    expect(item.remoteUrl, 'https://cdn.example.com/resource.json');
  });

  test('dirty stats are flushed through caller persistence callback', () async {
    final persisted = <TrafficStatsSnapshot>[];
    store.configurePersistence(
      TrafficStatsPersistenceConfig(
        interval: const Duration(seconds: 30),
        onPersist: persisted.add,
      ),
    );

    await store.debugFlushPersistenceTick();
    expect(persisted, isEmpty);

    store.recordDownload(
      bucket: TrafficBucket.image,
      url: 'https://cdn.example.com/banner.png',
      bytes: 512,
      accuracy: TrafficAccuracy.exact,
    );

    await store.debugFlushPersistenceTick();
    expect(persisted, hasLength(1));
    expect(persisted.single.totals['downloadBytes'], 512);

    await store.debugFlushPersistenceTick();
    expect(persisted, hasLength(1));
  });

  test('scheduled reporting obeys per-day quota and resets next day', () async {
    final reports = <TrafficStatsReportContext>[];
    store.configureReporting(
      TrafficStatsReportingConfig(
        interval: const Duration(minutes: 30),
        maxReportsPerDay: 3,
        onReport: (snapshot, context) {
          reports.add(context);
          return true;
        },
      ),
    );
    store.recordDownload(
      bucket: TrafficBucket.resource,
      url: 'https://cdn.example.com/feed.json',
      bytes: 256,
      accuracy: TrafficAccuracy.exact,
    );

    expect(await store.debugRunScheduledReportTick(), isTrue);
    expect(await store.debugRunScheduledReportTick(), isTrue);
    expect(await store.debugRunScheduledReportTick(), isTrue);
    expect(await store.debugRunScheduledReportTick(), isFalse);
    expect(reports.map((item) => item.dailyReportCount), [1, 2, 3]);
    expect(
        reports.every(
            (item) => item.trigger == TrafficStatsReportTrigger.scheduled),
        isTrue);

    now = now.add(const Duration(days: 1));

    expect(await store.debugRunScheduledReportTick(), isTrue);
    expect(reports.last.dailyReportCount, 1);
  });

  test('manual report exposes in-memory snapshot to caller', () async {
    late TrafficStatsSnapshot reportedSnapshot;
    late TrafficStatsReportContext reportedContext;
    store.configureReporting(
      TrafficStatsReportingConfig(
        onReport: (snapshot, context) {
          reportedSnapshot = snapshot;
          reportedContext = context;
          return true;
        },
      ),
    );
    store.recordUpload(
      bucket: TrafficBucket.fileUpload,
      label: 'avatar',
      bytes: 4096,
      accuracy: TrafficAccuracy.exact,
    );

    final didReport = await FlutterTrafficStats.reportNow();

    expect(didReport, isTrue);
    expect(reportedContext.trigger, TrafficStatsReportTrigger.manual);
    expect(reportedSnapshot.totals['uploadBytes'], 4096);
    expect(reportedSnapshot.items, isNotEmpty);
  });

  test('count-only and rtc stats are included in persisted snapshot', () async {
    final persisted = <TrafficStatsSnapshot>[];
    store.configurePersistence(
      TrafficStatsPersistenceConfig(
        onPersist: persisted.add,
      ),
    );

    store.recordCountOnly(
      bucket: TrafficBucket.shortVideo,
      label: 'video-1',
      remoteUrl: 'https://cdn.example.com/video.mp4',
    );
    store.recordRtcStats(
      roomId: 'room-1',
      txBytes: 100,
      rxBytes: 200,
    );

    await store.debugFlushPersistenceTick();

    expect(persisted, hasLength(1));
    expect(persisted.single.totals['requestCount'], 2);
    expect(
      persisted.single.items.any((item) => item['bucket'] == 'shortVideo'),
      isTrue,
    );
    expect(
      persisted.single.items.any((item) => item['bucket'] == 'rtcAudio'),
      isTrue,
    );
  });

  test('disabled switch blocks reporting', () async {
    var reportCount = 0;
    store.configureReporting(
      TrafficStatsReportingConfig(
        onReport: (snapshot, context) {
          reportCount += 1;
          return true;
        },
      ),
    );
    store.recordDownload(
      bucket: TrafficBucket.api,
      url: 'https://api.example.com/feed',
      bytes: 128,
      accuracy: TrafficAccuracy.exact,
    );
    store.setEnabled(false);

    final didReport = await store.reportNow();

    expect(didReport, isFalse);
    expect(reportCount, 0);
  });

  test('report quota is restored from caller persistence', () async {
    var savedQuota = TrafficStatsReportQuota(
      quotaDay: DateTime(2026, 1, 1),
      reportCountToday: 2,
    );
    final reports = <TrafficStatsReportContext>[];
    store.configureReporting(
      TrafficStatsReportingConfig(
        maxReportsPerDay: 3,
        loadReportQuota: () => savedQuota,
        saveReportQuota: (quota) => savedQuota = quota,
        onReport: (snapshot, context) {
          reports.add(context);
          return true;
        },
      ),
    );

    expect(await store.reportNow(), isTrue);
    expect(await store.reportNow(), isFalse);
    expect(reports.map((item) => item.dailyReportCount), [3]);
    expect(savedQuota.reportCountToday, 3);

    now = DateTime(2026, 1, 2, 9);
    store.configureReporting(
      TrafficStatsReportingConfig(
        maxReportsPerDay: 3,
        loadReportQuota: () => savedQuota,
        saveReportQuota: (quota) => savedQuota = quota,
        onReport: (snapshot, context) {
          reports.add(context);
          return true;
        },
      ),
    );

    expect(await store.reportNow(), isTrue);
    expect(reports.last.dailyReportCount, 1);
    expect(savedQuota.reportCountToday, 1);
  });

  test('failed report callback does not consume daily quota', () async {
    var shouldSucceed = false;
    final reports = <TrafficStatsReportContext>[];
    store.configureReporting(
      TrafficStatsReportingConfig(
        maxReportsPerDay: 1,
        onReport: (snapshot, context) {
          reports.add(context);
          return shouldSucceed;
        },
      ),
    );

    expect(await store.reportNow(), isFalse);
    shouldSucceed = true;
    expect(await store.reportNow(), isTrue);
    expect(reports.map((item) => item.dailyReportCount), [1, 1]);
  });

  test('consume reported snapshot removes uploaded in-memory stats only', () {
    store.recordDownload(
      bucket: TrafficBucket.resource,
      url: 'https://cdn.example.com/a.json',
      bytes: 100,
      accuracy: TrafficAccuracy.exact,
      label: 'feed',
    );
    final uploadedSnapshot = store.snapshot();
    store.recordDownload(
      bucket: TrafficBucket.resource,
      url: 'https://cdn.example.com/a.json',
      bytes: 40,
      accuracy: TrafficAccuracy.exact,
      label: 'feed',
    );

    store.consumeReportedSnapshot(uploadedSnapshot);

    final item = store.items.single;
    expect(item.downloadBytes, 40);
    expect(item.requestCount, 1);
    expect(item.occurrenceCount, 1);
  });
}
