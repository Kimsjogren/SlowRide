import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/models/alert_model.dart';
import 'package:slowride/services/trafikverket_service.dart';

AlertModel _alert({
  required String id,
  required AlertType type,
  required double latitude,
}) {
  return AlertModel(
    id: id,
    type: type,
    position: LatLng(latitude, 18.0),
    description: '',
    upvotes: 0,
    createdAt: DateTime.now(),
  );
}

void main() {
  group('road closure warnings', () {
    test('round-trips the persisted community alert key', () {
      expect(AlertType.roadClosure.key, 'road_closure');
      expect(AlertTypeX.fromKey('road_closure'), AlertType.roadClosure);
    });

    test('prioritizes a road closure over a closer lower-priority warning', () {
      const position = LatLng(59.0, 18.0);
      final selected = AlertModel.mostRelevantNearby([
        _alert(id: 'hazard', type: AlertType.hazard, latitude: 59.0005),
        _alert(id: 'closure', type: AlertType.roadClosure, latitude: 59.006),
      ], position);

      expect(selected?.id, 'closure');
    });

    test('does not show community places as driving warnings', () {
      const position = LatLng(59.0, 18.0);
      final selected = AlertModel.mostRelevantNearby([
        _alert(id: 'meetup', type: AlertType.meetup, latitude: 59.0001),
        _alert(id: 'parking', type: AlertType.parking, latitude: 59.0001),
      ], position);

      expect(selected, isNull);
    });

    test('honors a dismissed warning id', () {
      const position = LatLng(59.0, 18.0);
      final selected = AlertModel.mostRelevantNearby(
        [_alert(id: 'closure', type: AlertType.roadClosure, latitude: 59.001)],
        position,
        excludedId: 'closure',
      );

      expect(selected, isNull);
    });

    test(
      'suppresses the same nearby warning after a refresh with a new id',
      () {
        const position = LatLng(59.0, 18.0);
        final dismissed = _alert(
          id: 'roadwork_old',
          type: AlertType.roadwork,
          latitude: 59.0010,
        );
        final selected = AlertModel.mostRelevantNearby(
          [
            _alert(
              id: 'roadwork_new',
              type: AlertType.roadwork,
              latitude: 59.0011,
            ),
          ],
          position,
          dismissedAlert: dismissed,
        );

        expect(selected, isNull);
      },
    );
  });

  group('Trafikverket alert classification', () {
    test('recognizes a Swedish closed-road header before roadwork', () {
      expect(
        TrafikverketService.classifyAlert(
          iconId: 'roadwork',
          messageCode: 'vägarbete',
          header: 'Vägen avstängd i båda riktningar',
        ),
        AlertType.roadClosure,
      );
    });

    test('recognizes queues and speed cameras', () {
      expect(
        TrafikverketService.classifyAlert(iconId: 'queue', messageCode: ''),
        AlertType.trafficJam,
      );
      expect(
        TrafikverketService.classifyAlert(
          iconId: '',
          messageCode: 'speedCamera',
        ),
        AlertType.speedCamera,
      );
    });
  });
}
