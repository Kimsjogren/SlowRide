import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:slowride/services/user_preferences_service.dart';

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

  static Widget stylePreview(
    MapMarkerStyle style, {
    double size = 42,
    bool selected = false,
  }) {
    final palette = _paletteFor(style);
    return _MarkerBadge(
      style: style,
      size: size,
      borderColor: selected ? Colors.white : Colors.white70,
      borderWidth: selected ? 2.6 : 2.0,
      showOuterGlow: selected,
      palette: palette,
      showChrome: true,
    );
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
            final rotatesWithHeading =
                !lockNorthUp && _rotatesWithHeading(markerStyle);
            final palette = _paletteFor(markerStyle);

            return Center(
              child: Transform.rotate(
                angle: rotatesWithHeading ? heading * math.pi / 180.0 : 0.0,
                child: _MarkerBadge(
                  style: markerStyle,
                  size: size,
                  borderColor: borderColor,
                  borderWidth: borderWidth,
                  showOuterGlow: showOuterGlow,
                  palette: palette,
                  showChrome:
                      backgroundColor.a > 0 ||
                      borderColor.a > 0 ||
                      showOuterGlow,
                ),
              ),
            );
          },
        );
      },
    );
  }

  static bool _rotatesWithHeading(MapMarkerStyle style) {
    return switch (style) {
      MapMarkerStyle.navigation ||
      MapMarkerStyle.compass ||
      MapMarkerStyle.triangle => true,
      _ => false,
    };
  }

  static _MarkerPalette _paletteFor(MapMarkerStyle style) {
    return switch (style) {
      MapMarkerStyle.navigation => const _MarkerPalette(
        base: Color(0xFF1E90FF),
        accent: Color(0xFF7BD6FF),
        glow: Color(0xFF1E90FF),
      ),
      MapMarkerStyle.compass => const _MarkerPalette(
        base: Color(0xFF00BFA5),
        accent: Color(0xFF82FFF1),
        glow: Color(0xFF00BFA5),
      ),
      MapMarkerStyle.triangle => const _MarkerPalette(
        base: Color(0xFF6C63FF),
        accent: Color(0xFFB9B3FF),
        glow: Color(0xFF6C63FF),
      ),
      MapMarkerStyle.dot => const _MarkerPalette(
        base: Color(0xFF25C281),
        accent: Color(0xFFA8FFD9),
        glow: Color(0xFF25C281),
      ),
      MapMarkerStyle.smile => const _MarkerPalette(
        base: Color(0xFFFFC83D),
        accent: Color(0xFFFFF0A8),
        glow: Color(0xFFFFC83D),
      ),
      MapMarkerStyle.cool => const _MarkerPalette(
        base: Color(0xFF47C7FF),
        accent: Color(0xFFC4F3FF),
        glow: Color(0xFF47C7FF),
      ),
      MapMarkerStyle.turbo => const _MarkerPalette(
        base: Color(0xFF9B51E0),
        accent: Color(0xFFE4C7FF),
        glow: Color(0xFF9B51E0),
      ),
      MapMarkerStyle.crown => const _MarkerPalette(
        base: Color(0xFFFF7A45),
        accent: Color(0xFFFFD0A8),
        glow: Color(0xFFFF7A45),
      ),
      MapMarkerStyle.ghost => const _MarkerPalette(
        base: Color(0xFF7F8CFF),
        accent: Color(0xFFE1E5FF),
        glow: Color(0xFF7F8CFF),
      ),
    };
  }
}

class _MarkerBadge extends StatelessWidget {
  const _MarkerBadge({
    required this.style,
    required this.size,
    required this.borderColor,
    required this.borderWidth,
    required this.showOuterGlow,
    required this.palette,
    required this.showChrome,
  });

  final MapMarkerStyle style;
  final double size;
  final Color borderColor;
  final double borderWidth;
  final bool showOuterGlow;
  final _MarkerPalette palette;
  final bool showChrome;

