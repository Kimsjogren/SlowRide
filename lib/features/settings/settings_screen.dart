import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slowride/core/constants/backend_config.dart';
import 'package:slowride/core/constants/legal_links.dart';
import 'package:slowride/features/paywall/paywall_screen.dart';
import 'package:slowride/features/settings/parent_settings_screen.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/models/country_vehicle_rules.dart';
import 'package:slowride/services/ad_service.dart';
import 'package:slowride/services/subscription_service.dart';
import 'package:slowride/services/tts_service.dart';
import 'package:slowride/services/user_preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:slowride/widgets/ad_banner_widget.dart';
import 'package:slowride/widgets/app_background.dart';
import 'package:slowride/widgets/user_location_marker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static final Uri _privacyPolicyUri = Uri.parse(LegalLinks.privacyPolicy);
  static final Uri _termsOfUseUri = Uri.parse(LegalLinks.termsOfUse);
  static final Uri _supportUri = Uri.parse(LegalLinks.support);

  static Widget _proFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CD964), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

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
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          backgroundColor: restored
              ? const Color(0xFF00913F)
              : Colors.redAccent.withValues(alpha: 0.85),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } on PlatformException catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? l10n.settingsRestorePurchaseFailed,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                                value: 'Low vehicle',
                                child: Text(l10n.settingsVehicleLowVehicle),
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
                      // Country selector — affects routing rules and speed limits.
                      ValueListenableBuilder<String>(
                        valueListenable: preferences.countryCode,
                        builder: (context, country, _) {
                          return DropdownButtonFormField<String>(
                            dropdownColor: const Color(0xFF0A1F63),
                            style: valueStyle,
                            iconEnabledColor: Colors.white70,
                            initialValue: country,
                            decoration: InputDecoration(
                              labelText: l10n.settingsCountryLabel,
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
                                value: 'SE',
                                child: Text(l10n.settingsCountrySweden),
                              ),
                              DropdownMenuItem(
                                value: 'NO',
                                child: Text(l10n.settingsCountryNorway),
                              ),
                              DropdownMenuItem(
                                value: 'DK',
                                child: Text(l10n.settingsCountryDenmark),
                              ),
                              DropdownMenuItem(
                                value: 'FI',
                                child: Text(l10n.settingsCountryFinland),
                              ),
                              DropdownMenuItem(
                                value: 'FR',
                                child: Text(l10n.settingsCountryFrance),
                              ),
                              DropdownMenuItem(
                                value: 'ES',
                                child: Text(l10n.settingsCountrySpain),
                              ),
                              DropdownMenuItem(
                                value: 'IT',
                                child: Text(l10n.settingsCountryItaly),
                              ),
                              DropdownMenuItem(
                                value: 'GB',
                                child: Text(l10n.settingsCountryUnitedKingdom),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                preferences.countryCode.value = value;
                                // Auto-set language to match the selected country.
                                final syncedLanguage = switch (value) {
                                  'SE' => 'sv',
                                  'NO' => 'nb',
                                  'DK' => 'da',
                                  'FI' => 'fi',
                                  'FR' => 'fr',
                                  'ES' => 'es',
                                  'IT' => 'it',
                                  'GB' => 'en',
                                  _ => null,
                                };
                                if (syncedLanguage != null) {
                                  preferences.languageCode.value =
                                      syncedLanguage;
                                }
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.settingsCountryHint,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
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
                              DropdownMenuItem(
                                value: 'fr',
                                child: Text(l10n.settingsLanguageFrench),
                              ),
                              DropdownMenuItem(
                                value: 'nb',
                                child: Text(l10n.settingsLanguageNorwegian),
                              ),
                              DropdownMenuItem(
                                value: 'da',
                                child: Text(l10n.settingsLanguageDanish),
                              ),
                              DropdownMenuItem(
                                value: 'fi',
                                child: Text(l10n.settingsLanguageFinnish),
                              ),
                              DropdownMenuItem(
                                value: 'es',
                                child: Text(l10n.settingsLanguageSpanish),
                              ),
                              DropdownMenuItem(
                                value: 'it',
                                child: Text(l10n.settingsLanguageItalian),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null || value == 'system') {
                                preferences.languageCode.value = null;
                                return;
                              }
                              preferences.languageCode.value = value;
                              // Sync country to match the selected language.
                              final syncedCountry = switch (value) {
                                'sv' => 'SE',
                                'nb' => 'NO',
                                'da' => 'DK',
                                'fi' => 'FI',
                                'fr' => 'FR',
                                'es' => 'ES',
                                'it' => 'IT',
                                _ => null,
                              };
                              if (syncedCountry != null) {
                                preferences.countryCode.value = syncedCountry;
                              }
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
                            'fr' => l10n.settingsLanguageFrench,
                            'nb' => l10n.settingsLanguageNorwegian,
                            'da' => l10n.settingsLanguageDanish,
                            'fi' => l10n.settingsLanguageFinnish,
                            'es' => l10n.settingsLanguageSpanish,
                            'it' => l10n.settingsLanguageItalian,
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
                      ValueListenableBuilder<String>(
                        valueListenable: preferences.countryCode,
                        builder: (context, country, _) {
                          return ValueListenableBuilder<SpeedUnit>(
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
                                  // Slider max = legal limit + 5 km/h so the
                                  // user can fine-tune for their actual avg speed.
                                  final legalMax =
                                      CountryVehicleRules.maxLegalSpeedFor(
                                        country,
                                        preferences.vehicleType.value,
                                      );
                                  final sliderMaxKmh = legalMax + 5.0;
                                  final minDisplay = unit == SpeedUnit.kmh
                                      ? 15.0
                                      : 9.0;
                                  final maxDisplay = unit == SpeedUnit.kmh
                                      ? sliderMaxKmh
                                      : preferences.toDisplaySpeed(
                                          speedKmh: sliderMaxKmh,
                                          unit: unit,
                                        );

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        label: maxSpeedDisplay.toStringAsFixed(
                                          0,
                                        ),
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
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                  child: ValueListenableBuilder<MapMarkerStyle>(
                    valueListenable: preferences.mapMarkerStyle,
                    builder: (context, markerStyle, _) {
                      final sections = _markerVehicleSections(l10n);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.settingsMapMarkerLabel, style: labelStyle),
                          const SizedBox(height: 14),
                          ...sections.map(
                            (section) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _MarkerVehicleSection(
                                section: section,
                                selectedStyle: markerStyle,
                                onSelected: (style) =>
                                    preferences.mapMarkerStyle.value = style,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
                      return Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
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
                          activeThumbColor: const Color(0xFF00C8FF),
                          onChanged: (v) =>
                              TtsService.instance.enabled.value = v,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Vector map toggle
                ValueListenableBuilder<bool>(
                  valueListenable: UserPreferencesService.instance.useVectorMap,
                  builder: (context, useVector, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l10n.settingsVectorMap,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            useVector
                                ? l10n.settingsVectorMapOn
                                : l10n.settingsVectorMapOff,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 13,
                            ),
                          ),
                          secondary: Icon(
                            Icons.map_outlined,
                            color: useVector
                                ? const Color(0xFF00C8FF)
                                : Colors.white38,
                          ),
                          value: useVector,
                          activeThumbColor: const Color(0xFF00C8FF),
                          onChanged: (v) =>
                              UserPreferencesService
                                      .instance
                                      .useVectorMap
                                      .value =
                                  v,
                        ),
                      ),
                    );
                  },
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
                          // ── Title row ────────────────────────────
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

                          // ── Price ────────────────────────────────
                          if (!isPro)
                            ValueListenableBuilder<String?>(
                              valueListenable:
                                  SubscriptionService.instance.localizedPrice,
                              builder: (_, price, _) {
                                final displayPrice =
                                    (price != null && price.isNotEmpty)
                                    ? l10n.settingsProPricePerMonth(price)
                                    : (SubscriptionService
                                              .instance
                                              .isWebCheckout
                                          ? l10n.settingsProPricePerMonth(
                                              BackendConfig
                                                  .webCheckoutDisplayPrice,
                                            )
                                          : null);
                                if (displayPrice == null) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    displayPrice,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              },
                            ),

                          const SizedBox(height: 16),

                          // ── Feature list ─────────────────────────
                          if (!isPro) ...[
                            _proFeatureRow(l10n.settingsProFeatureRoutes),
                            _proFeatureRow(l10n.settingsProFeatureConvoy),
                            _proFeatureRow(l10n.settingsProFeatureAds),
                            _proFeatureRow(l10n.settingsProFeatureSupport),
                            const SizedBox(height: 18),
                          ],

                          if (isPro)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text(
                                l10n.settingsProDescriptionActive,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),

                          // ── Upgrade button ───────────────────────
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

                          // ── Restore button ───────────────────────
                          if (!kIsWeb)
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

                          // ── Subscription note ────────────────────
                          if (!isPro && !kIsWeb) ...[
                            const SizedBox(height: 14),
                            Text(
                              l10n.settingsProSubscriptionNote,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // ── Legal links ──────────────────────────
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
                              TextButton(
                                onPressed: () =>
                                    _openExternalLink(context, _supportUri),
                                child: Text(l10n.settingsSupportLabel),
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

class _MarkerStyleChoice extends StatelessWidget {
  const _MarkerStyleChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 102,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.18),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Center(
          child: Semantics(label: label, selected: selected, child: child),
        ),
      ),
    );
  }
}

class _MarkerVehicleSection extends StatelessWidget {
  const _MarkerVehicleSection({
    required this.section,
    required this.selectedStyle,
    required this.onSelected,
  });

  final _MarkerVehicleGroup section;
  final MapMarkerStyle selectedStyle;
  final ValueChanged<MapMarkerStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ...section.brands.map(
          (brand) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MarkerBrandSection(
              brand: brand,
              selectedStyle: selectedStyle,
              onSelected: onSelected,
              l10n: l10n,
            ),
          ),
        ),
      ],
    );
  }
}

class _MarkerBrandSection extends StatelessWidget {
  const _MarkerBrandSection({
    required this.brand,
    required this.selectedStyle,
    required this.onSelected,
    required this.l10n,
  });

  final _MarkerBrandGroup brand;
  final MapMarkerStyle selectedStyle;
  final ValueChanged<MapMarkerStyle> onSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: brand.options.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final option = brand.options[index];
              final selected = option.style == selectedStyle;
              final color = option.colorName(l10n);
              final label = color == null
                  ? option.label(l10n)
                  : '${option.label(l10n)} $color';
              return _MarkerStyleChoice(
                label: label,
                selected: selected,
                onTap: () => onSelected(option.style),
                child: UserLocationMarker.stylePreview(
                  option.style,
                  size: 74,
                  selected: selected,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MarkerVehicleGroup {
  const _MarkerVehicleGroup({required this.title, required this.brands});

  final String title;
  final List<_MarkerBrandGroup> brands;
}

class _MarkerBrandGroup {
  const _MarkerBrandGroup({required this.title, required this.options});

  final String title;
  final List<MapMarkerOption> options;
}

List<_MarkerVehicleGroup> _markerVehicleSections(AppLocalizations l10n) {
  List<MapMarkerOption> byCategory(MapMarkerCategory category) =>
      UserLocationMarker.optionsForCategory(category);

  List<MapMarkerOption> byStyles(List<MapMarkerStyle> styles) {
    return styles.map(UserLocationMarker.optionFor).toList(growable: false);
  }

  return [
    _MarkerVehicleGroup(
      title: l10n.settingsVehicleAtractor,
      brands: [
        _MarkerBrandGroup(
          title: l10n.settingsMapMarkerPickup,
          options: byCategory(MapMarkerCategory.pickup),
        ),
        _MarkerBrandGroup(
          title: l10n.settingsMapMarkerMini,
          options: byStyles([
            MapMarkerStyle.miniOrange,
            MapMarkerStyle.miniGreen,
            MapMarkerStyle.miniWhite,
            MapMarkerStyle.miniBlue,
            MapMarkerStyle.miniPink,
          ]),
        ),
        _MarkerBrandGroup(
          title: l10n.settingsMapMarkerBmw,
          options: byStyles([
            MapMarkerStyle.bmwRed,
            MapMarkerStyle.bmwOrange,
            MapMarkerStyle.bmwSilver,
            MapMarkerStyle.bmwPink,
          ]),
        ),
      ],
    ),
    _MarkerVehicleGroup(
      title: l10n.settingsVehicleMopedCar,
      brands: [
        _MarkerBrandGroup(
          title: l10n.settingsMapMarkerCategoryAixam,
          options: byCategory(MapMarkerCategory.aixam),
        ),
        _MarkerBrandGroup(
          title: 'Microcar',
          options: byCategory(MapMarkerCategory.microcar),
        ),
        _MarkerBrandGroup(
          title: l10n.settingsMapMarkerCategoryLigier,
          options: byCategory(MapMarkerCategory.ligier),
        ),
      ],
    ),
    _MarkerVehicleGroup(
      title: l10n.settingsVehicleTractor,
      brands: [
        _MarkerBrandGroup(
          title: l10n.settingsVehicleTractor,
          options: byCategory(MapMarkerCategory.tractor),
        ),
      ],
    ),
  ];
}
