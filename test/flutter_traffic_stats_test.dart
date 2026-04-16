import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_traffic_stats/flutter_traffic_stats.dart';

void main() {
  final store = TrafficStatsStore.I;

  setUp(() {
    store.clear();
    store.setEnabled(true);
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
}
