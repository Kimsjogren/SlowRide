import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slowride/widgets/accessible_tap_target.dart';

void main() {
  testWidgets('exposes a named button and activates through semantics', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccessibleTapTarget(
            label: 'Center the map on my location',
            onTap: () => taps++,
            child: const Icon(Icons.my_location),
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(AccessibleTapTarget));
    expect(
      semantics,
      matchesSemantics(
        label: 'Center the map on my location',
        isButton: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byType(AccessibleTapTarget));
    expect(taps, 1);
  });
}
