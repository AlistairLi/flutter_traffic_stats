import 'package:flutter/material.dart';

import '../widgets/traffic_stats_widget.dart';

class TrafficStatsOverlayController {
  TrafficStatsOverlayController._();

  static OverlayEntry? _entry;
  static final ValueNotifier<bool> visibility = ValueNotifier<bool>(false);

  static bool get isShowing => _entry != null;

  static void show(BuildContext context) {
    if (_entry != null) {
      return;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    _entry = OverlayEntry(
      builder: (_) {
        return const Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: TrafficStatsWidget(compact: true, maxItems: 0),
          ),
        );
      },
    );
    overlay.insert(_entry!);
    visibility.value = true;
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
    visibility.value = false;
  }
}
