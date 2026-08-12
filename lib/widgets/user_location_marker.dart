import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/services/user_preferences_service.dart';

enum MapMarkerCategory {
  classic,
  ligier,
  aixam,
  microcar,
  pickup,
  atraktor,
  tractor,
  mopedScooter,
  mopedCross,
  electricScooter,
}

class MapMarkerOption {
  const MapMarkerOption({
    required this.style,
    required this.category,
    required this.assetPath,
    required this.labelBuilder,
    this.colorNameBuilder,
    this.rotatesWithHeading = false,
    this.tint,
  });

  final MapMarkerStyle style;
  final MapMarkerCategory category;
  final String? assetPath;
  final String Function(AppLocalizations l10n) labelBuilder;
  final String Function(AppLocalizations l10n)? colorNameBuilder;
  final bool rotatesWithHeading;
  final Color? tint;

  String label(AppLocalizations l10n) => labelBuilder(l10n);

  String? colorName(AppLocalizations l10n) => colorNameBuilder?.call(l10n);
}

class UserLocationMarker extends StatelessWidget {
  const UserLocationMarker({
    super.key,
    required this.headingNotifier,
    required this.lockNorthUp,
    this.size = 38,
    this.backgroundColor = const Color(0xFF1E90FF),
    this.borderColor = Colors.white,
    this.borderWidth = 2.5,
    this.showOuterGlow = true,
  });

  final ValueNotifier<double> headingNotifier;
  final bool lockNorthUp;
  final double size;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final bool showOuterGlow;

