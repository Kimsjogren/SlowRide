import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slowride/models/country_vehicle_rules.dart';

enum SpeedUnit { kmh, mph }

enum MapMarkerStyle {
  navigation,
  compass,
  triangle,
  dot,
  microcarRed,
  microcarBlue,
  microcarBlack,
  microcarWhite,
  microcarGold,
  epaRed,
  epaBlue,
  epaBlack,
  epaWhite,
  epaGold,
  aixamWhite,
  aixamRed,
  aixamBlack,
  aixamGraphite,
  aixamYellow,
  tractorWhite,
  tractorBlack,
  tractorRed,
  tractorGold,
  miniWhite,
  miniGreen,
  miniOrange,
  bmwRed,
  bmwBlack,
  bmwSilver,
  bmwOrange,
  mgoOrange,
  mgoRed,
  mgoBlack,
  mgoYellow,
}

class UserPreferencesService {
  UserPreferencesService._();

  static final UserPreferencesService instance = UserPreferencesService._();

  final ValueNotifier<String> vehicleType = ValueNotifier<String>('A-tractor');
  final ValueNotifier<SpeedUnit> speedUnit = ValueNotifier<SpeedUnit>(
    SpeedUnit.kmh,
  );
  final ValueNotifier<double> maxSpeedKmh = ValueNotifier<double>(30);
  final ValueNotifier<String?> languageCode = ValueNotifier<String?>(null);
  final ValueNotifier<String> countryCode = ValueNotifier<String>(
    CountryVehicleRules.defaultCountry,
  );
  final ValueNotifier<bool> use3DMap = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isElectric = ValueNotifier<bool>(false);
  final ValueNotifier<bool> hasStuddedTires = ValueNotifier<bool>(false);
  final ValueNotifier<MapMarkerStyle> mapMarkerStyle =
      ValueNotifier<MapMarkerStyle>(MapMarkerStyle.navigation);

  static const String _vehicleTypeKey = 'user_vehicle_type';
  static const String _speedUnitKey = 'user_speed_unit';
  static const String _maxSpeedKmhKey = 'user_max_speed_kmh';
  static const String _languageCodeKey = 'user_language_code';
  static const String _countryCodeKey = 'user_country_code';
  static const String _use3DMapKey = 'user_use_3d_map';
  static const String _isElectricKey = 'user_is_electric';
  static const String _hasStuddedTiresKey = 'user_has_studded_tires';
  static const String _mapMarkerStyleKey = 'user_map_marker_style';

  /// Per-vehicle speed key prefix. Stored as e.g. 'vehicle_speed_SE_A-tractor'.
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
    countryCode.value =
        _prefs!.getString(_countryCodeKey) ??
        CountryVehicleRules.defaultCountry;
    use3DMap.value = _prefs!.getBool(_use3DMapKey) ?? false;
    isElectric.value = _prefs!.getBool(_isElectricKey) ?? false;
    hasStuddedTires.value = _prefs!.getBool(_hasStuddedTiresKey) ?? false;
    final storedMarkerStyle = _prefs!.getString(_mapMarkerStyleKey);
    mapMarkerStyle.value = MapMarkerStyle.values.firstWhere(
      (style) => style.name == storedMarkerStyle,
      orElse: () => MapMarkerStyle.navigation,
    );

    if (!_listenersAttached) {
      vehicleType.addListener(_onVehicleTypeChanged);
      vehicleType.addListener(_persistVehicleType);
      speedUnit.addListener(_persistSpeedUnit);
      maxSpeedKmh.addListener(_persistMaxSpeedKmh);
      languageCode.addListener(_persistLanguageCode);
      countryCode.addListener(_onCountryChanged);
      countryCode.addListener(_persistCountryCode);
      use3DMap.addListener(_persist3DMap);
      isElectric.addListener(_persistIsElectric);
      hasStuddedTires.addListener(_persistHasStuddedTires);
      mapMarkerStyle.addListener(_persistMapMarkerStyle);
      _listenersAttached = true;
    }
  }

  void _onVehicleTypeChanged() {
    // Load the user's saved speed for this country+vehicle, or use the default.
    final defaultSpeed = CountryVehicleRules.defaultSpeedFor(
      countryCode.value,
      vehicleType.value,
    );
    final savedSpeed = _prefs?.getDouble(
      '$_vehicleSpeedPrefix${countryCode.value}_${vehicleType.value}',
    );
    maxSpeedKmh.value = savedSpeed ?? defaultSpeed;
  }

  void _onCountryChanged() {
    // Country changed — always update speed to the saved or default for this
    // country+vehicle combination.
    final defaultSpeed = CountryVehicleRules.defaultSpeedFor(
      countryCode.value,
      vehicleType.value,
    );
    final savedSpeed = _prefs?.getDouble(
      '$_vehicleSpeedPrefix${countryCode.value}_${vehicleType.value}',
    );
    maxSpeedKmh.value = savedSpeed ?? defaultSpeed;
  }

  Future<void> _persistVehicleType() async {
    await _prefs?.setString(_vehicleTypeKey, vehicleType.value);
  }

  Future<void> _persistSpeedUnit() async {
    await _prefs?.setString(_speedUnitKey, speedUnit.value.name);
  }

  Future<void> _persistMaxSpeedKmh() async {
    await _prefs?.setDouble(_maxSpeedKmhKey, maxSpeedKmh.value);
    // Also save per-country+vehicle so switching back restores the user's chosen speed.
    await _prefs?.setDouble(
      '$_vehicleSpeedPrefix${countryCode.value}_${vehicleType.value}',
      maxSpeedKmh.value,
    );
  }

  Future<void> _persist3DMap() async {
    await _prefs?.setBool(_use3DMapKey, use3DMap.value);
  }

  Future<void> _persistIsElectric() async {
    await _prefs?.setBool(_isElectricKey, isElectric.value);
  }

  Future<void> _persistHasStuddedTires() async {
    await _prefs?.setBool(_hasStuddedTiresKey, hasStuddedTires.value);
  }

  Future<void> _persistMapMarkerStyle() async {
    await _prefs?.setString(_mapMarkerStyleKey, mapMarkerStyle.value.name);
  }

  Future<void> _persistLanguageCode() async {
    final current = languageCode.value;
    if (current == null || current.isEmpty) {
      await _prefs?.remove(_languageCodeKey);
      return;
    }
    await _prefs?.setString(_languageCodeKey, current);
  }

  Future<void> _persistCountryCode() async {
    await _prefs?.setString(_countryCodeKey, countryCode.value);
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
