import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slowride/core/constants/legal_links.dart';
import 'package:slowride/features/paywall/paywall_screen.dart';
import 'package:slowride/features/settings/parent_settings_screen.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/services/ad_service.dart';
import 'package:slowride/services/subscription_service.dart';
import 'package:slowride/services/tts_service.dart';
import 'package:slowride/services/user_preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:slowride/widgets/ad_banner_widget.dart';
import 'package:slowride/widgets/app_background.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static final Uri _privacyPolicyUri = Uri.parse(LegalLinks.privacyPolicy);
  static final Uri _termsOfUseUri = Uri.parse(LegalLinks.termsOfUse);

  Future<void> _openExternalLink(BuildContext context, Uri uri) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsLinkOpenFailed)));
  }

  Future<void> _restorePurchase(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final restored = await SubscriptionService.instance.restorePurchase();
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            restored ? l10n.paywallRestoreSuccess : l10n.paywallRestoreNotFound,
          ),
        ),
      );
    } on PlatformException catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message ?? l10n.settingsRestorePurchaseFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final preferences = UserPreferencesService.instance;

    const labelStyle = TextStyle(color: Colors.white70, fontSize: 13);
    const valueStyle = TextStyle(color: Colors.white, fontSize: 16);

    return AppBackground(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsTitle,
                        style: const TextStyle(
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
                              final maxSpeedDisplay = preferences
                                  .toDisplaySpeed(
                                    speedKmh: maxSpeedKmh,
                                    unit: unit,
                                  );
                              final speedUnitLabel = unit == SpeedUnit.kmh
                                  ? l10n.settingsSpeedUnitKmh
                                  : l10n.settingsSpeedUnitMph;
                              final minDisplay = unit == SpeedUnit.kmh
                                  ? 20.0
                                  : 12.0;
                              final maxDisplay = unit == SpeedUnit.kmh
                                  ? 45.0
                                  : 28.0;

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
                                    divisions: (maxDisplay - minDisplay)
                                        .round(),
                                    value: maxSpeedDisplay.clamp(
                                      minDisplay,
                                      maxDisplay,
                                    ),
                                    label: maxSpeedDisplay.toStringAsFixed(0),
                                    onChanged: (value) {
                                      preferences.maxSpeedKmh.value =
                                          preferences.fromDisplaySpeed(
                                            value: value,
                                            unit: unit,
                                          );
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
                const SizedBox(height: 16),
                // Voice navigation toggle
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: TtsService.instance.enabled,
                    builder: (context, ttsEnabled, _) {
                      return SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.settingsVoiceNavigation,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          l10n.settingsVoiceNavigationSubtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 13,
                          ),
                        ),
                        secondary: Icon(
                          ttsEnabled ? Icons.volume_up : Icons.volume_off,
                          color: ttsEnabled
                              ? const Color(0xFF00C8FF)
                              : Colors.white38,
                        ),
                        value: ttsEnabled,
                        activeColor: const Color(0xFF00C8FF),
                        onChanged: (v) => TtsService.instance.enabled.value = v,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Parent Mode card
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ParentSettingsScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00C8FF,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.family_restroom,
                            color: Color(0xFF00C8FF),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.parentModeTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.parentModeDescription,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: SubscriptionService.instance.isPro,
                  builder: (context, isPro, _) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.workspace_premium_rounded,
                                color: Color(0xFFFFD166),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.settingsProCardTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isPro
                                      ? const Color(0x3328C76F)
                                      : const Color(0x33FFFFFF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isPro
                                        ? const Color(0x6628C76F)
                                        : const Color(0x33FFFFFF),
                                  ),
                                ),
                                child: Text(
                                  isPro
                                      ? l10n.settingsProStatusActive
                                      : l10n.settingsProStatusInactive,
                                  style: TextStyle(
                                    color: isPro
                                        ? const Color(0xFF7FF0AA)
                                        : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isPro
                                ? l10n.settingsProDescriptionActive
                                : l10n.settingsProDescriptionInactive,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (!isPro)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const PaywallScreen(),
                                    ),
                                  );
                                },
                                child: Text(l10n.paywallUpgradeButton),
                              ),
                            ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _restorePurchase(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(l10n.paywallRestoreButton),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 0,
                            children: [
                              TextButton(
                                onPressed: () => _openExternalLink(
                                  context,
                                  _privacyPolicyUri,
                                ),
                                child: Text(l10n.settingsPrivacyPolicyLabel),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _openExternalLink(context, _termsOfUseUri),
                                child: Text(l10n.settingsTermsOfUseLabel),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          AdBannerWidget(adUnitId: AdService.instance.bannerSettingsUnitId),
        ],
      ),
    );
  }
}
