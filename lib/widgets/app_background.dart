import 'package:flutter/material.dart';

/// Shared full-screen background with the CruizX logo in the top-left corner.
/// Use this to wrap the body of every screen (except the map).
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.showLogo = true,
    this.logoAsset = 'assets/logga_nobg.png',
    this.logoHeight = 96,
    this.centerLogo = false,
  });

  final Widget child;

  /// Set to false to hide the top-left logo (e.g. when the screen has its own).
  final bool showLogo;

  /// Optional screen-specific logo while retaining the shared background.
  final String logoAsset;
  final double logoHeight;
  final bool centerLogo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLogo)
              Align(
                alignment: centerLogo ? Alignment.topCenter : Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: centerLogo ? 0 : 16,
                    top: 12,
                    bottom: 4,
                  ),
                  child: Image.asset(
                    logoAsset,
                    height: logoHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
