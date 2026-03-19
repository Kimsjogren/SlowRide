import 'package:latlong2/latlong.dart';
import 'package:slowride/models/alert_model.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/supabase_service.dart';

/// Community alerts controller.
///
/// Reads from and writes to the `community_alerts` Supabase table.
/// Falls back to an in-memory local list when Supabase is not configured,
/// so the feature works end-to-end even without a backend.
///
/// Required Supabase table (run once):
/// ```sql
/// create table if not exists community_alerts (
///   id          uuid primary key default gen_random_uuid(),
///   user_id     text,
///   type        text not null,
///   lat         double precision not null,
///   lng         double precision not null,
///   description text default '',
///   upvotes     integer default 0,
///   created_at  timestamptz default now()
/// );
/// alter table community_alerts enable row level security;
/// create policy "read all" on community_alerts for select using (true);
/// create policy "insert authenticated" on community_alerts for insert
///   with check (auth.uid() is not null);
/// create policy "update authenticated" on community_alerts for update
///   using (true) with check (true);
/// ```
class AlertsController {
  /// Radius around the current position to fetch alerts (degrees ≈ 50 km).
  static const double _radiusDeg = 0.45;

  // In-memory fallback when Supabase is unavailable.
  final List<AlertModel> _localAlerts = [];

  // ── Fetch ────────────────────────────────────────────────────────────────

  /// Returns all non-expired alerts within ~50 km of [center].
  Future<List<AlertModel>> fetchNearby(LatLng center) async {
    late List<AlertModel> raw;

    if (SupabaseService.instance.isEnabled) {
      try {
        final minLat = center.latitude - _radiusDeg;
        final maxLat = center.latitude + _radiusDeg;
        final minLng = center.longitude - _radiusDeg;
        final maxLng = center.longitude + _radiusDeg;

        final rows = await SupabaseService.instance.client
            .from('community_alerts')
            .select()
            .gte('lat', minLat)
            .lte('lat', maxLat)
            .gte('lng', minLng)
            .lte('lng', maxLng)
            .order('created_at', ascending: false)
            .limit(150);

        raw = (rows as List)
            .map((r) => AlertModel.fromMap(Map<String, dynamic>.from(r as Map)))
            .toList();
      } catch (_) {
        raw = List<AlertModel>.from(_localAlerts);
      }
    } else {
      raw = List<AlertModel>.from(_localAlerts);
    }

    return raw.where((a) => !a.isExpired).toList();
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  /// Reports a new community alert at [position].
  Future<AlertModel> submit({
    required AlertType type,
    required LatLng position,
    String description = '',
  }) async {
    final userId = AuthService.instance.userId.value;

    final payload = {
      'type': type.key,
      'lat': position.latitude,
      'lng': position.longitude,
      'description': description,
      'upvotes': 0,
      'user_id': userId,
    };

    if (SupabaseService.instance.isEnabled) {
      try {
        final row = await SupabaseService.instance.client
            .from('community_alerts')
            .insert(payload)
            .select()
            .single();
        return AlertModel.fromMap(Map<String, dynamic>.from(row as Map));
      } catch (_) {
        // Fall through to local fallback so report flow never hangs/fails.
      }
    }

    // Local fallback — generate a fake id so the UI can display it.
    final alert = AlertModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      position: position,
      description: description,
      upvotes: 0,
      createdAt: DateTime.now(),
      userId: userId,
    );
    _localAlerts.insert(0, alert);
    return alert;
  }

  // ── Upvote ────────────────────────────────────────────────────────────────

  /// Confirms an existing alert — increments upvotes by 1.
  Future<void> upvote(String alertId) async {
    if (SupabaseService.instance.isEnabled) {
      try {
        await SupabaseService.instance.client.rpc(
          'increment_alert_upvotes',
          params: {'alert_id': alertId},
        );
      } catch (_) {
        // RPC may not exist — fall through silently.
      }
    } else {
      final idx = _localAlerts.indexWhere((a) => a.id == alertId);
      if (idx >= 0) {
        final old = _localAlerts[idx];
        _localAlerts[idx] = AlertModel(
          id: old.id,
          type: old.type,
          position: old.position,
          description: old.description,
          upvotes: old.upvotes + 1,
          createdAt: old.createdAt,
          userId: old.userId,
        );
      }
    }
  }
}
