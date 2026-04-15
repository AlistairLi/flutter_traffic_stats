# flutter_traffic_stats

**A Flutter package for collecting and displaying in-app traffic statistics.**

## Features

- Track session traffic stats for requests and responses
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
import 'package:flutter_traffic_stats/flutter_traffic_stats.dart';
```

Enable or disable traffic collection:

```dart
FlutterTrafficStats.setEnabled(true);
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
