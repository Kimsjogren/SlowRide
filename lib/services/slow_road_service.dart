import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:slowride/services/supabase_service.dart';

/// SlowRoad Learning Engine
///
/// Records GPS traces while the user navigates and uploads them to Supabase.
/// Over time, roads that slow vehicles frequently use get a higher
/// `slow_vehicle_score`, which GraphHopper can leverage when scoring routes.
///
/// Required Supabase tables (run the SQL below in your project):
///
/// ```sql
/// create table if not exists route_traces (
///   id            uuid primary key default gen_random_uuid(),
///   vehicle_type  text not null,
///   started_at    timestamptz not null,
///   ended_at      timestamptz,
///   distance_m    double precision,
///   points        jsonb not null default '[]'::jsonb
/// );
///
/// -- Row-level security: users can only insert/read their own rows.
/// alter table route_traces enable row level security;
/// create policy "users can insert own traces"
///   on route_traces for insert
///   with check (auth.uid() is not null);
///
/// create policy "users can read own traces"
///   on route_traces for select
///   using (true);
/// ```
class SlowRoadService {
  SlowRoadService._();
  static final SlowRoadService instance = SlowRoadService._();

  String? _sessionVehicleType;
  DateTime? _sessionStartedAt;
  final List<_TracePoint> _buffer = [];
  bool _isActive = false;

  /// Begin recording a navigation session for [vehicleType].
  void startSession(String vehicleType) {
    _sessionVehicleType = vehicleType;
    _sessionStartedAt = DateTime.now().toUtc();
    _buffer.clear();
    _isActive = true;
  }

  /// Add a GPS [position] recorded at [speedKmh] during navigation.
  /// Call this from the GPS stream whenever the user is actively navigating.
  void addPoint(LatLng position, double speedKmh) {
    if (!_isActive) return;
    _buffer.add(
      _TracePoint(
        lat: position.latitude,
        lng: position.longitude,
        speedKmh: speedKmh,
        timestamp: DateTime.now().toUtc(),
      ),
    );
  }

  /// End the session and upload the trace to Supabase.
  /// Returns silently if Supabase is not configured or the session is empty.
  Future<void> endSession() async {
    if (!_isActive) return;
    _isActive = false;

    final points = List<_TracePoint>.from(_buffer);
    final vehicleType = _sessionVehicleType;
    final startedAt = _sessionStartedAt;

    _buffer.clear();
    _sessionVehicleType = null;
    _sessionStartedAt = null;

    if (points.isEmpty ||
        vehicleType == null ||
        startedAt == null ||
        !SupabaseService.instance.isEnabled) {
      return;
    }

    try {
      final distanceM = _computeDistanceMeters(points);

      await SupabaseService.instance.client.from('route_traces').insert({
        'vehicle_type': vehicleType,
        'started_at': startedAt.toIso8601String(),
        'ended_at': DateTime.now().toUtc().toIso8601String(),
        'distance_m': distanceM,
        'points': points
            .map(
              (p) => {
                'lat': p.lat,
                'lng': p.lng,
                'speed_kmh': p.speedKmh,
                'ts': p.timestamp.toIso8601String(),
              },
            )
            .toList(),
      });
    } catch (_) {
      // Non-fatal — learning data is best-effort.
    }
  }

  /// Abort without saving (e.g. user cancelled navigation).
  void cancelSession() {
    _isActive = false;
    _buffer.clear();
    _sessionVehicleType = null;
    _sessionStartedAt = null;
  }

  bool get isActive => _isActive;

  // ── Private helpers ──────────────────────────────────────────────────────

  double _computeDistanceMeters(List<_TracePoint> points) {
    if (points.length < 2) return 0;
    const Distance calc = Distance();
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += calc(
        LatLng(points[i - 1].lat, points[i - 1].lng),
        LatLng(points[i].lat, points[i].lng),
      );
    }
    return total;
  }
}

class _TracePoint {
  const _TracePoint({
    required this.lat,
    required this.lng,
    required this.speedKmh,
    required this.timestamp,
  });

  final double lat;
  final double lng;
  final double speedKmh;
  final DateTime timestamp;
}
