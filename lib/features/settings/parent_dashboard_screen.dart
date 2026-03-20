import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/parent_service.dart';
import 'package:slowride/widgets/app_background.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _codeController = TextEditingController();
  int _selectedTab = 0; // 0 = map, 1 = alerts

  @override
  void initState() {
    super.initState();
    ParentService.instance.startChildTracking();
  }

  @override
  void dispose() {
    ParentService.instance.stopChildTracking();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.parentDashboardTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: l10n.parentDashboardAddChild,
            onPressed: () => _showAddChildDialog(context, l10n),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: ValueListenableBuilder<bool>(
            valueListenable: AuthService.instance.isLoggedIn,
            builder: (context, isLoggedIn, _) {
              if (!isLoggedIn) {
                return _buildLoginRequired(context, l10n);
              }
              return _buildContent(context, l10n);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginRequired(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.family_restroom, size: 80, color: Colors.white54),
            const SizedBox(height: 24),
            Text(
              l10n.parentModeLoginRequired,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C8FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(l10n.login),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        // Tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildTab(
                  icon: Icons.map,
                  label: l10n.parentDashboardMapTab,
                  isSelected: _selectedTab == 0,
                  onTap: () => setState(() => _selectedTab = 0),
                ),
              ),
              Expanded(
                child: _buildTab(
                  icon: Icons.notifications,
                  label: l10n.parentDashboardAlertsTab,
                  isSelected: _selectedTab == 1,
                  onTap: () => setState(() => _selectedTab = 1),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _selectedTab == 0
              ? _buildMapView(context, l10n)
              : _buildAlertsView(context, l10n),
        ),
      ],
    );
  }

  Widget _buildTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C8FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(BuildContext context, AppLocalizations l10n) {
    return ValueListenableBuilder<List<LinkedChild>>(
      valueListenable: ParentService.instance.linkedChildren,
      builder: (context, children, _) {
        if (children.isEmpty) {
          return _buildEmptyState(l10n);
        }

        // Calculate bounds to fit all children.
        final locations = children
            .where((c) => c.location != null)
            .map((c) => c.location!)
            .toList();

        return Column(
          children: [
            // Children list (horizontal scroll)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: children.length,
                itemBuilder: (context, index) {
                  return _buildChildCard(children[index], l10n);
                },
              ),
            ),
            // Map
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: locations.isNotEmpty
                        ? locations.first
                        : const LatLng(59.3293, 18.0686), // Stockholm default
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.kimtechtool.cruizx',
                    ),
                    MarkerLayer(
                      markers: children
                          .where((c) => c.location != null)
                          .map((child) => _buildMarker(child))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChildCard(LinkedChild child, AppLocalizations l10n) {
    final isOnline = child.isOnline;
    final isDriving = child.isDriving;

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDriving
              ? const Color(0xFF00C8FF)
              : isOnline
              ? Colors.green.withAlpha(100)
              : Colors.white24,
          width: isDriving ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDriving
                      ? const Color(0xFF00C8FF)
                      : isOnline
                      ? Colors.green
                      : Colors.grey,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  child.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (isDriving && child.speedKmh != null) ...[
            Row(
              children: [
                const Icon(Icons.speed, size: 14, color: Colors.white54),
                const SizedBox(width: 4),
                Text(
                  '${child.speedKmh!.toStringAsFixed(0)} km/h',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ] else if (isOnline) ...[
            Text(
              l10n.parentDashboardOnline,
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
          ] else ...[
            Text(
              l10n.parentDashboardOffline,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
          if (child.lastUpdate != null) ...[
            const SizedBox(height: 2),
            Text(
              _formatLastUpdate(child.lastUpdate!, l10n),
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Marker _buildMarker(LinkedChild child) {
    final isDriving = child.isDriving;

    return Marker(
      point: child.location!,
      width: 50,
      height: 50,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDriving
                  ? const Color(0xFF00C8FF)
                  : Colors.white.withAlpha(200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              child.displayName.length > 8
                  ? '${child.displayName.substring(0, 8)}…'
                  : child.displayName,
              style: TextStyle(
                color: isDriving ? Colors.black : Colors.black87,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isDriving ? const Color(0xFF00C8FF) : Colors.blueGrey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 4),
              ],
            ),
            child: Icon(
              isDriving ? Icons.directions_car : Icons.person,
              size: 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsView(BuildContext context, AppLocalizations l10n) {
    return ValueListenableBuilder<List<ParentAlert>>(
      valueListenable: ParentService.instance.alerts,
      builder: (context, alertsList, _) {
        if (alertsList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: Colors.white38,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.parentDashboardNoAlerts,
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: alertsList.length,
          itemBuilder: (context, index) {
            final alert = alertsList[index];
            return _buildAlertCard(alert, l10n);
          },
        );
      },
    );
  }

  Widget _buildAlertCard(ParentAlert alert, AppLocalizations l10n) {
    final isSpeeding = alert.type == 'speeding';
    final isNight = alert.type == 'night_driving';

    IconData icon;
    Color color;
    String title;
    String subtitle;

    if (isSpeeding) {
      icon = Icons.speed;
      color = Colors.orangeAccent;
      final speed = (alert.data['speed_kmh'] as num?)?.toInt() ?? 0;
      final limit = (alert.data['limit_kmh'] as num?)?.toInt() ?? 30;
      title = l10n.parentDashboardSpeedingAlert;
      subtitle = l10n.parentDashboardSpeedingDetail(
        alert.childName,
        speed,
        limit,
      );
    } else if (isNight) {
      icon = Icons.nightlight_round;
      color = Colors.blueAccent;
      title = l10n.parentDashboardNightAlert;
      subtitle = l10n.parentDashboardNightDetail(alert.childName);
    } else {
      icon = Icons.warning;
      color = Colors.yellow;
      title = alert.type;
      subtitle = alert.childName;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAlertTime(alert.createdAt),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_search, size: 80, color: Colors.white38),
            const SizedBox(height: 24),
            Text(
              l10n.parentDashboardNoChildren,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.parentDashboardNoChildrenHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C8FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.person_add),
              label: Text(l10n.parentDashboardAddChild),
              onPressed: () => _showAddChildDialog(context, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddChildDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    _codeController.clear();

    // Capture messenger before async gaps.
    final messenger = ScaffoldMessenger.of(context);
    final successMsg = l10n.parentDashboardLinkSuccess;
    final failMsg = l10n.parentDashboardLinkFailed;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          l10n.parentDashboardEnterCode,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.parentDashboardEnterCodeHint,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'ABC123',
                hintStyle: TextStyle(
                  color: Colors.white.withAlpha(50),
                  fontSize: 24,
                  letterSpacing: 8,
                ),
                filled: true,
                fillColor: Colors.white.withAlpha(15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00C8FF)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C8FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.parentDashboardLink),
          ),
        ],
      ),
    );

    if (result == true && _codeController.text.length == 6) {
      final success = await ParentService.instance.linkToChildWithCode(
        _codeController.text,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(success ? successMsg : failMsg)),
      );
    }
  }

  String _formatLastUpdate(DateTime time, AppLocalizations l10n) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) {
      return l10n.alertTimeJustNow;
    } else if (diff.inMinutes < 60) {
      return l10n.alertTimeMinutes(diff.inMinutes);
    } else {
      return l10n.alertTimeHours(diff.inHours);
    }
  }

  String _formatAlertTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