  static const List<MapMarkerOption> options = [
    MapMarkerOption(
      style: MapMarkerStyle.navigation,
      category: MapMarkerCategory.classic,
      assetPath: null,
      labelBuilder: _arrowLabel,
      rotatesWithHeading: true,
      tint: Color(0xFF1E90FF),
    ),
    MapMarkerOption(
      style: MapMarkerStyle.compass,
      category: MapMarkerCategory.classic,
      assetPath: null,
      labelBuilder: _compassLabel,
      rotatesWithHeading: true,
      tint: Color(0xFF00BFA5),
    ),
    MapMarkerOption(
      style: MapMarkerStyle.triangle,
      category: MapMarkerCategory.classic,
      assetPath: null,
      labelBuilder: _triangleLabel,
      rotatesWithHeading: true,
      tint: Color(0xFF6C63FF),
    ),
    MapMarkerOption(
      style: MapMarkerStyle.dot,
      category: MapMarkerCategory.classic,
      assetPath: null,
      labelBuilder: _dotLabel,
      rotatesWithHeading: true,
      tint: Color(0xFF19A7FF),
    ),
    MapMarkerOption(
      style: MapMarkerStyle.scooterBlack,
      category: MapMarkerCategory.mopedScooter,
      assetPath: 'assets/Moped/scooter_black_transparent.png',
      labelBuilder: _scooterLabel,
      colorNameBuilder: _blackLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.scooterBlue,
      category: MapMarkerCategory.mopedScooter,
      assetPath: 'assets/Moped/scooter_blue_transparent.png',
      labelBuilder: _scooterLabel,
      colorNameBuilder: _blueLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.scooterGold,
      category: MapMarkerCategory.mopedScooter,
      assetPath: 'assets/Moped/scooter_gold_transparent.png',
      labelBuilder: _scooterLabel,
      colorNameBuilder: _goldLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.scooterRed,
      category: MapMarkerCategory.mopedScooter,
      assetPath: 'assets/Moped/scooter_red_transparent.png',
      labelBuilder: _scooterLabel,
      colorNameBuilder: _redLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.crossMopedBlack,
      category: MapMarkerCategory.mopedCross,
      assetPath: 'assets/Moped/cross_black_transparent.png',
      labelBuilder: _crossMopedLabel,
      colorNameBuilder: _blackLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.crossMopedBlue,
      category: MapMarkerCategory.mopedCross,
      assetPath: 'assets/Moped/cross_blue_transparent.png',
      labelBuilder: _crossMopedLabel,
      colorNameBuilder: _blueLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.crossMopedGold,
      category: MapMarkerCategory.mopedCross,
      assetPath: 'assets/Moped/cross_gold_transparent.png',
      labelBuilder: _crossMopedLabel,
      colorNameBuilder: _goldLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.crossMopedRed,
      category: MapMarkerCategory.mopedCross,
      assetPath: 'assets/Moped/cross_red_transparent.png',
      labelBuilder: _crossMopedLabel,
      colorNameBuilder: _redLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.electricScooterGold,
      category: MapMarkerCategory.electricScooter,
      assetPath: 'assets/Elsparkcykel/scooter_gold.png',
      labelBuilder: _electricScooterLabel,
      colorNameBuilder: _goldLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.electricScooterRed,
      category: MapMarkerCategory.electricScooter,
      assetPath: 'assets/Elsparkcykel/scooter_red.png',
      labelBuilder: _electricScooterLabel,
      colorNameBuilder: _redLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.microcarBlue,
      category: MapMarkerCategory.ligier,
      assetPath: 'assets/mopedbilar/ligier/IMG_8769.png',
      labelBuilder: _ligierLabel,
      colorNameBuilder: _blueLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.microcarBlack,
      category: MapMarkerCategory.ligier,
      assetPath:
          'assets/mopedbilar/ligier/0B2354C4-4074-4FC9-B461-7E773F54DF63.png',
      labelBuilder: _ligierLabel,
      colorNameBuilder: _blackLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.microcarGold,
      category: MapMarkerCategory.ligier,
      assetPath:
          'assets/mopedbilar/ligier/DC861799-B006-4369-9BD9-F170EC9DCF9E.png',
      labelBuilder: _ligierLabel,
      colorNameBuilder: _goldLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.aixamWhite,
      category: MapMarkerCategory.aixam,
      assetPath:
          'assets/mopedbilar/aixam/769AAE71-DB8C-4215-AFE9-679B33C3007A.png',
      labelBuilder: _aixamLabel,
      colorNameBuilder: _whiteLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.aixamBlack,
      category: MapMarkerCategory.aixam,
      assetPath:
          'assets/mopedbilar/aixam/B4C91DA5-7FB2-4997-8890-C5B9C34F89F6.png',
      labelBuilder: _aixamLabel,
      colorNameBuilder: _blackLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.aixamYellow,
      category: MapMarkerCategory.aixam,
      assetPath:
          'assets/mopedbilar/aixam/B73ED154-474F-43D8-B326-FE67D0F85297.png',
      labelBuilder: _aixamLabel,
      colorNameBuilder: _yellowLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.mgoOrange,
      category: MapMarkerCategory.microcar,
      assetPath:
          'assets/mopedbilar/microcar/F21F459C-B9C8-424A-AD4D-E557B404BA0D.png',
      labelBuilder: _microcarLabel,
      colorNameBuilder: _orangeLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.mgoRed,
      category: MapMarkerCategory.microcar,
      assetPath:
          'assets/mopedbilar/microcar/543B1A38-5F70-4648-A692-4841CC390E91.png',
      labelBuilder: _microcarLabel,
      colorNameBuilder: _redLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.mgoBlack,
      category: MapMarkerCategory.microcar,
      assetPath:
          'assets/mopedbilar/microcar/AF6505FA-A1BE-4473-A4FE-FA7F3A96EA7B.png',
      labelBuilder: _microcarLabel,
      colorNameBuilder: _blackLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.mgoYellow,
      category: MapMarkerCategory.microcar,
      assetPath:
          'assets/mopedbilar/microcar/B3492F1A-99B3-494C-BE72-DA295A4898AF.png',
      labelBuilder: _microcarLabel,
      colorNameBuilder: _yellowLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.epaRed,
      category: MapMarkerCategory.pickup,
      assetPath: 'assets/A-Traktor/192ED5A9-0723-4BEB-ADA8-CBECE9EB065F.png',
      labelBuilder: _pickupLabel,
      colorNameBuilder: _redLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.epaBlue,
      category: MapMarkerCategory.pickup,
      assetPath: 'assets/A-Traktor/17F2CAAE-09B6-4F6B-975C-E7A2F3ADB1FB.png',
      labelBuilder: _pickupLabel,
      colorNameBuilder: _blueLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.epaBlack,
      category: MapMarkerCategory.pickup,
      assetPath: 'assets/A-Traktor/8EF4AEEB-9B42-4CB6-8E12-F314F536213A.png',
      labelBuilder: _pickupLabel,
      colorNameBuilder: _blackLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.epaWhite,
      category: MapMarkerCategory.pickup,
      assetPath:
          'assets/A-Traktor/Projektet Ta bort bakgrunden - 13 juni 2026 10.16.26.png',
      labelBuilder: _pickupLabel,
      colorNameBuilder: _blackLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.epaPink,
      category: MapMarkerCategory.pickup,
      assetPath: 'assets/A-Traktor/A69BDD57-5335-42D1-B4CF-B9F5E15D9931.PNG',
      labelBuilder: _pickupLabel,
      colorNameBuilder: _pinkLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.miniBlue,
      category: MapMarkerCategory.atraktor,
      assetPath: 'assets/A-Traktor/BAA3B7F2-D521-448A-945B-23C135CA577D.png',
      labelBuilder: _miniLabel,
      colorNameBuilder: _blueLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.miniWhite,
      category: MapMarkerCategory.atraktor,
      assetPath: 'assets/A-Traktor/A57BEDF4-AC7A-4AF9-846B-D6D52265B8C0.png',
      labelBuilder: _miniLabel,
      colorNameBuilder: _whiteLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.miniGreen,
      category: MapMarkerCategory.atraktor,
      assetPath: 'assets/A-Traktor/826EFA5F-802B-4BAF-8489-7DFDDB113F5E.png',
      labelBuilder: _miniLabel,
      colorNameBuilder: _greenLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.miniOrange,
      category: MapMarkerCategory.atraktor,
      assetPath: 'assets/A-Traktor/59BCA6D8-AB43-43CF-9B49-B44947A049F1.png',
      labelBuilder: _miniLabel,
      colorNameBuilder: _orangeLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.miniPink,
      category: MapMarkerCategory.atraktor,
      assetPath: 'assets/A-Traktor/CDB10DE2-6FEC-4C22-9CFA-4D9B8CC48BF3.PNG',
      labelBuilder: _miniLabel,
      colorNameBuilder: _pinkLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.bmwRed,
      category: MapMarkerCategory.atraktor,
      assetPath: 'assets/A-Traktor/00C1DD02-7ECB-4113-BEFF-25D50FB60232 2.png',
      labelBuilder: _bmwLabel,
      colorNameBuilder: _redLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.bmwOrange,
      category: MapMarkerCategory.atraktor,
      assetPath: 'assets/A-Traktor/F0E868B6-F2D9-4166-8C27-E47034926C18.png',
      labelBuilder: _bmwLabel,
      colorNameBuilder: _orangeLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.bmwSilver,
      category: MapMarkerCategory.atraktor,
      assetPath: 'assets/A-Traktor/19C25927-5A00-4010-8C52-56659BBA33C1.png',
      labelBuilder: _bmwLabel,
      colorNameBuilder: _silverLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.bmwPink,
      category: MapMarkerCategory.atraktor,
      assetPath: 'assets/A-Traktor/F0384A4D-9B3D-47F9-9914-735FB0F7BD10.PNG',
      labelBuilder: _bmwLabel,
      colorNameBuilder: _pinkLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.tractorWhite,
      category: MapMarkerCategory.tractor,
      assetPath: 'assets/traktor/IMG_8596.png',
      labelBuilder: _tractorLabel,
      colorNameBuilder: _whiteLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.tractorBlack,
      category: MapMarkerCategory.tractor,
      assetPath: 'assets/traktor/IMG_8598.png',
      labelBuilder: _tractorLabel,
      colorNameBuilder: _blackLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.tractorRed,
      category: MapMarkerCategory.tractor,
      assetPath: 'assets/traktor/IMG_8600.png',
      labelBuilder: _tractorLabel,
      colorNameBuilder: _redLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.tractorGold,
      category: MapMarkerCategory.tractor,
      assetPath: 'assets/traktor/IMG_8601.png',
      labelBuilder: _tractorLabel,
      colorNameBuilder: _goldLabel,
    ),
  ];

