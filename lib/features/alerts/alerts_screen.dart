import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/features/alerts/alerts_controller.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/models/alert_model.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/widgets/app_background.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final AlertsController _controller = AlertsController();

  List<AlertModel> _alerts = const [];
  bool _loading = true;
  LatLng? _myPosition;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _init();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
      _myPosition = LatLng(pos.latitude, pos.longitude);
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    final center = _myPosition ?? const LatLng(59.3293, 18.0686);
    final alerts = await _controller.fetchNearby(center);
    if (!mounted) return;
    setState(() {
      _alerts = alerts;
      _loading = false;
    });
  }

  Future<void> _showReportSheet() async {
    final isLoggedIn = AuthService.instance.isLoggedIn.value;
    if (!isLoggedIn) {
      _showMustLoginSnack();
      return;
    }
    if (_myPosition == null) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.alertGpsUnavailable)));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ReportSheet(
        position: _myPosition!,
        controller: _controller,
        onSubmitted: _load,
      ),
    );
  }

  void _showMustLoginSnack() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.alertMustBeLoggedIn),
        backgroundColor: const Color(0xFF1E6BFF),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFFB800),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(context)!.alertsTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E6BFF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_alert_rounded, size: 18),
                  label: Text(AppLocalizations.of(context)!.alertReportButton),
                  onPressed: _showReportSheet,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              AppLocalizations.of(context)!.alertsScreenSubtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E6BFF)),
                  )
                : _alerts.isEmpty
                ? _EmptyState(onReport: _showReportSheet)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      itemCount: _alerts.length,
                      itemBuilder: (ctx, i) => _AlertTile(
                        alert: _alerts[i],
                        myPosition: _myPosition,
                        controller: _controller,
                        onUpvoted: _load,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Alert tile ────────────────────────────────────────────────────────────

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.myPosition,
    required this.controller,
    required this.onUpvoted,
  });

  final AlertModel alert;
  final LatLng? myPosition;
  final AlertsController controller;
  final VoidCallback onUpvoted;

  Color _bgColor(AlertType t) => switch (t) {
    AlertType.police => const Color(0xFF1565C0),
    AlertType.roadwork => const Color(0xFFE65100),
    AlertType.accident => const Color(0xFFC62828),
    AlertType.trafficJam => const Color(0xFFF57F17),
    AlertType.speedCamera => const Color(0xFF6A1B9A),
    AlertType.narrowRoad => const Color(0xFF00695C),
    AlertType.steepHill => const Color(0xFF37474F),
    AlertType.speedBump => const Color(0xFFFF7A00),
    AlertType.meetup => const Color(0xFF1E88E5),
    AlertType.parking => const Color(0xFF0277BD),
    AlertType.foodStop => const Color(0xFFEF6C00),
    AlertType.charging => const Color(0xFF00A86B),
    AlertType.hangout => const Color(0xFFFFB300),
    _ => const Color(0xFF4A148C),
  };

  String _timeAgo(DateTime dt, AppLocalizations l10n) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return l10n.alertTimeJustNow;
    if (diff.inMinutes < 60) {
      return l10n.alertTimeMinutes(diff.inMinutes.toString());
    }
    return l10n.alertTimeHours(diff.inHours.toString());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dist = myPosition != null ? alert.distanceTo(myPosition!) : null;
    final distStr = dist == null
        ? ''
        : dist < 1000
        ? '${dist.round()} m'
        : '${(dist / 1000).toStringAsFixed(1)} km';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _bgColor(alert.type).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _bgColor(alert.type),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(alert.type.emoji, style: const TextStyle(fontSize: 22)),
          ),
        ),
        title: Text(
          alert.type.localizedLabel(l10n),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alert.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  alert.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _timeAgo(alert.createdAt, l10n),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                if (distStr.isNotEmpty) ...[
                  const Text(' · ', style: TextStyle(color: Colors.white38)),
                  Text(
                    distStr,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: GestureDetector(
          onTap: () async {
            await controller.upvote(alert.id);
            onUpvoted();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.thumb_up_alt_rounded,
                color: Color(0xFF3AA8FF),
                size: 18,
              ),
              Text(
                '${alert.upvotes}',
                style: const TextStyle(
                  color: Color(0xFF3AA8FF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReport});
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF00C896),
            size: 56,
          ),
          const SizedBox(height: 14),
          Text(
            l10n.alertsEmptyTitle,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.alertsEmptySubtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E6BFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_alert_rounded),
            label: Text(l10n.reportAlertTitle),
            onPressed: onReport,
          ),
        ],
      ),
    );
  }
}

// ─── Report bottom sheet ───────────────────────────────────────────────────

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.position,
    required this.controller,
    required this.onSubmitted,
  });

  final LatLng position;
  final AlertsController controller;
  final VoidCallback onSubmitted;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  AlertType? _selected;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_selected == null) return;
    setState(() => _submitting = true);
    try {
      await widget.controller.submit(
        type: _selected!,
        position: widget.position,
        description: '',
      );
      if (!mounted) return;
      widget.onSubmitted();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(_selected!.emoji),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.alertReportedSuccess,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0A7E3F),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Builder(
              builder: (ctx) {
                final l10n = AppLocalizations.of(ctx)!;
                return Text(
                  l10n.alertReportQuestion,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Builder(
              builder: (ctx) {
                final l10n = AppLocalizations.of(ctx)!;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AlertType.values.map((t) {
                    final sel = _selected == t;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF1E6BFF)
                              : Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF1E6BFF)
                                : Colors.white24,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(t.emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Text(
                              t.localizedLabel(l10n),
                              style: TextStyle(
                                color: sel ? Colors.white : Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (ctx) {
                final l10n = AppLocalizations.of(ctx)!;
                return SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _selected != null
                          ? const Color(0xFF1E6BFF)
                          : Colors.white24,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _selected == null || _submitting
                        ? null
                        : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            l10n.reportAlertSubmit,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
