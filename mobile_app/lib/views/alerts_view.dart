import 'dart:async';

import 'package:field_app/services/alerts_store.dart';
import 'package:flutter/material.dart';

/// Live alerts feed view — pulls real official alerts from NDMA, IMD,
/// USGS, OpenWeather, NASA EONET via the backend /api/v1/alerts/live
/// endpoint.
///
/// Each alert is rendered as a card with source, type, severity, time,
/// and a deep-link to the original publisher. Filter chips let the user
/// filter by source.
class AlertsView extends StatefulWidget {
  const AlertsView({super.key});

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  final AlertsStore _store = AlertsStore.instance;
  String? _activeSourceFilter;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChange);
    _store.initialize();
  }

  @override
  void dispose() {
    _store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sources = _store.sourcesAttempted.where((s) => s != 'BUNDLED_FALLBACK').toList();
    final visibleAlerts = _activeSourceFilter == null
        ? _store.alerts
        : _store.alerts.where((a) => a['source']?.toString().toUpperCase() == _activeSourceFilter!.toUpperCase()).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        title: const Text('Live Official Alerts', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF000000))),
        actions: [
          IconButton(
            icon: _store.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _store.loading ? null : () => _store.refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF9FAFB),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _store.fromCache ? const Color(0xFFCA8A04) : const Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _store.fromCache
                          ? 'Cached snapshot • last fetched ${_store.lastFetched != null ? _formatTime(_store.lastFetched!) : 'never'}'
                          : 'Live snapshot • ${_store.alerts.length} alerts from ${_store.sourcesAttempted.length} sources',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${_store.alerts.length} alerts',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
                  ),
                ],
              ),
            ),
            // Source filter chips
            if (sources.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _buildChip('All', null),
                    ...sources.map((s) => _buildChip(s, s)),
                  ],
                ),
              ),
            // Alerts list
            Expanded(
              child: visibleAlerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            _store.loading ? 'Fetching live alerts...' : 'No alerts available',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (_store.error != null) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _store.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: visibleAlerts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _buildAlertCard(visibleAlerts[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, String? source) {
    final active = _activeSourceFilter == source;
    final count = source == null
        ? _store.alerts.length
        : _store.alerts.where((a) => a['source']?.toString().toUpperCase() == source.toUpperCase()).length;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: active,
        onSelected: (_) => setState(() => _activeSourceFilter = active ? null : source),
        selectedColor: const Color(0xFF000000),
        labelStyle: TextStyle(
          color: active ? Colors.white : const Color(0xFF374151),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final source = alert['source']?.toString() ?? 'UNKNOWN';
    final type = alert['type']?.toString().replaceAll('_', ' ') ?? 'ALERT';
    final title = alert['title']?.toString() ?? 'Untitled alert';
    final summary = alert['summary']?.toString() ?? alert['description']?.toString() ?? '';
    final timestamp = alert['timestamp']?.toString() ?? '';
    final url = alert['url']?.toString();
    final severity = alert['severity']?.toString().toUpperCase() ??
        (alert['magnitude'] != null && (alert['magnitude'] as num) >= 5 ? 'HIGH' : 'MEDIUM');

    final sourceColor = _sourceColor(source);
    final sevColor = _severityColor(severity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: sourceColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  source,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: sourceColor),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: sevColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  severity,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: sevColor),
                ),
              ),
              const Spacer(),
              if (timestamp.isNotEmpty)
                Text(
                  _formatTime(DateTime.tryParse(timestamp) ?? DateTime.now()),
                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF9CA3AF)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF4B5563), height: 1.4),
            ),
          ],
          if (alert['magnitude'] != null) ...[
            const SizedBox(height: 6),
            Text(
              'Magnitude ${alert['magnitude']} • Depth ${alert['depth_km']} km',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C)),
            ),
          ],
          if (url != null && url.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                // In production: launch URL via url_launcher
              },
              child: Row(
                children: [
                  Icon(Icons.open_in_new_rounded, size: 12, color: sourceColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'View original source',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sourceColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _sourceColor(String source) {
    switch (source.toUpperCase()) {
      case 'USGS':
        return const Color(0xFFDC2626);
      case 'NASA_EONET':
        return const Color(0xFF7C3AED);
      case 'IMD':
        return const Color(0xFF0EA5E9);
      case 'NDMA':
        return const Color(0xFFD97706);
      case 'OPENWEATHER':
        return const Color(0xFF059669);
      case 'BUNDLED_FALLBACK':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFDC2626);
      case 'HIGH':
        return const Color(0xFFD97706);
      case 'MEDIUM':
        return const Color(0xFFCA8A04);
      case 'LOW':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
