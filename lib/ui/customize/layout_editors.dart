import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/layout_prefs.dart';

/// A list of sections with a visibility switch and up/down controls.
class SectionOrderEditor extends StatelessWidget {
  const SectionOrderEditor({super.key, required this.order, required this.hidden, required this.labelOf, required this.onMove, required this.onToggle});

  final List<HomeSection> order;
  final Set<HomeSection> hidden;
  final String Function(HomeSection section) labelOf;
  final void Function(HomeSection section, int delta) onMove;
  final void Function(HomeSection section, bool visible) onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return FTileGroup(
      divider: FItemDivider.full,
      children: [
        for (final (i, section) in order.indexed)
          FTile(
            prefix: FSwitch(value: !hidden.contains(section), onChange: (v) => onToggle(section, v)),
            title: Text(labelOf(section), style: hidden.contains(section) ? TextStyle(color: colors.mutedForeground) : null),
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FButton.icon(style: FButtonStyle.ghost(), onPress: i == 0 ? null : () => onMove(section, -1), child: const Icon(FIcons.chevronUp)),
                FButton.icon(style: FButtonStyle.ghost(), onPress: i == order.length - 1 ? null : () => onMove(section, 1), child: const Icon(FIcons.chevronDown)),
              ],
            ),
          ),
      ],
    );
  }
}

/// A labelled dropdown row for a single option.
class OptionRow<T> extends StatelessWidget {
  const OptionRow({super.key, required this.label, required this.value, required this.items, required this.onChange});

  final String label;
  final T value;
  final Map<String, T> items;
  final ValueChanged<T> onChange;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(child: Text(label, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w600))),
            SizedBox(
              width: 190,
              child: FSelect<T>(
                control: FSelectControl<T>.lifted(value: value, onChange: (v) => v == null ? null : onChange(v)),
                items: items,
              ),
            ),
          ],
        ),
      );
}

class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.label, required this.value, required this.onChange});

  final String label;
  final bool value;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) => FTileGroup(
        divider: FItemDivider.full,
        children: [FTile(title: Text(label), suffix: FSwitch(value: value, onChange: onChange))],
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
        child: Text(text, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w700)),
      );
}
