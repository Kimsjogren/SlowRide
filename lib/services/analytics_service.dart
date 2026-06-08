import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:slowride/services/firebase_service.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  bool _initialized = false;
  bool _enabled = false;
  FirebaseAnalyticsObserver? _observer;

  bool get isEnabled => _enabled;
  bool get isInitialized => _initialized;
  List<NavigatorObserver> get navigatorObservers =>
      _observer == null ? const [] : [_observer!];

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (!FirebaseService.instance.isEnabled) {
      _enabled = false;
      _initialized = true;
      return;
    }

    try {
      final analytics = FirebaseAnalytics.instance;
      await analytics.logAppOpen();
      _observer = FirebaseAnalyticsObserver(analytics: analytics);
      _enabled = true;
    } catch (e, st) {
      debugPrint('Analytics service init error: $e\n$st');
      _enabled = false;
      _observer = null;
    }

    _initialized = true;
  }
}
