import 'package:flutter/material.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/widgets/app_background.dart';
import 'package:slowride/widgets/feature_placeholder.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppBackground(
      child: FeaturePlaceholder(
        title: l10n.alertsTitle,
        subtitle: l10n.alertsSubtitle,
        icon: Icons.warning_amber,
      ),
    );
  }
}
