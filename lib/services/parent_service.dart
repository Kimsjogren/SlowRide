import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/supabase_service.dart';

/// Configuration for parent sharing features.
class ParentShareSettings {
  const ParentShareSettings({
    this.shareLocation = true,
    this.shareSpeed = true,
    this.alertOnSpeeding = true,
    this.alertOnNightDriving = false,
    this.nightStartHour = 23,
    this.nightEndHour = 5,
    this.speedLimitKmh = 35,
  });

  final bool shareLocation;
  final bool shareSpeed;
  final bool alertOnSpeeding;
  final bool alertOnNightDriving;
  final int nightStartHour;
  final int nightEndHour;
  final double speedLimitKmh;

  Map<String, dynamic> toJson() => {
    'shareLocation': shareLocation,
    'shareSpeed': shareSpeed,
    'alertOnSpeeding': alertOnSpeeding,
    'alertOnNightDriving': alertOnNightDriving,
    'nightStartHour': nightStartHour,
    'nightEndHour': nightEndHour,
    'speedLimitKmh': speedLimitKmh,
  };

  factory ParentShareSettings.fromJson(Map<String, dynamic> json) {
    return ParentShareSettings(
      shareLocation: json['shareLocation'] as bool? ?? true,
      shareSpeed: json['shareSpeed'] as bool? ?? true,
      alertOnSpeeding: json['alertOnSpeeding'] as bool? ?? true,
      alertOnNightDriving: json['alertOnNightDriving'] as bool? ?? false,
      nightStartHour: json['nightStartHour'] as int? ?? 23,
      nightEndHour: json['nightEndHour'] as int? ?? 5,
      speedLimitKmh: (json['speedLimitKmh'] as num?)?.toDouble() ?? 35,
    );
  }

  ParentShareSettings copyWith({
    bool? shareLocation,
    bool? shareSpeed,
    bool? alertOnSpeeding,
    bool? alertOnNightDriving,
    int? nightStartHour,
    int? nightEndHour,
    double? speedLimitKmh,
  }) {
    return ParentShareSettings(
      shareLocation: shareLocation ?? this.shareLocation,
      shareSpeed: shareSpeed ?? this.shareSpeed,
      alertOnSpeeding: alertOnSpeeding ?? this.alertOnSpeeding,
      alertOnNightDriving: alertOnNightDriving ?? this.alertOnNightDriving,
      nightStartHour: nightStartHour ?? this.nightStartHour,
      nightEndHour: nightEndHour ?? this.nightEndHour,
      speedLimitKmh: speedLimitKmh ?? this.speedLimitKmh,
    );
  }
}

/// Linked parent info.
class LinkedParent {
  const LinkedParent({
    required this.id,
    required this.email,
    this.name,
    required this.linkedAt,
  });

  final String id;
  final String email;
  final String? name;
  final DateTime linkedAt;

  factory LinkedParent.fromJson(Map<String, dynamic> json) {
    return LinkedParent(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      linkedAt: DateTime.parse(json['linked_at'] as String),
    );
  }
}

/// Trip record for history.
class TripRecord {
  const TripRecord({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.startLocation,
    this.endLocation,
    required this.distanceKm,
    required this.maxSpeedKmh,
    required this.speedViolations,
  });

  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final String startLocation;
  final String? endLocation;
  final double distanceKm;
  final double maxSpeedKmh;
  final int speedViolations;
}

/// Linked child info for parent view.
class LinkedChild {
  const LinkedChild({
    required this.id,
    required this.email,
    this.name,
    required this.linkedAt,
    this.location,
    this.speedKmh,
    this.isDriving = false,
    this.lastUpdate,
  });

  final String id;
  final String email;
  final String? name;
  final DateTime linkedAt;
  final LatLng? location;
  final double? speedKmh;
  final bool isDriving;
  final DateTime? lastUpdate;

  String get displayName => name ?? email.split('@').first;

  bool get isOnline {
    if (lastUpdate == null) return false;
    return DateTime.now().difference(lastUpdate!).inMinutes < 2;
  }

