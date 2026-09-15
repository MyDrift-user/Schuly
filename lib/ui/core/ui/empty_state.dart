import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'accents.dart';

/// Friendly placeholder for a list with nothing in it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.accent = Accent.neutral,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Accent accent;
  final Widget? action;

  /// Inline inside a section rather than filling a page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 28 : 40, color: accent == Accent.neutral ? colors.mutedForeground : accent.color),
        SizedBox(height: compact ? 10 : 16),
        Text(title,
            textAlign: TextAlign.center,
            style: (compact ? typography.sm : typography.lg).copyWith(fontWeight: FontWeight.w600)),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(message!,
              textAlign: TextAlign.center,
              style: (compact ? typography.xs : typography.sm).copyWith(color: colors.mutedForeground)),
        ],
        if (action != null) ...[
          const SizedBox(height: 16),
          action!,
        ],
      ],
    );

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border),
          borderRadius: context.theme.style.borderRadius,
        ),
        child: body,
      );
    }
    return Center(
      child: Padding(padding: const EdgeInsets.fromLTRB(32, 24, 32, 48), child: body),
    );
  }
}
