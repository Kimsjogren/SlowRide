import 'package:flutter/material.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/services/user_preferences_service.dart';
import 'package:slowride/widgets/app_background.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final preferences = UserPreferencesService.instance;

    const labelStyle = TextStyle(color: Colors.white70, fontSize: 13);
    const valueStyle = TextStyle(color: Colors.white, fontSize: 16);

    return AppBackground(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inställningar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<String>(
                  valueListenable: preferences.vehicleType,
                  builder: (context, vehicleType, _) {
                    return DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF0A1F63),
                      style: valueStyle,
                      iconEnabledColor: Colors.white70,
                      initialValue: vehicleType,
                      decoration: InputDecoration(
                        labelText: l10n.settingsVehicleTypeLabel,
                        labelStyle: labelStyle,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'A-tractor',
                          child: Text(l10n.settingsVehicleAtractor),
                        ),
                        DropdownMenuItem(
                          value: 'Moped car',
                          child: Text(l10n.settingsVehicleMopedCar),
                        ),
                        DropdownMenuItem(
                          value: 'Tractor',
                          child: Text(l10n.settingsVehicleTractor),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          preferences.vehicleType.value = value;
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<String?>(
                  valueListenable: preferences.languageCode,
                  builder: (context, languageCode, _) {
                    return DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF0A1F63),
                      style: valueStyle,
                      iconEnabledColor: Colors.white70,
                      initialValue: languageCode ?? 'system',
                      decoration: InputDecoration(
                        labelText: l10n.settingsLanguageLabel,
                        labelStyle: labelStyle,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'system',
                          child: Text(l10n.settingsLanguageSystem),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(l10n.settingsLanguageEnglish),
                        ),
                        DropdownMenuItem(
                          value: 'sv',
                          child: Text(l10n.settingsLanguageSwedish),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null || value == 'system') {
                          preferences.languageCode.value = null;
                          return;
                        }
                        preferences.languageCode.value = value;
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String?>(
                  valueListenable: preferences.languageCode,
                  builder: (context, languageCode, _) {
                    final currentMode = switch (languageCode) {
                      'en' => l10n.settingsLanguageEnglish,
                      'sv' => l10n.settingsLanguageSwedish,
                      _ => l10n.settingsLanguageSystem,
                    };
                    return Text(
                      l10n.settingsLanguageCurrentlyUsing(currentMode),
                      style: labelStyle,
                    );
                  },
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<SpeedUnit>(
                  valueListenable: preferences.speedUnit,
                  builder: (context, unit, _) {
                    return SegmentedButton<SpeedUnit>(
                      segments: [
                        ButtonSegment(
                          value: SpeedUnit.kmh,
                          label: Text(l10n.settingsSpeedUnitKmh),
                        ),
                        ButtonSegment(
                          value: SpeedUnit.mph,
                          label: Text(l10n.settingsSpeedUnitMph),
                        ),
                      ],
                      selected: {unit},
                      onSelectionChanged: (selection) {
                        preferences.speedUnit.value = selection.first;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<SpeedUnit>(
                  valueListenable: preferences.speedUnit,
                  builder: (context, unit, _) {
                    return ValueListenableBuilder<double>(
                      valueListenable: preferences.maxSpeedKmh,
                      builder: (context, maxSpeedKmh, _) {
                        final maxSpeedDisplay = preferences.toDisplaySpeed(
                          speedKmh: maxSpeedKmh,
                          unit: unit,
                        );
                        final speedUnitLabel = unit == SpeedUnit.kmh
                            ? l10n.settingsSpeedUnitKmh
                            : l10n.settingsSpeedUnitMph;
                        final minDisplay = unit == SpeedUnit.kmh ? 20.0 : 12.0;
                        final maxDisplay = unit == SpeedUnit.kmh ? 45.0 : 28.0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.settingsMaxSpeedWithUnit(
                                maxSpeedDisplay.toStringAsFixed(0),
                                speedUnitLabel,
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Slider(
                              min: minDisplay,
                              max: maxDisplay,
                              divisions: (maxDisplay - minDisplay).round(),
                              value: maxSpeedDisplay.clamp(
                                minDisplay,
                                maxDisplay,
                              ),
                              label: maxSpeedDisplay.toStringAsFixed(0),
                              onChanged: (value) {
                                preferences.maxSpeedKmh.value = preferences
                                    .fromDisplaySpeed(value: value, unit: unit);
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