  LinkedChild copyWith({
    String? id,
    String? email,
    String? name,
    DateTime? linkedAt,
    LatLng? location,
    double? speedKmh,
    bool? isDriving,
    DateTime? lastUpdate,
  }) {
    return LinkedChild(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      linkedAt: linkedAt ?? this.linkedAt,
      location: location ?? this.location,
      speedKmh: speedKmh ?? this.speedKmh,
      isDriving: isDriving ?? this.isDriving,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

/// Alert from child for parent view.
class ParentAlert {
  const ParentAlert({
    required this.id,
    required this.childId,
    required this.childName,
    required this.type,
    required this.data,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String childId;
  final String childName;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;
}

/// Service for managing parent-child link and location/speed sharing.
class ParentService {
  ParentService._();

  static final ParentService instance = ParentService._();

  static const String _settingsKey = 'parent_share_settings';
  static const String _enabledKey = 'parent_sharing_enabled';
  static const String _inviteCodeKey = 'parent_invite_code';

  SharedPreferences? _prefs;

  final ValueNotifier<bool> isEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<ParentShareSettings> settings =
      ValueNotifier<ParentShareSettings>(const ParentShareSettings());
  final ValueNotifier<List<LinkedParent>> linkedParents =
      ValueNotifier<List<LinkedParent>>([]);
  final ValueNotifier<String?> inviteCode = ValueNotifier<String?>(null);

  // Parent dashboard state.
  final ValueNotifier<List<LinkedChild>> linkedChildren =
      ValueNotifier<List<LinkedChild>>([]);
  final ValueNotifier<List<ParentAlert>> alerts =
      ValueNotifier<List<ParentAlert>>([]);

  // Current driving state (updated by map screen).
  LatLng? _currentLocation;
  double _currentSpeedKmh = 0;
  bool _isDriving = false;

  Timer? _updateTimer;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();

    isEnabled.value = _prefs?.getBool(_enabledKey) ?? false;
    inviteCode.value = _prefs?.getString(_inviteCodeKey);

    final settingsJson = _prefs?.getString(_settingsKey);
    if (settingsJson != null) {
      try {
        final decoded = settingsJson;
        // Simple JSON parsing without import
        settings.value = ParentShareSettings.fromJson(
          Map<String, dynamic>.from(_parseJson(decoded)),
        );
      } catch (_) {
        settings.value = const ParentShareSettings();
      }
    }

    if (isEnabled.value && SupabaseService.instance.isEnabled) {
      await _loadLinkedParents();
      _startRealtimeUpdates();
    }
  }

  Map<String, dynamic> _parseJson(String json) {
    try {
      final trimmed = json.trim();
      if (!trimmed.startsWith('{')) return {};
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static Map<String, dynamic>? _mapOrNull(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    final text = _stringOrNull(value);
    if (text == null) return null;
    return DateTime.tryParse(text);
  }

  static LatLng? _latLngOrNull(Object? value) {
    final map = _mapOrNull(value);
    final lat = (map?['lat'] as num?)?.toDouble();
    final lng = (map?['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  @visibleForTesting
  static LinkedChild? parseLinkedChildRow(Map<String, dynamic> row) {
    final childId = _stringOrNull(row['child_id']);
    final linkedAt = _dateTimeOrNull(row['linked_at']);
    if (childId == null || linkedAt == null) return null;

    final profile = _mapOrNull(row['profiles']);
    final share = _mapOrNull(row['parent_shares']);

    return LinkedChild(
      id: childId,
      email: _stringOrNull(profile?['email']) ?? '',
      name: _stringOrNull(profile?['display_name']),
      linkedAt: linkedAt,
      location: _latLngOrNull(share?['last_location']),
      speedKmh: (share?['last_speed_kmh'] as num?)?.toDouble(),
      isDriving: share?['is_driving'] as bool? ?? false,
      lastUpdate: _dateTimeOrNull(share?['last_update']),
    );
  }

  @visibleForTesting
  static ParentAlert? parseParentAlertRow(
    Map<String, dynamic> row, {
    required Map<String, String> childMap,
  }) {
    final id = _stringOrNull(row['id']);
    final childId = _stringOrNull(row['child_id']);
    final type = _stringOrNull(row['type']);
    final createdAt = _dateTimeOrNull(row['created_at']);
    if (id == null || childId == null || type == null || createdAt == null) {
      return null;
    }

    return ParentAlert(
      id: id,
      childId: childId,
      childName: childMap[childId] ?? 'Unknown',
      type: type,
      data: _mapOrNull(row['data']) ?? const {},
      createdAt: createdAt,
    );
  }

  /// Enable parent sharing and generate invite code.
  Future<String> enableSharing() async {
    if (!AuthService.instance.isLoggedIn.value) {
      throw StateError('Must be logged in to enable parent sharing');
    }

    // Generate a 6-character invite code.
    final code = _generateInviteCode();
    inviteCode.value = code;
    isEnabled.value = true;

    await _prefs?.setBool(_enabledKey, true);
    await _prefs?.setString(_inviteCodeKey, code);

    if (SupabaseService.instance.isEnabled) {
      await _createShareRecord(code);
      _startRealtimeUpdates();
    }

    return code;
  }

  /// Disable parent sharing.
  Future<void> disableSharing() async {
    isEnabled.value = false;
    inviteCode.value = null;
    linkedParents.value = [];

    await _prefs?.setBool(_enabledKey, false);
    await _prefs?.remove(_inviteCodeKey);

    _updateTimer?.cancel();
    _updateTimer = null;

    if (SupabaseService.instance.isEnabled) {
      await _deleteShareRecord();
    }
  }

  /// Update sharing settings.
  Future<void> updateSettings(ParentShareSettings newSettings) async {
    settings.value = newSettings;
    await _prefs?.setString(_settingsKey, _settingsToJson(newSettings));

    if (SupabaseService.instance.isEnabled && isEnabled.value) {
      await _syncSettingsToServer();
    }
  }

  String _settingsToJson(ParentShareSettings s) {
    return '{"shareLocation":${s.shareLocation},"shareSpeed":${s.shareSpeed},'
        '"alertOnSpeeding":${s.alertOnSpeeding},"alertOnNightDriving":${s.alertOnNightDriving},'
        '"nightStartHour":${s.nightStartHour},"nightEndHour":${s.nightEndHour},'
        '"speedLimitKmh":${s.speedLimitKmh}}';
  }

  /// Remove a linked parent.
  Future<void> unlinkParent(String parentId) async {
    if (!SupabaseService.instance.isEnabled) return;

    await SupabaseService.instance.client
        .from('parent_links')
        .delete()
        .eq('parent_id', parentId)
        .eq('child_id', AuthService.instance.userId.value ?? '');

    await _loadLinkedParents();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PARENT DASHBOARD METHODS (for parents monitoring children)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Link to a child using their invite code.
  /// Returns 'ok' on success, 'self' if trying to link to own account,
  /// 'not_found' if code is invalid, or 'error' on failure.
  Future<String> linkToChildWithCode(String code) async {
    if (!SupabaseService.instance.isEnabled) return 'error';
    if (!AuthService.instance.isLoggedIn.value) return 'error';

    final parentId = AuthService.instance.userId.value;
    if (parentId == null) return 'error';

    try {
      // Find the child with this invite code.
      final shareResponse = await SupabaseService.instance.client
          .from('parent_shares')
          .select('user_id')
          .eq('invite_code', code.toUpperCase())
          .eq('is_active', true)
          .maybeSingle();

      if (shareResponse == null) return 'not_found';

      final childId = _stringOrNull(shareResponse['user_id']);
      if (childId == null) return 'error';

      // Don't allow linking to yourself.
      if (childId == parentId) return 'self';

      // Check if already linked.
      final existingLink = await SupabaseService.instance.client
          .from('parent_links')
          .select('id')
          .eq('parent_id', parentId)
          .eq('child_id', childId)
          .maybeSingle();

      if (existingLink != null) return 'ok'; // Already linked.

      // Create the link.
      await SupabaseService.instance.client.from('parent_links').insert({
        'parent_id': parentId,
        'child_id': childId,
        'linked_at': DateTime.now().toIso8601String(),
      });

      await loadLinkedChildren();
      return 'ok';
    } catch (e) {
      debugPrint('Failed to link to child: $e');
      return 'error';
    }
  }

  /// Load all linked children for the current user (as parent).
  Future<void> loadLinkedChildren() async {
    if (!SupabaseService.instance.isEnabled) return;
    final parentId = AuthService.instance.userId.value;
    if (parentId == null) return;

    try {
      final response = await SupabaseService.instance.client
          .from('parent_links')
          .select('''
            child_id,
            linked_at,
            profiles!child_id(email, display_name),
            parent_shares!child_id(last_location, last_speed_kmh, is_driving, last_update)
          ''')
          .eq('parent_id', parentId);

      final children = <LinkedChild>[];
      for (final row in response as List) {
        final parsed = parseLinkedChildRow(
          Map<String, dynamic>.from(row as Map),
        );
        if (parsed != null) children.add(parsed);
      }
      linkedChildren.value = children;
    } catch (e) {
      debugPrint('Failed to load linked children: $e');
    }
  }

  /// Remove a linked child.
  Future<void> unlinkChild(String childId) async {
    if (!SupabaseService.instance.isEnabled) return;
    final parentId = AuthService.instance.userId.value;
    if (parentId == null) return;

    await SupabaseService.instance.client
        .from('parent_links')
        .delete()
        .eq('parent_id', parentId)
        .eq('child_id', childId);

    await loadLinkedChildren();
  }

  /// Load recent alerts for linked children.
  Future<void> loadAlerts() async {
    if (!SupabaseService.instance.isEnabled) return;
    final parentId = AuthService.instance.userId.value;
    if (parentId == null) return;

    try {
      // Get all linked child IDs first.
      final links = await SupabaseService.instance.client
          .from('parent_links')
          .select('child_id, profiles!child_id(display_name, email)')
          .eq('parent_id', parentId);

      final childMap = <String, String>{};
      for (final link in links as List) {
        final map = Map<String, dynamic>.from(link as Map);
        final childId = _stringOrNull(map['child_id']);
        if (childId == null) continue;
        final profile = _mapOrNull(map['profiles']);
        childMap[childId] =
            _stringOrNull(profile?['display_name']) ??
            _stringOrNull(profile?['email'])?.split('@').first ??
            'Unknown';
      }

      if (childMap.isEmpty) {
        alerts.value = [];
        return;
      }

      // Fetch alerts from last 24 hours.
      final since = DateTime.now().subtract(const Duration(hours: 24));
      final response = await SupabaseService.instance.client
          .from('parent_alerts')
          .select()
          .inFilter('child_id', childMap.keys.toList())
          .gte('created_at', since.toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      final alertList = <ParentAlert>[];
      for (final row in response as List) {
        final parsed = parseParentAlertRow(
          Map<String, dynamic>.from(row as Map),
          childMap: childMap,
        );
        if (parsed != null) alertList.add(parsed);
      }
      alerts.value = alertList;
    } catch (e) {
      debugPrint('Failed to load alerts: $e');
    }
  }

  Timer? _childUpdateTimer;

  /// Start polling for children updates (for parent dashboard).
  void startChildTracking() {
    _childUpdateTimer?.cancel();
    _childUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await loadLinkedChildren();
    });
    // Initial load.
    loadLinkedChildren();
    loadAlerts();
  }

  /// Stop polling for children updates.
  void stopChildTracking() {
    _childUpdateTimer?.cancel();
    _childUpdateTimer = null;
  }

  /// Update current driving state (called by map screen).
  void updateDrivingState({
    required LatLng location,
    required double speedKmh,
    required bool isDriving,
  }) {
    _currentLocation = location;
    _currentSpeedKmh = speedKmh;
    _isDriving = isDriving;

    // Check for speeding alert.
    if (isEnabled.value && settings.value.alertOnSpeeding) {
      if (speedKmh > settings.value.speedLimitKmh) {
        _sendSpeedingAlert(speedKmh);
      }
    }

    // Check for night driving.
    if (isEnabled.value && settings.value.alertOnNightDriving && isDriving) {
      final hour = DateTime.now().hour;
      final nightStart = settings.value.nightStartHour;
      final nightEnd = settings.value.nightEndHour;
      final isNight = nightStart > nightEnd
          ? (hour >= nightStart || hour < nightEnd)
          : (hour >= nightStart && hour < nightEnd);
      if (isNight) {
        _sendNightDrivingAlert();
      }
    }
  }

  // ── Private methods ─────────────────────────────────────────────────────

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _createShareRecord(String code) async {
    if (!SupabaseService.instance.isEnabled) return;
    final userId = AuthService.instance.userId.value;
    if (userId == null) return;

    await SupabaseService.instance.client.from('parent_shares').upsert({
      'user_id': userId,
      'invite_code': code,
      'settings': settings.value.toJson(),
      'is_active': true,
    });
  }

  Future<void> _deleteShareRecord() async {
    if (!SupabaseService.instance.isEnabled) return;
    final userId = AuthService.instance.userId.value;
    if (userId == null) return;

    await SupabaseService.instance.client
        .from('parent_shares')
        .delete()
        .eq('user_id', userId);

    await SupabaseService.instance.client
        .from('parent_links')
        .delete()
        .eq('child_id', userId);
  }

  Future<void> _syncSettingsToServer() async {
    if (!SupabaseService.instance.isEnabled) return;
    final userId = AuthService.instance.userId.value;
    if (userId == null) return;

    await SupabaseService.instance.client
        .from('parent_shares')
        .update({'settings': settings.value.toJson()})
        .eq('user_id', userId);
  }

  Future<void> _loadLinkedParents() async {
    if (!SupabaseService.instance.isEnabled) return;
    final userId = AuthService.instance.userId.value;
    if (userId == null) return;

    try {
      final response = await SupabaseService.instance.client
          .from('parent_links')
          .select(
            'parent_id, linked_at, profiles!parent_id(email, display_name)',
          )
          .eq('child_id', userId);

      final parents = <LinkedParent>[];
      for (final row in response as List) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        parents.add(
          LinkedParent(
            id: row['parent_id'] as String,
            email: profile?['email'] as String? ?? '',
            name: profile?['display_name'] as String?,
            linkedAt: DateTime.parse(row['linked_at'] as String),
          ),
        );
      }
      linkedParents.value = parents;
    } catch (e) {
      debugPrint('Failed to load linked parents: $e');
    }
  }

  void _startRealtimeUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pushLocationUpdate();
    });
  }

  Future<void> _pushLocationUpdate() async {
    if (!isEnabled.value || !_isDriving) return;
    if (!SupabaseService.instance.isEnabled) return;
    if (!settings.value.shareLocation) return;

    final userId = AuthService.instance.userId.value;
    final loc = _currentLocation;
    if (userId == null || loc == null) return;

    try {
      await SupabaseService.instance.client
          .from('parent_shares')
          .update({
            'last_location': {'lat': loc.latitude, 'lng': loc.longitude},
            'last_speed_kmh': settings.value.shareSpeed
                ? _currentSpeedKmh
                : null,
            'is_driving': _isDriving,
            'last_update': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Failed to push location update: $e');
    }
  }

  DateTime? _lastSpeedingAlert;
  Future<void> _sendSpeedingAlert(double speedKmh) async {
    // Rate limit: max one alert per 60 seconds.
    final now = DateTime.now();
    if (_lastSpeedingAlert != null &&
        now.difference(_lastSpeedingAlert!).inSeconds < 60) {
      return;
    }
    _lastSpeedingAlert = now;

    if (!SupabaseService.instance.isEnabled) return;
    final userId = AuthService.instance.userId.value;
    if (userId == null) return;

    try {
      await SupabaseService.instance.client.from('parent_alerts').insert({
        'child_id': userId,
        'type': 'speeding',
        'data': {
          'speed_kmh': speedKmh,
          'limit_kmh': settings.value.speedLimitKmh,
        },
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to send speeding alert: $e');
    }
  }

  DateTime? _lastNightAlert;
  Future<void> _sendNightDrivingAlert() async {
    // Rate limit: max one alert per 10 minutes.
    final now = DateTime.now();
    if (_lastNightAlert != null &&
        now.difference(_lastNightAlert!).inMinutes < 10) {
      return;
    }
    _lastNightAlert = now;

    if (!SupabaseService.instance.isEnabled) return;
    final userId = AuthService.instance.userId.value;
    if (userId == null) return;

    try {
      await SupabaseService.instance.client.from('parent_alerts').insert({
        'child_id': userId,
        'type': 'night_driving',
        'data': {'hour': now.hour},
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to send night driving alert: $e');
    }
  }

  void dispose() {
    _updateTimer?.cancel();
    _updateTimer = null;
    _childUpdateTimer?.cancel();
    _childUpdateTimer = null;
  }
}
