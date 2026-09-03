import 'package:flutter_test/flutter_test.dart';
import 'package:slowride/services/traffic_reroute_policy.dart';

void main() {
  test('warns only for meaningful traffic with enough route remaining', () {
    expect(
      TrafficReroutePolicy.shouldWarn(
        trafficDelaySeconds: 89,
        remainingDistanceMeters: 10000,
      ),
      isFalse,
    );
    expect(
      TrafficReroutePolicy.shouldWarn(
        trafficDelaySeconds: 600,
        remainingDistanceMeters: 799,
      ),
      isFalse,
    );
    expect(
      TrafficReroutePolicy.shouldWarn(
        trafficDelaySeconds: 90,
        remainingDistanceMeters: 800,
      ),
      isTrue,
    );
  });

  test(
    'searches only for meaningful congestion on a useful remaining route',
    () {
      expect(
        TrafficReroutePolicy.shouldSearch(
          trafficDelaySeconds: 179,
          remainingDistanceMeters: 10000,
        ),
        isFalse,
      );
      expect(
        TrafficReroutePolicy.shouldSearch(
          trafficDelaySeconds: 600,
          remainingDistanceMeters: 1499,
        ),
        isFalse,
      );
      expect(
        TrafficReroutePolicy.shouldSearch(
          trafficDelaySeconds: 180,
          remainingDistanceMeters: 1500,
        ),
        isTrue,
      );
    },
  );

  test('requires at least three minutes and eight percent saving', () {
    expect(
      TrafficReroutePolicy.shouldSuggest(
        currentEtaSeconds: 1800,
        candidateEtaSeconds: 1621,
      ),
      isFalse,
    );
    expect(
      TrafficReroutePolicy.shouldSuggest(
        currentEtaSeconds: 1800,
        candidateEtaSeconds: 1620,
      ),
      isTrue,
    );
    expect(
      TrafficReroutePolicy.shouldSuggest(
        currentEtaSeconds: 7200,
        candidateEtaSeconds: 6625,
      ),
      isFalse,
    );
    expect(
      TrafficReroutePolicy.shouldSuggest(
        currentEtaSeconds: 7200,
        candidateEtaSeconds: 6624,
      ),
      isTrue,
    );
  });
}
