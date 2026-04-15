import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/traffic_stats.dart';

class TrafficStatsWidget extends StatelessWidget {
  const TrafficStatsWidget({
    super.key,
    this.compact = false,
    this.maxItems = 100,
  });

  final bool compact;
  final int maxItems;

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

        if (compact) {
          return _CompactTrafficStatsWidget(totals: totals);
        }

        return Container(
          color: const Color(0xFF101418),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      value: formatBytes(totals['downloadBytes'] as int? ?? 0),
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
                  const Expanded(child: SizedBox()),
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
                            text: TrafficStatsStore.I.exportPrettyJson()),
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
              const Text(
                'Top Items',
                style: TextStyle(
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
                'Enable controls whether traffic is recorded. HTTP/Image/File/WebSocket/OSS upload/Agora bytes are tracked in-session. Short video currently records play count and URL only.',
                maxLines: 10,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactTrafficStatsWidget extends StatelessWidget {
  const _CompactTrafficStatsWidget({required this.totals});

  final Map<String, dynamic> totals;

  @override
  Widget build(BuildContext context) {
    final enabled = TrafficStatsStore.I.enabled;
    final totalBytes = totals['totalBytes'] as int? ?? 0;
    final failures = totals['failureCount'] as int? ?? 0;
    final retries = totals['retryCount'] as int? ?? 0;
    final fieldCount = totals['responseFieldCount'] as int? ?? 0;

    return IgnorePointer(
      ignoring: true,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
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
                  Text(formatBytes(totalBytes)),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

class _BucketChip extends StatelessWidget {
  const _BucketChip({required this.name, required this.bytes});

  final String name;
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
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

class _TrafficRow extends StatelessWidget {
  const _TrafficRow({required this.item});

  final TrafficAggregate item;

  @override
  Widget build(BuildContext context) {
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
            maxLines: 5,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
            ),
          ),
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
