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

  test('traffic reroute proposal returns native driver choice', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return true;
        });
    CarPlayBridgeService.instance.isConnected.value = true;
    addTearDown(() {
      CarPlayBridgeService.instance.isConnected.value = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final accepted = await CarPlayBridgeService.instance
        .showTrafficRerouteProposal(
          title: 'Snabbare rutt hittad',
          body: 'Sparar cirka 6 minuter.',
          keepLabel: 'Behåll',
          useLabel: 'Byt rutt',
        );

    expect(accepted, isTrue);
    expect(received?.method, 'showTrafficRerouteProposal');
    final payload = Map<String, dynamic>.from(received!.arguments as Map);
    expect(payload['title'], 'Snabbare rutt hittad');
    expect(payload['timeoutSeconds'], 20);
    expect(payload['id'], isNotEmpty);
  });

  test('traffic reroute proposal is skipped without a car screen', () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls++;
          return true;
        });
    CarPlayBridgeService.instance.isConnected.value = false;
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final result = await CarPlayBridgeService.instance
        .showTrafficRerouteProposal(
          title: 'Title',
          body: 'Body',
          keepLabel: 'Keep',
          useLabel: 'Use',
        );

    expect(result, isNull);
    expect(calls, 0);
  });
}
