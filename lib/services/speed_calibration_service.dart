import 'package:shared_preferences/shared_preferences.dart';
import 'package:slowride/services/user_preferences_service.dart';

/// Speed Calibration Engine (Phase 3 — Plan.txt)
///
/// Learns the user's actual average driving speed per vehicle type by
/// recording completed navigation trips and applying an exponential
/// moving average:
///
///   new_speed = previous_speed × 0.7 + trip_speed × 0.3
///
/// The learned speed is used to compute live ETA during navigation:
///
///   ETA = remaining_distance / learned_speed
///
/// If no trips have been recorded yet, falls back to 85 % of the user's
/// configured max speed (conservative real-world estimate for slow vehicles).
class SpeedCalibrationService {
  SpeedCalibrationService._();

  static final SpeedCalibrationService instance = SpeedCalibrationService._();

  static const String _keyPrefix = 'learned_speed_kmh_';
  static const double _minDistM = 300; // ignore very short trips
  static const double _minDurSec = 30; // ignore very short sessions
  static const double _learningRate = 0.3; // weight of newest trip

  SharedPreferences? _prefs;

  /// Load SharedPreferences. Safe to call multiple times.
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Effective average speed (km/h) to use for ETA calculation.
  ///
  /// Returns the persisted learned speed if available.
  /// Falls back to 85 % of the user's configured max speed.
  double effectiveSpeedKmh(String vehicleType) {
    final learned = _prefs?.getDouble('$_keyPrefix$vehicleType');
    if (learned != null && learned > 1) return learned;
    // Fallback: 85 % of configured max speed (real-world for slow vehicles).
    return UserPreferencesService.instance.maxSpeedKmh.value * 0.85;
  }

  /// Returns the raw learned speed, or null if not yet calibrated.
  double? learnedSpeedKmh(String vehicleType) {
    return _prefs?.getDouble('$_keyPrefix$vehicleType');
  }

  /// Record a completed trip and update the learned speed.
  ///
  /// [distanceM]   — total distance driven (metres)
  /// [durationSec] — total navigation time (seconds)
  ///
  /// Ignored if the trip is too short or the computed speed is implausible.
  Future<void> recordTrip({
    required String vehicleType,
    required double distanceM,
    required double durationSec,
  }) async {
    if (distanceM < _minDistM || durationSec < _minDurSec) return;

    final tripSpeedKmh = (distanceM / durationSec) * 3.6;

    // Sanity bounds: must be between 1 km/h and 120 % of the vehicle max.
    final maxAllowed = UserPreferencesService.instance.maxSpeedKmh.value * 1.2;
    if (tripSpeedKmh < 1 || tripSpeedKmh > maxAllowed) return;

    final prev = effectiveSpeedKmh(vehicleType);
    final newSpeed = prev * (1 - _learningRate) + tripSpeedKmh * _learningRate;

    await _prefs?.setDouble('$_keyPrefix$vehicleType', newSpeed);
  }

  /// Reset learned speed for a vehicle type (e.g. from settings).
  Future<void> resetCalibration(String vehicleType) async {
    await _prefs?.remove('$_keyPrefix$vehicleType');
  }
}
