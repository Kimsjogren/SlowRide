import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PaywallReason { routeLimit, convoyLimit, memberLimit }

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const int freeMaxDailyRoutes = 2;
  static const int freeMaxConvoyMembers = 2;

  static const String _isProKey = 'sub_is_pro';
  static const String _routeCountKey = 'sub_route_count';
  static const String _routeDateKey = 'sub_route_date';

  late SharedPreferences _prefs;
  final ValueNotifier<bool> isPro = ValueNotifier<bool>(false);

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    isPro.value = _prefs.getBool(_isProKey) ?? false;
  }

  // ── Daily route tracking ────────────────────────────────────────────────

  int get routesToday {
    final savedDate = _prefs.getString(_routeDateKey) ?? '';
    if (savedDate != _todayString) return 0;
    return _prefs.getInt(_routeCountKey) ?? 0;
  }

  bool canStartRoute() => isPro.value || routesToday < freeMaxDailyRoutes;

  void recordRoute() {
    final today = _todayString;
    final savedDate = _prefs.getString(_routeDateKey) ?? '';
    final count = savedDate == today ? (_prefs.getInt(_routeCountKey) ?? 0) : 0;
    _prefs.setString(_routeDateKey, today);
    _prefs.setInt(_routeCountKey, count + 1);
  }

  String get _todayString {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  // ── Convoy limits ───────────────────────────────────────────────────────

  /// Free users can only be in 1 convoy at a time.
  bool canCreateOrJoinConvoy(int currentJoinedCount) =>
      isPro.value || currentJoinedCount == 0;

  /// Free users cannot join a convoy that already has max members.
  bool canJoinConvoyWithMemberCount(int memberCount) =>
      isPro.value || memberCount < freeMaxConvoyMembers;

  // ── Purchase ─────────────────────────────────────────────────────────────

  /// Activates Pro (call after successful RevenueCat purchase).
  Future<void> activatePro() async {
    isPro.value = true;
    await _prefs.setBool(_isProKey, true);
  }

  /// Restores purchase (stub — integrate RevenueCat here).
  Future<bool> restorePurchase() async {
    // TODO: RevenueCat restore
    return false;
  }

  /// Deactivates Pro (for testing / subscription lapse).
  Future<void> deactivatePro() async {
    isPro.value = false;
    await _prefs.setBool(_isProKey, false);
  }
}