  static MapMarkerOption optionFor(MapMarkerStyle style) {
    final resolvedStyle = switch (style) {
      MapMarkerStyle.bmwBlack => MapMarkerStyle.bmwRed,
      MapMarkerStyle.epaGold => MapMarkerStyle.epaWhite,
      MapMarkerStyle.microcarRed => MapMarkerStyle.microcarBlack,
      MapMarkerStyle.microcarWhite => MapMarkerStyle.microcarBlue,
      MapMarkerStyle.aixamRed => MapMarkerStyle.aixamWhite,
      MapMarkerStyle.aixamGraphite => MapMarkerStyle.aixamBlack,
      _ => style,
    };
    return options.firstWhere(
      (option) => option.style == resolvedStyle,
      orElse: () => options.first,
    );
  }

  static List<MapMarkerOption> optionsForCategory(MapMarkerCategory category) {
    return options.where((option) => option.category == category).toList();
  }

  static String categoryLabel(
    MapMarkerCategory category,
    AppLocalizations l10n,
  ) {
    return switch (category) {
      MapMarkerCategory.classic => l10n.settingsMapMarkerCategoryClassic,
      MapMarkerCategory.ligier => l10n.settingsMapMarkerCategoryLigier,
      MapMarkerCategory.aixam => l10n.settingsMapMarkerCategoryAixam,
      MapMarkerCategory.microcar => l10n.settingsMapMarkerCategoryMicrocar,
      MapMarkerCategory.pickup => l10n.settingsMapMarkerCategoryPickup,
      MapMarkerCategory.atraktor => l10n.settingsMapMarkerCategoryAtractor,
      MapMarkerCategory.tractor => l10n.settingsMapMarkerCategoryTractor,
      MapMarkerCategory.mopedScooter => l10n.settingsMapMarkerScooter,
      MapMarkerCategory.mopedCross => l10n.settingsMapMarkerCrossMoped,
      MapMarkerCategory.electricScooter => l10n.settingsVehicleElectricScooter,
    };
  }

