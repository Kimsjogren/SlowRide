import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/models/alert_model.dart';
import 'package:slowride/services/road_score_service.dart';
import 'package:slowride/services/routing_service.dart';

void main() {
  const safeRoute = RouteResult(
    points: [LatLng(59.3, 18.0), LatLng(59.4, 18.1)],
    distanceMeters: 10000,
    durationSeconds: 1800,
    instructions: [
      RouteInstruction(
        sign: 0,
        text: 'Continue',
        distanceMeters: 9000,
        pointIndex: 0,
      ),
      RouteInstruction(
        sign: 4,
        text: 'Arrive',
        distanceMeters: 0,
        pointIndex: 1,
      ),
    ],
  );

  test('gives a clean verified route an excellent score', () {
    final result = RoadScoreService.calculate(
      route: safeRoute,
      isLegallyVerified: true,
      alertCounts: const {},
      shortestDistanceMeters: 10000,
      shortestDurationSeconds: 1800,
    );

    expect(result.score, 100);
    expect(result.grade, RoadScoreGrade.excellent);
  });

  test('never presents an unverified route as good', () {
    final result = RoadScoreService.calculate(
      route: safeRoute,
      isLegallyVerified: false,
      alertCounts: const {},
    );

    expect(result.score, 55);
    expect(result.grade, RoadScoreGrade.unverified);
  });

  test('penalizes verified road hazards with bounded duplicate impact', () {
    final result = RoadScoreService.calculate(
      route: safeRoute,
      isLegallyVerified: true,
      alertCounts: const {
        AlertType.roadClosure: 1,
        AlertType.speedBump: 8,
      },
    );

    expect(result.score, 55);
    expect(result.alertCount, 9);
    expect(result.grade, RoadScoreGrade.caution);
  });
}
