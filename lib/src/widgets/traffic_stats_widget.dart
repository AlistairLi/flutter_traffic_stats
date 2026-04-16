import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/traffic_stats.dart';
import '../core/traffic_stats_overlay.dart';

const int _largeStatsWarningThreshold = 5 * 1024 * 1024;

/// 流量统计展示组件
///
/// 用于显示应用的网络流量统计数据，包括上传/下载字节数、请求次数、失败次数等。
/// 支持完整UI和悬浮UI两种展示方式。
class TrafficStatsWidget extends StatelessWidget {
  const TrafficStatsWidget({
    super.key,
    this.compact = false,
    this.maxItems = 150,
    this.showBackToFloatingButton = false,
  });

  /// 是否使用悬浮UI，默认为 false（完整面板）
  final bool compact;

  /// 最多显示的流量记录条目数，默认为 150
  final int maxItems;

  /// 是否显示切换回悬浮态的按钮，仅在全屏浮层展示时开启。
  final bool showBackToFloatingButton;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TrafficStatsStore.I,
      builder: (context, _) {
        final snapshot = TrafficStatsStore.I.snapshot();
        final items = TrafficStatsStore.I.items.take(maxItems).toList();
        final totals = snapshot.totals;
        final byBucket = (totals['byBucket'] as Map<String, dynamic>? ?? {})
            .entries
            .toList();
        final snapshotBytes = totals['snapshotBytes'] as int? ?? 0;
        final shouldSuggestClear =
            snapshotBytes >= _largeStatsWarningThreshold && items.isNotEmpty;

        if (compact) {
          return _CompactTrafficStatsWidget(totals: totals);
        }

        return Container(
          color: const Color(0xFF101418),
          child: RefreshIndicator(
            color: Colors.white,
            backgroundColor: const Color(0xFF1A222A),
            onRefresh: () async {
              await WidgetsBinding.instance.endOfFrame;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Traffic Stats',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (showBackToFloatingButton) ...[
                      _IconActionButton(
                        tooltip: 'Back to floating',
                        icon: Icons.close_fullscreen,
                        onTap: TrafficStatsOverlayController.showCompact,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Switch(
                      value: TrafficStatsStore.I.enabled,
                      onChanged: (value) {
                        TrafficStatsStore.I.setEnabled(value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total',
                        value: formatBytes(totals['totalBytes'] as int? ?? 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        title: 'Upload',
                        value: formatBytes(totals['uploadBytes'] as int? ?? 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        title: 'Download',
                        value:
                            formatBytes(totals['downloadBytes'] as int? ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Failures',
                        value: '${totals['failureCount'] ?? 0}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        title: 'Retries',
                        value: '${totals['retryCount'] ?? 0}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        title: 'Cache Hit',
                        value: '${totals['cacheHitCount'] ?? 0}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Fields',
                        value: '${totals['responseFieldCount'] ?? 0}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        title: 'Avg Fields',
                        value: _formatDecimal(
                          totals['averageResponseFieldCount'] as num? ?? 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        title: 'Stats Size',
                        value: formatBytes(snapshotBytes),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Top Fields',
                        value: _formatDecimal(
                          totals['averageTopLevelFieldCount'] as num? ?? 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        title: 'Data Fields',
                        value: _formatDecimal(
                          totals['averageDataInnerFieldCount'] as num? ?? 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        title: 'Arr Elem Avg',
                        value: _formatDecimal(
                          totals['averageArrayElementFieldCount'] as num? ?? 0,
                        ),
                      ),
                    ),
                  ],
                ),
                if (shouldSuggestClear) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x33F5A623),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0x88F5A623),
                      ),
                    ),
                    child: Text(
                      '统计数据当前约 ${formatBytes(snapshotBytes)}，已偏大；如非排查中，建议点击 “Clear” 清理，避免继续占用内存。',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in byBucket)
                      _BucketChip(
                        name: entry.key,
                        bytes: (entry.value['totalBytes'] as int?) ?? 0,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ActionButton(
                      label: 'Copy JSON',
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: TrafficStatsStore.I.exportPrettyJson(),
                          ),
                        );
                      },
                    ),
                    _ActionButton(
                      label: 'Clear',
                      onTap: TrafficStatsStore.I.clear,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Top Items (Max $maxItems items)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Text(
                    'No traffic recorded yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                for (final item in items) _TrafficRow(item: item),
                const SizedBox(height: 12),
                const Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enable controls whether traffic is recorded. HTTP/Image/File/WebSocket/OSS upload/Agora bytes are tracked in-session. Short video currently records play count and URL only. Pull down to manually refresh this list.',
                  maxLines: 10,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 悬浮UI流量统计展示组件
///
/// 展示关键流量信息：
/// - 启用状态指示器
/// - 总流量大小
/// - 失败次数和重试次数（如果有）
/// - 响应字段数量（如果有）
class _CompactTrafficStatsWidget extends StatelessWidget {
  const _CompactTrafficStatsWidget({required this.totals});

  /// 统计汇总数据，包含总字节数、失败次数、重试次数等信息
  final Map<String, dynamic> totals;

  @override
  Widget build(BuildContext context) {
    final enabled = TrafficStatsStore.I.enabled;
    final totalBytes = totals['totalBytes'] as int? ?? 0;
    final failures = totals['failureCount'] as int? ?? 0;
    final retries = totals['retryCount'] as int? ?? 0;
    final fieldCount = totals['responseFieldCount'] as int? ?? 0;

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 11,
              height: 1.1,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: enabled ? const Color(0xFF53D769) : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(enabled ? 'Traffic' : 'Traffic Off'),
                const SizedBox(width: 8),
                Flexible(child: Text(formatBytes(totalBytes))),
                if (failures > 0) ...[
                  const SizedBox(width: 8),
                  Text('F:$failures'),
                ],
                if (retries > 0) ...[
                  const SizedBox(width: 8),
                  Text('R:$retries'),
                ],
                if (fieldCount > 0) ...[
                  const SizedBox(width: 8),
                  Text('Fields:$fieldCount'),
                ],
                const SizedBox(width: 8),
                _IconActionButton(
                  tooltip: 'Expand',
                  icon: Icons.open_in_full,
                  iconSize: 16,
                  padding: const EdgeInsets.all(2),
                  onTap: () => TrafficStatsOverlayController.showExpanded(
                    context,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 统计卡片组件
class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 流量分类标签组件
///
/// 以胶囊形状显示某个流量分类（bucket）的名称和总字节数，
/// 如 "接口 1.2MB"、"图片 3.5MB" 等。
class _BucketChip extends StatelessWidget {
  const _BucketChip({required this.name, required this.bytes});

  /// 流量分类名称
  final String name;

  /// 该分类的总字节数
  final int bytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$name ${formatBytes(bytes)}',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 操作按钮组件
///
/// 用于执行流量统计相关的操作，如复制 JSON 数据、清空统计等。
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  /// 按钮显示的文本标签
  final String label;

  /// 点击按钮时的回调函数
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.iconSize = 18,
    this.padding = const EdgeInsets.all(6),
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Icon(icon, size: iconSize, color: Colors.white),
        ),
      ),
    );
  }
}

/// 流量记录行组件
///
/// 显示单条聚合流量记录的详细信息，包括：
/// - 记录标签（URL 或描述）
/// - 流量分类、上传/下载字节数、请求/失败/重试次数
/// - 缓存命中/未命中次数、快速重复次数
/// - 响应字段统计信息
/// - 附加备注（如果有）
class _TrafficRow extends StatelessWidget {
  const _TrafficRow({required this.item});

  /// 流量聚合数据项，包含完整的统计信息
  final TrafficAggregate item;

  @override
  Widget build(BuildContext context) {
    final remoteUrl = _remoteUrlForItem(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            maxLines: 3,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            // '${item.bucket.name} · up ${formatBytes(item.uploadBytes)} · down ${formatBytes(item.downloadBytes)} · req ${item.requestCount} · fail ${item.failureCount} · retry ${item.retryCount} · hit ${item.cacheHitCount} · miss ${item.cacheMissCount} · repeat ${item.rapidRepeatCount} · fields ${item.responseFieldCount} · top ${_formatDecimal(item.averageTopLevelFieldCount)} · data ${_formatDecimal(item.averageDataInnerFieldCount)} · arr ${_formatDecimal(item.averageArrayElementFieldCount)} · ${item.accuracy.name}',
            '${_bucketLabel(item.bucket)} · 上行 ${formatBytes(item.uploadBytes)} · 下行 ${formatBytes(item.downloadBytes)} · 请求 ${item.requestCount} 次 · 失败 ${item.failureCount} 次 · 重试 ${item.retryCount} 次 · 缓存命中 ${item.cacheHitCount} 次 · 缓存未命中 ${item.cacheMissCount} 次 · 快速重复 ${item.rapidRepeatCount} 次 · 响应字段总数 ${item.responseFieldCount} · 平均顶层字段 ${_formatDecimal(item.averageTopLevelFieldCount)} · 平均 data 内字段 ${_formatDecimal(item.averageDataInnerFieldCount)} · 平均数组元素字段 ${_formatDecimal(item.averageArrayElementFieldCount)} · 精度 ${_accuracyLabel(item.accuracy)}',
            maxLines: 20,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
            ),
          ),
          if (remoteUrl != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Remote Path',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _openRemoteUrl(remoteUrl),
                    child: Text(
                      remoteUrl,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7DC8FF),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF7DC8FF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ActionButton(
                        label: 'Copy Path',
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: remoteUrl),
                          );
                        },
                      ),
                      _ActionButton(
                        label: 'Open in Browser',
                        onTap: () => _openRemoteUrl(remoteUrl),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (item.note?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              item.note!,
              maxLines: 4,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.white60,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _openRemoteUrl(String remoteUrl) async {
  final uri = Uri.tryParse(remoteUrl);
  if (uri == null) {
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String? _remoteUrlForItem(TrafficAggregate item) {
  if (!_supportsRemoteUrl(item.bucket)) {
    return null;
  }
  final candidate = item.remoteUrl ?? item.label;
  final uri = Uri.tryParse(candidate);
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return null;
  }
  return candidate;
}

bool _supportsRemoteUrl(TrafficBucket bucket) {
  return switch (bucket) {
    TrafficBucket.image ||
    TrafficBucket.fileDownload ||
    TrafficBucket.shortVideo ||
    TrafficBucket.resource =>
      true,
    _ => false,
  };
}

String formatBytes(int bytes) {
  if (bytes < 1024) {
    return '${bytes}B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
}

String _formatDecimal(num value) {
  return value.toStringAsFixed(value >= 100 ? 0 : 1);
}

String _bucketLabel(TrafficBucket bucket) {
  return switch (bucket) {
    TrafficBucket.api => '接口',
    TrafficBucket.image => '图片',
    TrafficBucket.fileDownload => '文件下载',
    TrafficBucket.fileUpload => '文件上传',
    TrafficBucket.webSocket => '长连接',
    TrafficBucket.rtcAudio => '实时音频',
    TrafficBucket.shortVideo => '短视频',
    TrafficBucket.resource => '资源',
    TrafficBucket.im => '即时消息',
  };
}

String _accuracyLabel(TrafficAccuracy accuracy) {
  return switch (accuracy) {
    TrafficAccuracy.exact => '精确',
    TrafficAccuracy.estimated => '估算',
    TrafficAccuracy.countOnly => '仅次数',
  };
}
