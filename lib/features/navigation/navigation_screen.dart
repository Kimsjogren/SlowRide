import 'package:flutter/material.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/widgets/feature_placeholder.dart';

class NavigationScreen extends StatelessWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FeaturePlaceholder(
      title: l10n.navigationTitle,
      subtitle: l10n.navigationSubtitle,
      icon: Icons.alt_route,
    );
  }
}