  static Widget stylePreview(
    MapMarkerStyle style, {
    double size = 50,
    bool selected = false,
  }) {
    final option = optionFor(style);
    return _MarkerPreview(option: option, size: size, selected: selected);
  }

  @override
  Widget build(BuildContext context) {
    final preferences = UserPreferencesService.instance;

    return ValueListenableBuilder<MapMarkerStyle>(
      valueListenable: preferences.mapMarkerStyle,
      builder: (context, markerStyle, _) {
        return ValueListenableBuilder<double>(
          valueListenable: headingNotifier,
          builder: (_, heading, _) {
            final option = optionFor(markerStyle);
            final rotatesWithHeading =
                !lockNorthUp && option.rotatesWithHeading;
            final tint = option.tint ?? backgroundColor;
            final previewSize = size;

            return Center(
              child: Transform.rotate(
                angle: rotatesWithHeading ? heading * math.pi / 180.0 : 0.0,
                child: _MarkerPreview(
                  option: option,
                  size: previewSize,
                  selected: true,
                  assetScale: option.assetPath != null ? 1.0 : 1.08,
                  forceTint: tint,
                  borderColor: borderColor,
                  borderWidth: borderWidth,
                  showOuterGlow: showOuterGlow,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MarkerPreview extends StatelessWidget {
  const _MarkerPreview({
    required this.option,
    required this.size,
    required this.selected,
    this.assetScale = 1.0,
    this.forceTint,
    this.borderColor,
    this.borderWidth,
    this.showOuterGlow,
  });

  final MapMarkerOption option;
  final double size;
  final bool selected;
  final double assetScale;
  final Color? forceTint;
  final Color? borderColor;
  final double? borderWidth;
  final bool? showOuterGlow;

  @override
  Widget build(BuildContext context) {
    if (option.assetPath != null) {
      final effectiveGlow = showOuterGlow ?? selected;
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (effectiveGlow)
              Container(
                width: size * 0.56,
                height: size * 0.56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(
                        alpha: selected ? 0.20 : 0.12,
                      ),
                      blurRadius: selected ? 18 : 12,
                      spreadRadius: selected ? 2 : 0.5,
                    ),
                  ],
                ),
              ),
            Transform.scale(
              scale: assetScale,
              child: Image.asset(
                option.assetPath!,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                width: size,
                height: size,
              ),
            ),
          ],
        ),
      );
    }

    if (option.style == MapMarkerStyle.dot) {
      return _FlatClassicMarker(
        size: size,
        tint: forceTint ?? option.tint ?? const Color(0xFF19A7FF),
        borderColor: borderColor ?? (selected ? Colors.white : Colors.white70),
        showOuterGlow: showOuterGlow ?? selected,
      );
    }

    final tint = forceTint ?? option.tint ?? const Color(0xFF1E90FF);
    final icon = switch (option.style) {
      MapMarkerStyle.navigation => Icons.navigation,
      MapMarkerStyle.compass => Icons.assistant_navigation,
      MapMarkerStyle.triangle => Icons.change_history,
      MapMarkerStyle.dot => Icons.trip_origin,
      _ => Icons.navigation,
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          if (showOuterGlow ?? selected)
            BoxShadow(
              color: tint.withValues(alpha: 0.36),
              blurRadius: 14,
              spreadRadius: 1.5,
            ),
        ],
      ),
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(tint, Colors.white, 0.42)!, tint],
            ),
            border: Border.all(
              color: borderColor ?? (selected ? Colors.white : Colors.white70),
              width: borderWidth ?? (selected ? 1.8 : 1.0),
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: size * 0.50,
            ),
          ),
        ),
      ),
    );
  }
}

