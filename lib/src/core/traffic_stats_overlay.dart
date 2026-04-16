import 'package:flutter/material.dart';

import '../widgets/traffic_stats_widget.dart';

enum TrafficStatsOverlayMode { compact, expanded }

class TrafficStatsOverlayController {
  TrafficStatsOverlayController._();

  static OverlayEntry? _entry;
  static final ValueNotifier<bool> visibility = ValueNotifier<bool>(false);
  static final ValueNotifier<TrafficStatsOverlayMode> mode =
      ValueNotifier<TrafficStatsOverlayMode>(TrafficStatsOverlayMode.compact);

  static bool get isShowing => _entry != null;

  static void show(BuildContext context) {
    showCompact(context);
  }

  static void showCompact([BuildContext? context]) {
    _ensureEntry(context);
    if (_entry == null) {
      return;
    }
    mode.value = TrafficStatsOverlayMode.compact;
    visibility.value = true;
  }

  static void showExpanded(BuildContext context) {
    _ensureEntry(context);
    if (_entry == null) {
      return;
    }
    mode.value = TrafficStatsOverlayMode.expanded;
    visibility.value = true;
  }

  static void _ensureEntry(BuildContext? context) {
    if (_entry != null || context == null) {
      return;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    _entry = OverlayEntry(
      builder: (_) {
        return Positioned.fill(
          child: ValueListenableBuilder<TrafficStatsOverlayMode>(
            valueListenable: mode,
            builder: (context, currentMode, _) {
              if (currentMode == TrafficStatsOverlayMode.compact) {
                return const Material(
                  type: MaterialType.transparency,
                  child: TrafficStatsWidget(compact: true, maxItems: 0),
                );
              }

              return Material(
                color: Colors.black.withValues(alpha: 0.35),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: showCompact,
                  child: SafeArea(
                    child: Center(
                      child: GestureDetector(
                        onTap: () {},
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 920),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: const TrafficStatsWidget(
                              showBackToFloatingButton: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
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
    mode.value = TrafficStatsOverlayMode.compact;
    visibility.value = false;
  }
}