  @override
  Widget build(BuildContext context) {
    final child = Stack(
      alignment: Alignment.center,
      children: [
        if (showChrome)
          Positioned(
            top: size * 0.16,
            child: Container(
              width: size * 0.58,
              height: size * 0.18,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
        _styleChild(style, size),
      ],
    );

    if (!showChrome) {
      return SizedBox(width: size, height: size, child: child);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.accent, palette.base],
        ),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: palette.glow.withValues(alpha: 0.65),
            blurRadius: 10,
            spreadRadius: 2,
          ),
          if (showOuterGlow)
            BoxShadow(
              color: palette.glow.withValues(alpha: 0.28),
              blurRadius: 22,
              spreadRadius: 8,
            ),
        ],
      ),
      child: ClipOval(child: child),
    );
  }

  Widget _styleChild(MapMarkerStyle style, double size) {
    return switch (style) {
      MapMarkerStyle.navigation => Icon(
        Icons.navigation,
        color: Colors.white,
        size: size * 0.54,
      ),
      MapMarkerStyle.compass => Icon(
        Icons.assistant_navigation,
        color: Colors.white,
        size: size * 0.56,
      ),
      MapMarkerStyle.triangle => Icon(
        Icons.change_history,
        color: Colors.white,
        size: size * 0.56,
      ),
      MapMarkerStyle.dot => Icon(
        Icons.trip_origin,
        color: Colors.white,
        size: size * 0.42,
      ),
      MapMarkerStyle.smile => _AvatarFace(
        size: size,
        eyeColor: const Color(0xFF20243A),
        smileColor: const Color(0xFF20243A),
      ),
      MapMarkerStyle.cool => _AvatarFace(
        size: size,
        eyeColor: const Color(0xFF111827),
        smileColor: const Color(0xFF111827),
        accessory: Icon(
          Icons.horizontal_rule_rounded,
          color: const Color(0xFF111827),
          size: size * 0.52,
        ),
        accessoryOffset: Offset(0, -size * 0.04),
      ),
      MapMarkerStyle.turbo => _AvatarFace(
        size: size,
        eyeColor: Colors.white,
        smileColor: Colors.white,
        accessory: Icon(
          Icons.bolt_rounded,
          color: const Color(0xFFFFD54F),
          size: size * 0.34,
        ),
        accessoryOffset: Offset(size * 0.18, -size * 0.20),
      ),
      MapMarkerStyle.crown => _AvatarFace(
        size: size,
        eyeColor: const Color(0xFF3A1F14),
        smileColor: const Color(0xFF3A1F14),
        accessory: Icon(
          Icons.workspace_premium,
          color: const Color(0xFFFFE082),
          size: size * 0.34,
        ),
        accessoryOffset: Offset(0, -size * 0.22),
      ),
      MapMarkerStyle.ghost => _AvatarFace(
        size: size,
        eyeColor: const Color(0xFF272B63),
        smileColor: const Color(0xFF272B63),
        surprised: true,
      ),
    };
  }
}

class _AvatarFace extends StatelessWidget {
  const _AvatarFace({
    required this.size,
    required this.eyeColor,
    required this.smileColor,
    this.accessory,
    this.accessoryOffset = Offset.zero,
    this.surprised = false,
  });

  final double size;
  final Color eyeColor;
  final Color smileColor;
  final Widget? accessory;
  final Offset accessoryOffset;
  final bool surprised;

  @override
  Widget build(BuildContext context) {
    final eyeSize = size * 0.10;
    final mouthWidth = size * (surprised ? 0.12 : 0.30);
    final mouthHeight = size * (surprised ? 0.12 : 0.08);

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: size * 0.34,
          left: size * 0.26,
          child: _Eye(size: eyeSize, color: eyeColor),
        ),
        Positioned(
          top: size * 0.34,
          right: size * 0.26,
          child: _Eye(size: eyeSize, color: eyeColor),
        ),
        Positioned(
          bottom: surprised ? size * 0.26 : size * 0.22,
          child: Container(
            width: mouthWidth,
            height: mouthHeight,
            decoration: BoxDecoration(
              color: smileColor,
              borderRadius: BorderRadius.circular(size),
            ),
          ),
        ),
        if (!surprised)
          Positioned(
            bottom: size * 0.20,
            child: Container(
              width: size * 0.18,
              height: size * 0.04,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
        if (accessory != null)
          Transform.translate(offset: accessoryOffset, child: accessory!),
      ],
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MarkerPalette {
  const _MarkerPalette({
    required this.base,
    required this.accent,
    required this.glow,
  });

  final Color base;
  final Color accent;
  final Color glow;

  _MarkerPalette copyWith({Color? base, Color? accent, Color? glow}) {
    return _MarkerPalette(
      base: base ?? this.base,
      accent: accent ?? this.accent,
      glow: glow ?? this.glow,
    );
  }
}
