import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// A horizontally scrolling row of pill toggles with a single selection.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({super.key, required this.items, required this.selected, required this.onSelect, this.padding = const EdgeInsets.symmetric(horizontal: 16)});

  final Map<T, String> items;
  final T selected;
  final ValueChanged<T> onSelect;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final (i, entry) in items.entries.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            FTappable(
              onPress: () => onSelect(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: entry.key == selected ? colors.primary : colors.background,
                  border: Border.all(color: entry.key == selected ? colors.primary : colors.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.value,
                  style: typography.sm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: entry.key == selected ? colors.primaryForeground : colors.foreground,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