class _FlatClassicMarker extends StatelessWidget {
  const _FlatClassicMarker({
    required this.size,
    required this.tint,
    required this.borderColor,
    required this.showOuterGlow,
  });

  final double size;
  final Color tint;
  final Color borderColor;
  final bool showOuterGlow;

  @override
  Widget build(BuildContext context) {
    const outlineOffsets = <Offset>[
      Offset(-1.2, 0),
      Offset(1.2, 0),
      Offset(0, -1.2),
      Offset(0, 1.2),
    ];

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showOuterGlow)
            Icon(
              Icons.navigation_rounded,
              color: tint.withValues(alpha: 0.28),
              size: size * 0.92,
              shadows: [
                Shadow(
                  color: tint.withValues(alpha: 0.42),
                  blurRadius: 16,
                ),
              ],
            ),
          for (final offset in outlineOffsets)
            Transform.translate(
              offset: offset,
              child: Icon(
                Icons.navigation_rounded,
                color: borderColor,
                size: size * 0.72,
              ),
            ),
          Icon(
            Icons.navigation_rounded,
            color: tint,
            size: size * 0.72,
          ),
        ],
      ),
    );
  }
}

String _arrowLabel(AppLocalizations l10n) => l10n.settingsMapMarkerArrow;
String _compassLabel(AppLocalizations l10n) => l10n.settingsMapMarkerCompass;
String _triangleLabel(AppLocalizations l10n) => l10n.settingsMapMarkerTriangle;
String _dotLabel(AppLocalizations l10n) => l10n.settingsMapMarkerDot;
String _ligierLabel(AppLocalizations l10n) => l10n.settingsMapMarkerLigier;
String _aixamLabel(AppLocalizations l10n) => l10n.settingsMapMarkerAixam;
String _microcarLabel(AppLocalizations l10n) => l10n.settingsMapMarkerMicrocar;
String _pickupLabel(AppLocalizations l10n) => l10n.settingsMapMarkerPickup;
String _miniLabel(AppLocalizations l10n) => l10n.settingsMapMarkerMini;
String _bmwLabel(AppLocalizations l10n) => l10n.settingsMapMarkerBmw;
String _tractorLabel(AppLocalizations l10n) => l10n.settingsMapMarkerTractor;
String _scooterLabel(AppLocalizations l10n) => l10n.settingsMapMarkerScooter;
String _crossMopedLabel(AppLocalizations l10n) =>
    l10n.settingsMapMarkerCrossMoped;
String _electricScooterLabel(AppLocalizations l10n) =>
    l10n.settingsVehicleElectricScooter;
String _redLabel(AppLocalizations l10n) => l10n.settingsColorRed;
String _blueLabel(AppLocalizations l10n) => l10n.settingsColorBlue;
String _greenLabel(AppLocalizations l10n) => l10n.settingsColorGreen;
String _blackLabel(AppLocalizations l10n) => l10n.settingsColorBlack;
String _whiteLabel(AppLocalizations l10n) => l10n.settingsColorWhite;
String _goldLabel(AppLocalizations l10n) => l10n.settingsColorGold;
String _silverLabel(AppLocalizations l10n) => l10n.settingsColorSilver;
String _yellowLabel(AppLocalizations l10n) => l10n.settingsColorYellow;
String _orangeLabel(AppLocalizations l10n) => l10n.settingsColorOrange;
String _pinkLabel(AppLocalizations l10n) => l10n.settingsColorPink;
