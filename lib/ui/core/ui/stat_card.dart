import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'accents.dart';

/// A compact number-with-label card, meant to sit in a [StatRow].
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.icon, required this.value, required this.label, this.accent = Accent.neutral, this.onPress});

  final IconData icon;
  final String value;
  final String label;
  final Accent accent;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: context.theme.style.borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent == Accent.neutral ? colors.mutedForeground : accent.color),
          const SizedBox(height: 10),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.xl.copyWith(fontWeight: FontWeight.w700, height: 1.1)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.xs.copyWith(color: colors.mutedForeground)),
        ],
      ),
    );
    return onPress == null ? card : FTappable(onPress: onPress, child: card);
  }
}

class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, c) in children.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: c),
            ],
          ],
        ),
      );
}
