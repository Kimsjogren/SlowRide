import 'package:flutter/material.dart';

class NavigationEtaBadge extends StatelessWidget {
  const NavigationEtaBadge({required this.eta, super.key});

  final String eta;

  @override
  Widget build(BuildContext context) {
    final value = eta.trim();
    if (value.isEmpty) return const SizedBox.shrink();

    final parts = value.split('·').map((part) => part.trim()).toList();
    final remaining = parts.first;
    final arrival = parts.length > 1 ? parts.last : '';

    return Semantics(
      label: value,
      child: Container(
        constraints: const BoxConstraints(minWidth: 70, maxWidth: 86),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF102B60),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x553AA8FF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              remaining,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            if (arrival.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, size: 11, color: Colors.white60),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      arrival,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
