import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/supabase_service.dart';
import 'package:slowride/services/user_preferences_service.dart';

class PublicGatheringNotificationService {
  PublicGatheringNotificationService._();

  static final instance = PublicGatheringNotificationService._();
  static const double radiusMeters = 25000;
  static const Duration lookAhead = Duration(hours: 24);

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Timer? _timer;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher'),
      iOS: IOSInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _notifications.initialize(settings: settings);
    _initialized = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => checkNow());
    if (UserPreferencesService.instance.nearbyGatheringNotifications.value) {
      unawaited(checkNow());
    }
  }

  Future<bool> enable() async {
    await initialize();
    var granted = true;
    if (Platform.isAndroid) {
      granted =
          await _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    } else if (Platform.isIOS) {
      granted =
          await _notifications
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    if (!granted) return false;

    var locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
    }
    final locationGranted =
        locationPermission != LocationPermission.denied &&
        locationPermission != LocationPermission.deniedForever;
    if (!locationGranted) return false;

    UserPreferencesService.instance.nearbyGatheringNotifications.value = true;
    unawaited(checkNow());
    return true;
  }

  void disable() {
    UserPreferencesService.instance.nearbyGatheringNotifications.value = false;
  }

  Future<void> checkNow() async {
    if (!UserPreferencesService.instance.nearbyGatheringNotifications.value ||
        !SupabaseService.instance.isEnabled ||
        AuthService.instance.userId.value == null) {
      return;
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final now = DateTime.now();
      final rows = await SupabaseService.instance.client
          .from('convoys')
          .select(
            'id,name,meetup_lat,meetup_lng,meetup_label,starts_at,ends_at',
          )
          .eq('visibility', 'public')
          .gt('ends_at', now.toUtc().toIso8601String())
          .lte('starts_at', now.add(lookAhead).toUtc().toIso8601String());
      final blockedRows = await SupabaseService.instance.client
          .from('convoy_blocks')
          .select('gathering_id')
          .eq('blocker_id', AuthService.instance.userId.value!)
          .eq('target_type', 'gathering');
      final blockedIds = blockedRows
          .map<String>((row) => row['gathering_id']?.toString() ?? '')
          .toSet();
      final prefs = await SharedPreferences.getInstance();
      final origin = LatLng(position.latitude, position.longitude);
      const distance = Distance();

      for (final row in rows) {
        final id = row['id']?.toString() ?? '';
        if (id.isEmpty || blockedIds.contains(id)) continue;
        final lat = (row['meetup_lat'] as num?)?.toDouble();
        final lng = (row['meetup_lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        if (distance(origin, LatLng(lat, lng)) > radiusMeters) continue;
        final notificationKey = 'nearby_gathering_notified_$id';
        if (prefs.getBool(notificationKey) == true) continue;

        final language =
            UserPreferencesService.instance.languageCode.value ??
            Platform.localeName.split('_').first;
        final text = _localizedText(
          language,
          row['name']?.toString() ?? '',
          row['meetup_label']?.toString() ?? '',
        );
        await _notifications.show(
          id: id.hashCode & 0x7fffffff,
          title: text.$1,
          body: text.$2,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'cruizx_public_gatherings',
              'Public gatherings nearby',
              channelDescription: 'Nearby CruizX public gathering alerts',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: id,
        );
        await prefs.setBool(notificationKey, true);
      }
    } catch (error) {
      debugPrint('Nearby public gathering check failed: $error');
    }
  }

  (String, String) _localizedText(String language, String name, String place) {
    final location = place.isEmpty ? name : '$name · $place';
    return switch (language) {
      'sv' => ('Offentlig träff i närheten', '$location finns inom 25 km.'),
      'nb' => ('Offentlig treff i nærheten', '$location finnes innen 25 km.'),
      'da' => (
        'Offentligt træf i nærheden',
        '$location findes inden for 25 km.',
      ),
      'fi' => ('Julkinen tapaaminen lähellä', '$location on 25 km:n säteellä.'),
      'fr' => (
        'Rassemblement public à proximité',
        '$location se trouve à moins de 25 km.',
      ),
      'es' => ('Encuentro público cercano', '$location está a menos de 25 km.'),
      'it' => (
        'Incontro pubblico nelle vicinanze',
        '$location si trova entro 25 km.',
      ),
      _ => ('Public meetup nearby', '$location is within 25 km.'),
    };
  }
}
