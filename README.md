# flutter_traffic_stats

**A Flutter package for collecting and displaying in-app traffic statistics.**

## Features

- Track session traffic stats for requests and responses
- Persist in-memory stats through a caller-provided local storage callback
- Auto-report stats through a caller-provided upload callback
- View traffic data with a built-in stats page and widget
- Control stats collection and floating widget visibility in app

## Installation

Add the dependency in `pubspec.yaml`:

```yaml
dependencies:
  flutter_traffic_stats: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Usage

Import the package:

```dart
import 'package:flutter_traffic_stats/flutter_traffic_stats_plus.dart';
```

Enable or disable traffic collection:

```dart
FlutterTrafficStats.setEnabled(true);
FlutterTrafficStats.setAppVersion('1.0.0+100');
```

Configure persistence and reporting:

```dart
FlutterTrafficStats.configurePersistence(
  TrafficStatsPersistenceConfig(
    // Default is 30 seconds, which balances write frequency and data loss.
    onPersist: (snapshot) async {
      await saveTrafficStatsToLocal(snapshot.toJson());
    },
  ),
);

FlutterTrafficStats.configureReporting(
  TrafficStatsReportingConfig(
    // Default is every 30 minutes, with at most 3 reports per day.
    onReport: (snapshot, context) async {
      await uploadTrafficStats(snapshot.toJson(), trigger: context.trigger.name);
      return true;
    },
    loadReportQuota: loadTrafficStatsReportQuota,
    saveReportQuota: saveTrafficStatsReportQuota,
  ),
);
```

Restore from local storage on app startup:

```dart
final json = await loadTrafficStatsFromLocal();
if (json != null) {
  FlutterTrafficStats.restoreFromJson(json);
}
```

Trigger one manual report, for example after login:

```dart
await FlutterTrafficStats.reportNow();
```

Open the built-in stats page:

```dart
Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => const TrafficStatsPage(),
  ),
);
```

Show the floating stats widget:

```dart
FlutterTrafficStats.showFloatingWidget(context);
```

## Example

See the `example` directory for a complete sample app.
