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

  @override
  Widget build(BuildContext context) {
    final preferences = UserPreferencesService.instance;

    return ValueListenableBuilder<MapMarkerStyle>(
      valueListenable: preferences.mapMarkerStyle,
      builder: (context, markerStyle, _) {
        return ValueListenableBuilder<double>(
          valueListenable: headingNotifier,
          builder: (_, heading, __) {
            final rotate = !lockNorthUp && markerStyle != MapMarkerStyle.dot;
            return Center(
              child: Transform.rotate(
                angle: rotate ? heading * math.pi / 180.0 : 0.0,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: backgroundColor,
                    border: Border.all(color: borderColor, width: borderWidth),
                    boxShadow: [
                      BoxShadow(
                        color: backgroundColor.withValues(alpha: 0.75),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                      if (showOuterGlow)
                        BoxShadow(
                          color: backgroundColor.withValues(alpha: 0.30),
                          blurRadius: 22,
                          spreadRadius: 8,
                        ),
                    ],
                  ),
                  child: Icon(
                    _iconFor(markerStyle),
                    color: Colors.white,
                    size: markerStyle == MapMarkerStyle.dot
                        ? size * 0.42
                        : size * 0.54,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static IconData _iconFor(MapMarkerStyle style) {
    return switch (style) {
      MapMarkerStyle.navigation => Icons.navigation,
      MapMarkerStyle.compass => Icons.assistant_navigation,
      MapMarkerStyle.triangle => Icons.change_history,
      MapMarkerStyle.dot => Icons.trip_origin,
    };
  }
}
