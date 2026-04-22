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

  /// 配置宿主侧的本地落盘实现。
  static void configurePersistence(TrafficStatsPersistenceConfig? config) {
    store.configurePersistence(config);
  }

  /// 配置宿主侧的上报实现与调度参数。
  static void configureReporting(TrafficStatsReportingConfig? config) {
    store.configureReporting(config);
  }

  /// 立即执行一次落盘，适合应用即将进入后台时主动调用。
  static Future<void> persistNow() {
    return store.persistNow();
  }

  /// 立即执行一次上报，适合登录成功等关键时机主动调用。
  static Future<bool> reportNow({
    TrafficStatsReportTrigger trigger = TrafficStatsReportTrigger.manual,
    bool ignoreDailyLimit = false,
  }) {
    return store.reportNow(
      trigger: trigger,
      ignoreDailyLimit: ignoreDailyLimit,
    );
  }

  /// 从已经构造好的快照对象恢复内存数据。
  static void restoreFromSnapshot(
    TrafficStatsSnapshot snapshot, {
    bool merge = false,
  }) {
    store.restoreFromSnapshot(snapshot, merge: merge);
  }

  /// 从宿主本地缓存恢复快照。
  static void restoreFromJson(Map<String, dynamic> json, {bool merge = false}) {
    store.restoreFromJson(json, merge: merge);
  }

  static void showFloatingWidget(BuildContext context) {
    TrafficStatsOverlayController.show(context);
  }

  static void hideFloatingWidget() {
    TrafficStatsOverlayController.hide();
  }
}
