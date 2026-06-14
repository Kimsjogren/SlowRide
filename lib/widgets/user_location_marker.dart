import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/services/user_preferences_service.dart';

enum MapMarkerCategory { classic, ligier, aixam, pickup, tractor }

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
    this.size = 42,
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
      tint: Color(0xFF25C281),
    ),
    MapMarkerOption(
      style: MapMarkerStyle.microcarRed,
      category: MapMarkerCategory.ligier,
      assetPath: 'assets/105F87AA-6074-4B4A-A7CD-E127515E5CC4.png',
      labelBuilder: _ligierLabel,
      colorNameBuilder: _redLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.microcarBlue,
      category: MapMarkerCategory.ligier,
      assetPath: 'assets/AD4E2031-7011-471E-9E58-035D77DD0B48.png',
      labelBuilder: _ligierLabel,
      colorNameBuilder: _blueLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.microcarBlack,
      category: MapMarkerCategory.ligier,
      assetPath: 'assets/A5749156-12A5-4CE5-B25B-912ECD3965CD.png',
      labelBuilder: _ligierLabel,
      colorNameBuilder: _blackLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.microcarWhite,
      category: MapMarkerCategory.ligier,
      assetPath: 'assets/73F70485-0439-4968-9256-97E569628BBC.png',
      labelBuilder: _ligierLabel,
      colorNameBuilder: _whiteLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.microcarGold,
      category: MapMarkerCategory.ligier,
      assetPath: 'assets/8EE771CD-8380-40F9-8773-8FDFB0A6F372.png',
      labelBuilder: _ligierLabel,
      colorNameBuilder: _goldLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.aixamWhite,
      category: MapMarkerCategory.aixam,
      assetPath: 'assets/IMG_8603.png',
      labelBuilder: _aixamLabel,
      colorNameBuilder: _whiteLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.aixamRed,
      category: MapMarkerCategory.aixam,
      assetPath: 'assets/IMG_8604.png',
      labelBuilder: _aixamLabel,
      colorNameBuilder: _redLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.aixamBlack,
      category: MapMarkerCategory.aixam,
      assetPath: 'assets/IMG_8605.png',
      labelBuilder: _aixamLabel,
      colorNameBuilder: _blackLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.aixamGraphite,
      category: MapMarkerCategory.aixam,
      assetPath: 'assets/IMG_8606.png',
      labelBuilder: _aixamLabel,
      colorNameBuilder: _graphiteLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.aixamYellow,
      category: MapMarkerCategory.aixam,
      assetPath: 'assets/IMG_8607.png',
      labelBuilder: _aixamLabel,
      colorNameBuilder: _yellowLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.epaRed,
      category: MapMarkerCategory.pickup,
      assetPath: 'assets/192ED5A9-0723-4BEB-ADA8-CBECE9EB065F.png',
      labelBuilder: _pickupLabel,
      colorNameBuilder: _redLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.epaBlue,
      category: MapMarkerCategory.pickup,
      assetPath: 'assets/17F2CAAE-09B6-4F6B-975C-E7A2F3ADB1FB.png',
      labelBuilder: _pickupLabel,
      colorNameBuilder: _blueLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.epaBlack,
      category: MapMarkerCategory.pickup,
      assetPath: 'assets/8EF4AEEB-9B42-4CB6-8E12-F314F536213A.png',
      labelBuilder: _pickupLabel,
      colorNameBuilder: _blackLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.epaWhite,
      category: MapMarkerCategory.pickup,
      assetPath: 'assets/827E38C0-7FB9-46E9-946D-8822822A7DFA.png',
      labelBuilder: _pickupLabel,
      colorNameBuilder: _whiteLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.epaGold,
      category: MapMarkerCategory.pickup,
      assetPath: 'assets/A76FE270-F0FE-4E1C-98CE-68ED44E86C44.png',
      labelBuilder: _pickupLabel,
      colorNameBuilder: _goldLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.tractorWhite,
      category: MapMarkerCategory.tractor,
      assetPath: 'assets/IMG_8596.png',
      labelBuilder: _tractorLabel,
      colorNameBuilder: _whiteLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.tractorBlack,
      category: MapMarkerCategory.tractor,
      assetPath: 'assets/IMG_8598.png',
      labelBuilder: _tractorLabel,
      colorNameBuilder: _blackLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.tractorRed,
      category: MapMarkerCategory.tractor,
      assetPath: 'assets/IMG_8600_cutout.png',
      labelBuilder: _tractorLabel,
      colorNameBuilder: _redLabel,
    ),
    MapMarkerOption(
      style: MapMarkerStyle.tractorGold,
      category: MapMarkerCategory.tractor,
      assetPath: 'assets/IMG_8601_cutout.png',
      labelBuilder: _tractorLabel,
      colorNameBuilder: _goldLabel,
    ),
  ];

  static MapMarkerOption optionFor(MapMarkerStyle style) {
    return options.firstWhere(
      (option) => option.style == style,
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
      MapMarkerCategory.pickup => l10n.settingsMapMarkerCategoryPickup,
      MapMarkerCategory.tractor => l10n.settingsMapMarkerCategoryTractor,
    };
  }

  static Widget stylePreview(
    MapMarkerStyle style, {
    double size = 56,
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
            final previewSize = option.assetPath != null ? size * 1.12 : size;

            return Center(
              child: Transform.rotate(
                angle: rotatesWithHeading ? heading * math.pi / 180.0 : 0.0,
                child: _MarkerPreview(
                  option: option,
                  size: previewSize,
                  selected: true,
                  assetScale: option.assetPath != null ? 1.48 : 1.16,
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
    this.assetScale = 1.16,
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
                width: size * 0.70,
                height: size * 0.70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(
                        alpha: selected ? 0.20 : 0.12,
                      ),
                      blurRadius: selected ? 22 : 14,
                      spreadRadius: selected ? 3 : 1,
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(tint, Colors.white, 0.42)!, tint],
        ),
        border: Border.all(
          color: borderColor ?? (selected ? Colors.white : Colors.white70),
          width: borderWidth ?? (selected ? 2.0 : 1.2),
        ),
        boxShadow: [
          if (showOuterGlow ?? selected)
            BoxShadow(
              color: tint.withValues(alpha: 0.36),
              blurRadius: 18,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: option.style == MapMarkerStyle.dot ? size * 0.42 : size * 0.56,
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
String _pickupLabel(AppLocalizations l10n) => l10n.settingsMapMarkerPickup;
String _tractorLabel(AppLocalizations l10n) => l10n.settingsMapMarkerTractor;
String _redLabel(AppLocalizations l10n) => l10n.settingsColorRed;
String _blueLabel(AppLocalizations l10n) => l10n.settingsColorBlue;
String _blackLabel(AppLocalizations l10n) => l10n.settingsColorBlack;
String _whiteLabel(AppLocalizations l10n) => l10n.settingsColorWhite;
String _goldLabel(AppLocalizations l10n) => l10n.settingsColorGold;
String _graphiteLabel(AppLocalizations l10n) => l10n.settingsColorGraphite;
String _yellowLabel(AppLocalizations l10n) => l10n.settingsColorYellow;
