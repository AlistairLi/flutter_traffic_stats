import 'package:flutter/material.dart';

import '../../flutter_traffic_stats_plus.dart';

/// A page that displays traffic stats.
class TrafficStatsPage extends StatelessWidget {
  const TrafficStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      appBar: AppBar(
        title: const Text('Traffic Stats'),
        backgroundColor: const Color(0xFF101418),
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Report now',
            onPressed: () {
              FlutterTrafficStats.reportNow(ignoreDailyLimit: true);
            },
            icon: const Icon(Icons.cloud_upload_outlined),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: FlutterTrafficStats.floatingVisibility,
            builder: (context, isVisible, _) {
              return IconButton(
                tooltip:
                    isVisible ? 'Hide floating stats' : 'Show floating stats',
                onPressed: () {
                  if (isVisible) {
                    FlutterTrafficStats.hideFloatingWidget();
                  } else {
                    FlutterTrafficStats.showFloatingWidget(context);
                  }
                },
                icon: Icon(
                  isVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              );
            },
          ),
        ],
      ),
      body: const SafeArea(child: TrafficStatsWidget()),
    );
  }
}
