import 'dart:math' as math;

/// Conservative rules for when CruizX may offer a traffic-based route change.
/// The policy never changes a route itself; it only decides whether a verified
/// candidate saves enough time to be worth distracting the driver.
class TrafficReroutePolicy {
  const TrafficReroutePolicy._();

  static const double warningDelaySeconds = 90;
  static const double warningRemainingDistanceMeters = 800;
  static const double minimumTrafficDelaySeconds = 180;
  static const double minimumRemainingDistanceMeters = 1500;
  static const double minimumSavingSeconds = 180;
  static const double minimumSavingFraction = 0.08;

  static bool shouldWarn({
    required double trafficDelaySeconds,
    required double remainingDistanceMeters,
  }) =>
      trafficDelaySeconds >= warningDelaySeconds &&
      remainingDistanceMeters >= warningRemainingDistanceMeters;

  static bool shouldSearch({
    required double trafficDelaySeconds,
    required double remainingDistanceMeters,
  }) =>
      trafficDelaySeconds >= minimumTrafficDelaySeconds &&
      remainingDistanceMeters >= minimumRemainingDistanceMeters;

  static double requiredSavingSeconds(double currentEtaSeconds) => math.max(
    minimumSavingSeconds,
    currentEtaSeconds * minimumSavingFraction,
  );

  static bool shouldSuggest({
    required double currentEtaSeconds,
    required double candidateEtaSeconds,
  }) {
    if (currentEtaSeconds <= 0 || candidateEtaSeconds <= 0) return false;
    return currentEtaSeconds - candidateEtaSeconds >=
        requiredSavingSeconds(currentEtaSeconds);
  }
}
