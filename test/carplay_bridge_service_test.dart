import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:slowride/services/carplay_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('cruizx/carplay');

  test(
    'CarPlay route geometry is serialized and duplicate updates are skipped',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      const points = [LatLng(59.3293, 18.0686), LatLng(59.3320, 18.0750)];
      const destination = LatLng(59.3320, 18.0750);

      await CarPlayBridgeService.instance.updateRouteGeometry(
        routePoints: points,
        destination: destination,
      );
      await CarPlayBridgeService.instance.updateRouteGeometry(
        routePoints: points,
        destination: destination,
      );

      expect(calls, hasLength(1));
      expect(calls.single.method, 'syncRouteGeometry');
      final payload = Map<String, dynamic>.from(calls.single.arguments as Map);
      expect(payload['points'] as List, hasLength(2));
      expect(
        Map<String, dynamic>.from(payload['destination'] as Map),
        {'latitude': 59.3320, 'longitude': 18.0750},
      );
    },
  );

  test(
    'CarPlay convoy members are serialized and duplicate updates are skipped',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final members = <Map<String, Object?>>[
        {
          'userId': 'member-1',
          'label': 'Kim',
          'latitude': 59.3293,
          'longitude': 18.0686,
          'assetPath': 'assets/test-car.png',
        },
      ];

      await CarPlayBridgeService.instance.updateConvoyState(
        isActive: true,
        convoyName: 'Kvällsturen',
        currentUserId: 'me',
        members: members,
      );
      await CarPlayBridgeService.instance.updateConvoyState(
        isActive: true,
        convoyName: 'Kvällsturen',
        currentUserId: 'me',
        members: members,
      );

      expect(calls, hasLength(1));
      expect(calls.single.method, 'syncConvoyState');
      final payload = Map<String, dynamic>.from(calls.single.arguments as Map);
      expect(payload['isActive'], isTrue);
      expect(payload['convoyName'], 'Kvällsturen');
      expect(payload['members'] as List, hasLength(1));
    },
  );
}
