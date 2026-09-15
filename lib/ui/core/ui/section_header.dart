import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Section title with a leading icon and an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: colors.mutedForeground),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: typography.base.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
          if (actionLabel != null)
            FTappable(
              onPress: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(actionLabel!, style: typography.sm.copyWith(color: colors.mutedForeground, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 2),
                    Icon(FIcons.chevronRight, size: 16, color: colors.mutedForeground),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
