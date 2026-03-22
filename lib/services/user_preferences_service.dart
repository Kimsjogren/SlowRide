import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SpeedUnit { kmh, mph }

class UserPreferencesService {
  UserPreferencesService._();

  static final UserPreferencesService instance = UserPreferencesService._();

  final ValueNotifier<String> vehicleType = ValueNotifier<String>('A-tractor');
  final ValueNotifier<SpeedUnit> speedUnit = ValueNotifier<SpeedUnit>(
    SpeedUnit.kmh,
  );
  final ValueNotifier<double> maxSpeedKmh = ValueNotifier<double>(30);
  final ValueNotifier<String?> languageCode = ValueNotifier<String?>(null);
  final ValueNotifier<bool> use3DMap = ValueNotifier<bool>(false);

  static const String _vehicleTypeKey = 'user_vehicle_type';
  static const String _speedUnitKey = 'user_speed_unit';
  static const String _maxSpeedKmhKey = 'user_max_speed_kmh';
  static const String _languageCodeKey = 'user_language_code';
  static const String _use3DMapKey = 'user_use_3d_map';

  /// Per-vehicle speed key prefix. Stored as e.g. 'vehicle_speed_A-tractor'.
  static const String _vehicleSpeedPrefix = 'vehicle_speed_';

  SharedPreferences? _prefs;
  bool _listenersAttached = false;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();

    vehicleType.value = _prefs!.getString(_vehicleTypeKey) ?? 'A-tractor';

    final storedUnit = _prefs!.getString(_speedUnitKey);
    speedUnit.value = storedUnit == SpeedUnit.mph.name
        ? SpeedUnit.mph
        : SpeedUnit.kmh;

    maxSpeedKmh.value = _prefs!.getDouble(_maxSpeedKmhKey) ?? 30;
    languageCode.value = _prefs!.getString(_languageCodeKey);
    use3DMap.value = _prefs!.getBool(_use3DMapKey) ?? false;

    if (!_listenersAttached) {
      vehicleType.addListener(_onVehicleTypeChanged);
      vehicleType.addListener(_persistVehicleType);
      speedUnit.addListener(_persistSpeedUnit);
      maxSpeedKmh.addListener(_persistMaxSpeedKmh);
      languageCode.addListener(_persistLanguageCode);
      use3DMap.addListener(_persist3DMap);
      _listenersAttached = true;
    }
  }

  void _onVehicleTypeChanged() {
    // Load the user's saved speed for this vehicle, or use the vehicle default.
    final defaultSpeed = _defaultSpeedFor(vehicleType.value);
    final savedSpeed = _prefs?.getDouble(
      '$_vehicleSpeedPrefix${vehicleType.value}',
    );
    maxSpeedKmh.value = savedSpeed ?? defaultSpeed;
  }

  static double _defaultSpeedFor(String vehicle) {
    switch (vehicle) {
      case 'A-tractor':
        return 30;
      case 'Moped car':
        return 45;
      case 'Tractor':
        return 30;
      default:
        return 30;
    }
  }

  Future<void> _persistVehicleType() async {
    await _prefs?.setString(_vehicleTypeKey, vehicleType.value);
  }

  Future<void> _persistSpeedUnit() async {
    await _prefs?.setString(_speedUnitKey, speedUnit.value.name);
  }

  Future<void> _persistMaxSpeedKmh() async {
    await _prefs?.setDouble(_maxSpeedKmhKey, maxSpeedKmh.value);
    // Also save per-vehicle so switching back restores the user's chosen speed.
    await _prefs?.setDouble(
      '$_vehicleSpeedPrefix${vehicleType.value}',
      maxSpeedKmh.value,
    );
  }

  Future<void> _persist3DMap() async {
    await _prefs?.setBool(_use3DMapKey, use3DMap.value);
  }

  Future<void> _persistLanguageCode() async {
    final current = languageCode.value;
    if (current == null || current.isEmpty) {
      await _prefs?.remove(_languageCodeKey);
      return;
    }
    await _prefs?.setString(_languageCodeKey, current);
  }

  Locale? get localeOverride {
    final code = languageCode.value;
    if (code == null || code.isEmpty) {
      return null;
    }
    return Locale(code);
  }

  String unitLabel(SpeedUnit unit) {
    return unit == SpeedUnit.kmh ? 'km/h' : 'mph';
  }

  double toDisplaySpeed({required double speedKmh, required SpeedUnit unit}) {
    if (unit == SpeedUnit.kmh) {
      return speedKmh;
    }
    return speedKmh / 1.60934;
  }

  double fromDisplaySpeed({required double value, required SpeedUnit unit}) {
    if (unit == SpeedUnit.kmh) {
      return value;
    }
    return value * 1.60934;
  }
}
