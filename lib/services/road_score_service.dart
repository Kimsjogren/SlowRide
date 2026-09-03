import 'package:slowride/models/alert_model.dart';
import 'package:slowride/services/routing_service.dart';

enum RoadScoreGrade { excellent, good, caution, unverified }

class RoadScore {
  const RoadScore({
    required this.score,
    required this.grade,
    required this.isLegallyVerified,
    required this.alertCount,
    required this.complexTurnCount,
    required this.distanceDetourPercent,
    required this.durationDetourPercent,
    required this.alertCounts,
  });

  final int score;
  final RoadScoreGrade grade;
  final bool isLegallyVerified;
  final int alertCount;
  final int complexTurnCount;
  final int distanceDetourPercent;
  final int durationDetourPercent;
  final Map<AlertType, int> alertCounts;

  Map<String, Object> toAiFacts() => <String, Object>{
    'score': score,
    'grade': grade.name,
    'legally_verified': isLegallyVerified,
    'route_alert_count': alertCount,
    'complex_turn_count': complexTurnCount,
    'distance_detour_percent': distanceDetourPercent,
    'duration_detour_percent': durationDetourPercent,
    'factors': <String, int>{
      for (final entry in alertCounts.entries) entry.key.key: entry.value,
    },
  };
}

/// Deterministic, explainable route suitability score.
///
/// AI may explain these facts but never calculates or overrides the score.
class RoadScoreService {
  const RoadScoreService._();

  static RoadScore calculate({
    required RouteResult route,
    required bool isLegallyVerified,
    required Map<AlertType, int> alertCounts,
    double? shortestDistanceMeters,
    double? shortestDurationSeconds,
  }) {
    var score = 100.0;
    if (!isLegallyVerified) score -= 45;

    const alertWeights = <AlertType, double>{
      AlertType.roadClosure: 30,
      AlertType.accident: 12,
      AlertType.narrowRoad: 9,
      AlertType.steepHill: 8,
      AlertType.hazard: 7,
      AlertType.roadwork: 6,
      AlertType.trafficJam: 5,
      AlertType.speedBump: 5,
    };
    var relevantAlertCount = 0;
    for (final entry in alertCounts.entries) {
      final weight = alertWeights[entry.key];
      if (weight == null || entry.value <= 0) continue;
      relevantAlertCount += entry.value;
      score -= (weight * entry.value).clamp(0, weight * 3);
    }

    final complexTurnCount = route.instructions.where((instruction) {
      final sign = instruction.sign.abs();
      return sign >= 2 || sign == 6;
    }).length;
    score -= (complexTurnCount / 4).floor().clamp(0, 10);

    final distanceDetourPercent = _detourPercent(
      route.distanceMeters,
      shortestDistanceMeters,
    );
    final durationDetourPercent = _detourPercent(
      route.durationSeconds,
      shortestDurationSeconds,
    );
    score -= ((distanceDetourPercent - 10).clamp(0, 40) / 5).round();
    score -= ((durationDetourPercent - 15).clamp(0, 40) / 5).round();

    final roundedScore = score.round().clamp(0, 100);
    final grade = !isLegallyVerified
        ? RoadScoreGrade.unverified
        : roundedScore >= 85
        ? RoadScoreGrade.excellent
        : roundedScore >= 70
        ? RoadScoreGrade.good
        : RoadScoreGrade.caution;

    return RoadScore(
      score: roundedScore,
      grade: grade,
      isLegallyVerified: isLegallyVerified,
      alertCount: relevantAlertCount,
      complexTurnCount: complexTurnCount,
      distanceDetourPercent: distanceDetourPercent,
      durationDetourPercent: durationDetourPercent,
      alertCounts: Map.unmodifiable(alertCounts),
    );
  }

  static int _detourPercent(double value, double? shortest) {
    if (shortest == null || shortest <= 0 || value <= shortest) return 0;
    return (((value / shortest) - 1) * 100).round().clamp(0, 999);
  }
}
