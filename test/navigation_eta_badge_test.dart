import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slowride/widgets/navigation_eta_badge.dart';

void main() {
  testWidgets('shows remaining time and estimated arrival separately', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NavigationEtaBadge(eta: '12 min · 14:35')),
      ),
    );

    expect(find.text('12 min'), findsOneWidget);
    expect(find.text('14:35'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
  });

  testWidgets('stays hidden until an ETA is available', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NavigationEtaBadge(eta: '')),
      ),
    );

    expect(find.byType(Container), findsNothing);
  });
}
