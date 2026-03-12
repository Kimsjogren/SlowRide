import 'package:flutter/material.dart';

/// Shared full-screen background with the CruizX logo in the top-left corner.
/// Use this to wrap the body of every screen (except the map).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

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
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
              child: Image.asset('assets/logga_nobg.png', height: 76),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
