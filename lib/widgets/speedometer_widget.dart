import 'package:flutter/material.dart';
import 'package:slowride/l10n/app_localizations.dart';

class SpeedometerWidget extends StatelessWidget {
  const SpeedometerWidget({
    super.key,
    required this.speedValue,
    required this.speedUnitLabel,
    required this.maxSpeedValue,
    required this.isOverSpeed,
    this.statusText,
  });

  final double speedValue;
  final String speedUnitLabel;
  final double maxSpeedValue;
  final bool isOverSpeed;
  final String? statusText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      color: isOverSpeed ? theme.colorScheme.errorContainer : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isOverSpeed ? theme.colorScheme.error : Colors.transparent,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.speedometerLiveSpeed,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${speedValue.toStringAsFixed(0)} $speedUnitLabel',
                  style:
                      (isOverSpeed
                              ? theme.textTheme.headlineMedium
                              : theme.textTheme.headlineSmall)
                          ?.copyWith(
                            color: isOverSpeed ? theme.colorScheme.error : null,
                            fontWeight: isOverSpeed
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.speedometerMaxSpeedWithUnit(
                  maxSpeedValue.toStringAsFixed(0),
                  speedUnitLabel,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (isOverSpeed) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.speedometerSlowDown,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (statusText != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  statusText!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
