import 'package:flutter/material.dart';

/// Gives custom tap targets the same spoken name and actions as a standard
/// Flutter button. This makes them discoverable by VoiceOver and addressable
/// by Voice Control without exposing decorative child widgets twice.
class AccessibleTapTarget extends StatelessWidget {
  const AccessibleTapTarget({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.hint,
    this.selected,
    this.tooltip = true,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? hint;
  final bool? selected;
  final bool tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget target = GestureDetector(
      excludeFromSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: child,
    );

    if (tooltip) {
      target = Tooltip(message: label, child: target);
    }

    return Semantics(
      button: true,
      label: label,
      hint: hint,
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: target,
    );
  }
}
