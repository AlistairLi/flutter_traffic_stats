import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/traffic_stats.dart';
import 'core/traffic_stats_overlay.dart';

class FlutterTrafficStats {
  const FlutterTrafficStats._();

  static TrafficStatsStore get store => TrafficStatsStore.I;

  static bool get isEnabled => store.enabled;

  static bool get isFloatingVisible => TrafficStatsOverlayController.isShowing;

  static ValueListenable<bool> get floatingVisibility =>
      TrafficStatsOverlayController.visibility;

  /// 应用启动时，根据环境来设置是否开启流量统计
  static void setEnabled(bool enabled, {bool clearOnDisable = false}) {
    store.setEnabled(enabled, clearOnDisable: clearOnDisable);
  }

  static void showFloatingWidget(BuildContext context) {
    TrafficStatsOverlayController.show(context);
  }

  static void hideFloatingWidget() {
    TrafficStatsOverlayController.hide();
  }
}
