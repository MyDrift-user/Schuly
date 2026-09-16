import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/grade_settings.dart';
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
      listenable: Listenable.merge([LayoutPrefs.instance, GradeSettings.instance]),
      builder: (context, _) {
        final prefs = LayoutPrefs.instance;
        return FScaffold(
          header: FHeader.nested(
            title: const Text('Layout'),
            prefixes: [FHeaderAction.back(onPress: () => Navigator.of(context).pop())],
            suffixes: [
              FHeaderAction(
                icon: const Icon(FIcons.rotateCcw),
                onPress: prefs.isDefault && GradeSettings.instance.isDefault
                    ? null
                    : () {
                        prefs.reset();
                        GradeSettings.instance.reset();
                      },
              ),
            ],
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
              ...homeLayoutOptions(prefs),
              const SizedBox(height: 16),
              const SectionHeader(icon: FIcons.calendarDays, title: 'Timetable'),
              ...timetableLayoutOptions(prefs),
              const SizedBox(height: 16),
              const SectionHeader(icon: FIcons.chartColumn, title: 'Grades'),
              ...gradesLayoutOptions(context),
              const SizedBox(height: 24),
              const SectionHeader(icon: FIcons.calendarOff, title: 'Absences'),
              ...absencesLayoutOptions(prefs),
            ],
          ),
        );
      },
    );
  }
}
