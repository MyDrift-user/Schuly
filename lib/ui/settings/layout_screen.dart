import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/layout_prefs.dart';
import '../core/ui/section_header.dart';
import '../customize/layout_editors.dart';

class LayoutScreen extends StatelessWidget {
  const LayoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    return ListenableBuilder(
      listenable: LayoutPrefs.instance,
      builder: (context, _) {
        final prefs = LayoutPrefs.instance;
        return FScaffold(
          header: FHeader.nested(
            title: const Text('Layout'),
            prefixes: [FHeaderAction.back(onPress: () => Navigator.of(context).pop())],
            suffixes: [FHeaderAction(icon: const Icon(FIcons.rotateCcw), onPress: prefs.isDefault ? null : prefs.reset)],
          ),
          childPad: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.viewPaddingOf(context).bottom),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: Text('Choose what each tab shows and in which order. Changes apply immediately.', style: typography.sm.copyWith(color: colors.mutedForeground)),
              ),
              const SectionHeader(icon: FIcons.house, title: 'Home'),
              SectionOrderEditor(
                order: prefs.homeOrder,
                hidden: prefs.homeHidden,
                labelOf: (s) => s.label,
                onMove: prefs.moveHomeSection,
                onToggle: prefs.setHomeSectionVisible,
              ),
              const SectionLabel('Summary tiles'),
              for (var i = 0; i < 3; i++)
                OptionRow<String>(
                  label: 'Tile ${i + 1}',
                  value: i < prefs.homeTiles.length ? prefs.homeTiles[i].name : 'none',
                  items: {'None': 'none', for (final t in HomeTile.values) t.label: t.name},
                  onChange: (name) {
                    final tiles = List.of(prefs.homeTiles);
                    final chosen = HomeTile.values.where((t) => t.name == name).firstOrNull;
                    if (chosen == null) {
                      if (i < tiles.length) tiles.removeAt(i);
                    } else if (i < tiles.length) {
                      tiles[i] = chosen;
                    } else {
                      tiles.add(chosen);
                    }
                    prefs.setHomeTiles(tiles);
                  },
                ),
              const SizedBox(height: 16),
              const SectionHeader(icon: FIcons.calendarDays, title: 'Timetable'),
              OptionRow<TimeColumnSide>(
                label: 'Time column',
                value: prefs.timeColumn,
                items: {for (final v in TimeColumnSide.values) v.label: v},
                onChange: prefs.setTimeColumn,
              ),
              OptionRow<DayStripPosition>(
                label: 'Day picker',
                value: prefs.dayStrip,
                items: {for (final v in DayStripPosition.values) v.label: v},
                onChange: prefs.setDayStrip,
              ),
              const SizedBox(height: 16),
              const SectionHeader(icon: FIcons.chartColumn, title: 'Grades'),
              SwitchRow(label: 'Summary tiles', value: prefs.gradesTiles, onChange: prefs.setGradesTiles),
              const SizedBox(height: 24),
              const SectionHeader(icon: FIcons.calendarOff, title: 'Absences'),
              SwitchRow(label: 'Summary tiles', value: prefs.absencesTiles, onChange: prefs.setAbsencesTiles),
            ],
          ),
        );
      },
    );
  }
}
