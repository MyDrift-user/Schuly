import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:schuly_api/schuly_api.dart';

import '../../services/grade_settings.dart';
import '../../services/layout_prefs.dart';
import '../../services/school_data_service.dart';
import '../core/dates.dart';
import '../core/grade_color.dart';
import '../core/ui/accents.dart';
import '../core/ui/empty_state.dart';
import '../core/ui/chips.dart';
import '../core/ui/section_header.dart';
import '../core/ui/stat_card.dart';
import 'grade_math.dart';

class GradesPage extends StatefulWidget {
  const GradesPage({super.key});

  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  int? _selectedKey;

  static int _semesterKey(Date? d) {
    if (d == null) return 0;
    if (d.month >= 8) return d.year * 10 + 1;
    if (d.month <= 1) return (d.year - 1) * 10 + 1;
    return (d.year - 1) * 10 + 2;
  }

  static bool _isYear(int key) => key != 0 && key % 10 == 0;

  static String _periodLabel(int key) {
    if (key == 0) return 'Undated';
    final year = key ~/ 10, half = key % 10;
    final a = (year % 100).toString().padLeft(2, '0');
    final b = ((year + 1) % 100).toString().padLeft(2, '0');
    return half == 0 ? '$a/$b' : '$half. $a/$b'; // "25/26" vs "2. 25/26"
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Listenable.merge([LayoutPrefs.instance, GradeSettings.instance]), builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final typography = context.theme.typography;
    final svc = SchoolDataService.instance;
    final myGrades = svc.myGradesByExam;

    final graded = [
      for (final e in svc.exams)
        if (e.id != null && myGrades.containsKey(e.id)) e,
    ];
    if (graded.isEmpty) {
      return RefreshIndicator(
        onRefresh: svc.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 80),
          children: const [
            EmptyState(
              icon: FIcons.sparkles,
              title: 'No grades yet',
              message: 'Your grades appear here as soon as a teacher enters them. Pull down to refresh.',
            ),
          ],
        ),
      );
    }

    final semKeys = {for (final e in graded) _semesterKey(e.date)};
    final yearsDesc = {for (final k in semKeys) k ~/ 10}.toList()..sort((a, b) => b.compareTo(a));
    final periods = <int>[];
    for (final y in yearsDesc) {
      if (y == 0) {
        periods.add(0); // undated
        continue;
      }
      final halves = [for (final h in [2, 1]) if (semKeys.contains(y * 10 + h)) y * 10 + h];
      if (halves.length > 1) periods.add(y * 10); // whole-year option
      periods.addAll(halves);
    }
    final newestSemester = semKeys.where((k) => !_isYear(k)).fold(0, (m, k) => k > m ? k : m);
    final selected = (_selectedKey != null && periods.contains(_selectedKey))
        ? _selectedKey!
        : (periods.contains(newestSemester) ? newestSemester : periods.first);

    bool inSelection(int examKey) =>
        _isYear(selected) ? examKey ~/ 10 == selected ~/ 10 : examKey == selected;

    final classNames = <String?, String?>{
      for (final c in (svc.me?.classes ?? const <UserClassDto>[])) c.classId: c.className,
      ...svc.classNameById,
    };
    final byClass = <String, List<ExamDto>>{};
    final inPeriod = <ExamDto>[];
    for (final e in graded) {
      if (!inSelection(_semesterKey(e.date))) continue;
      inPeriod.add(e);
      byClass.putIfAbsent(e.classId ?? '-', () => []).add(e);
    }
    for (final list in byClass.values) {
      list.sort((a, b) => (b.date?.compareTo(a.date ?? b.date!) ?? 0));
    }

    final settings = GradeSettings.instance;
    final classAverages = <String, double>{
      for (final entry in byClass.entries) entry.key: ?subjectAverage(entry.value, myGrades),
    };
    final below = classAverages.values.where((a) => settings.subjectRounding.apply(a) < 4).length;
    final average = overallAverage(byClass, myGrades, settings);
    final best = classAverages.entries.fold<MapEntry<String, double>?>(null, (m, e) => m == null || e.value > m.value ? e : m);

    StatCard? tile(String key) {
      if (key.startsWith('group:')) {
        final group = settings.groups.where((g) => g.id == key.substring(6)).firstOrNull;
        if (group == null) return null;
        final avg = overallAverage(byClass, myGrades, settings, classIds: group.classIds);
        return StatCard(
          icon: FIcons.layers,
          accent: avg == null ? Accent.neutral : gradeAccent(avg),
          value: avg == null ? '-' : formatGrade(avg),
          label: group.name,
        );
      }
      return switch (key) {
        'average' => StatCard(
            icon: FIcons.sigma,
            accent: average == null ? Accent.neutral : gradeAccent(average),
            value: average == null ? '-' : formatGrade(average),
            label: 'Average',
          ),
        'exams' => StatCard(icon: FIcons.listChecks, value: '${inPeriod.length}', label: inPeriod.length == 1 ? 'Exam' : 'Exams'),
        'best' => StatCard(
            icon: FIcons.trophy,
            accent: best == null ? Accent.neutral : gradeAccent(best.value),
            value: best == null ? '-' : formatGrade(best.value),
            label: best == null ? 'Best subject' : (classNames[best.key] ?? 'Best subject'),
          ),
        'below' => StatCard(
            icon: below > 0 ? FIcons.triangleAlert : FIcons.badgeCheck,
            accent: below > 0 ? Accent.amber : Accent.green,
            value: '$below',
            label: 'Below 4',
          ),
        _ => null,
      };
    }

    final tiles = [for (final key in settings.tiles) ?tile(key)];

    final sections = byClass.entries.toList()
      ..sort((a, b) => (classNames[a.key] ?? '').compareTo(classNames[b.key] ?? ''));

    return RefreshIndicator(
      onRefresh: svc.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: Text('Grades', style: typography.xl2.copyWith(fontWeight: FontWeight.w800, height: 1))),
                if (periods.length > 1)
                  SizedBox(
                    width: 140,
                    child: FSelect<int>(
                      control: FSelectControl<int>.lifted(value: selected, onChange: (k) => setState(() => _selectedKey = k ?? selected)),
                      items: {for (final k in periods) _periodLabel(k): k},
                    ),
                  ),
              ],
            ),
          ),
          if (tiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  for (var i = 0; i < tiles.length; i += 3) ...[
                    if (i > 0) const SizedBox(height: 10),
                    StatRow(children: tiles.sublist(i, i + 3 > tiles.length ? tiles.length : i + 3)),
                  ],
                ],
              ),
            ),
          for (final entry in sections)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: _ClassSection(
                title: classNames[entry.key] ?? 'Class',
                average: classAverages[entry.key] == null ? null : settings.subjectRounding.apply(classAverages[entry.key]!),
                exams: entry.value,
                myGrades: myGrades,
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassSection extends StatelessWidget {
  final String title;
  final double? average;
  final List<ExamDto> exams;
  final Map<String, GradeDto> myGrades;
  const _ClassSection({required this.title, required this.average, required this.exams, required this.myGrades});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final avg = average;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          leading: SubjectChip(title, bordered: false),
          title: title,
          trailing: avg == null
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ø ', style: typography.sm.copyWith(color: colors.mutedForeground)),
                    Text(formatGrade(avg),
                        style: typography.sm.copyWith(color: gradeColor(context, avg), fontWeight: FontWeight.w700)),
                  ],
                ),
        ),
        FTileGroup(
          divider: FItemDivider.full,
          children: [
            for (final e in exams)
              FTile(
                prefix: e.date != null ? DateChip(fromApiDate(e.date!)) : const Icon(FIcons.fileText),
                title: Text(e.name),
                subtitle: Text([
                  if (isGraded(e.classAverage)) 'class Ø ${formatGrade(e.classAverage)}',
                  if ((myGrades[e.id]?.weighting ?? 1) != 1) 'weight ${formatGrade(myGrades[e.id]!.weighting ?? 1)}',
                ].join(' · ')),
                suffix: GradePill(myGrades[e.id]?.score),
                onPress: () => _showExamDetail(context, e, myGrades[e.id]),
              ),
          ],
        ),
      ],
    );
  }
}

void _showExamDetail(BuildContext context, ExamDto exam, GradeDto? grade) {
  showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: null,
    builder: (sheetCtx) => _ExamDetailSheet(exam: exam, grade: grade),
  );
}

class _ExamDetailSheet extends StatelessWidget {
  final ExamDto exam;
  final GradeDto? grade;
  const _ExamDetailSheet({required this.exam, required this.grade});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final score = grade?.score;
    final classAvg = exam.classAverage;
    final diff = isGraded(score) && isGraded(classAvg) ? score! - classAvg : null;

    Widget figure(String label, num? value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: typography.xs.copyWith(color: colors.mutedForeground)),
              const SizedBox(height: 4),
              Text(isGraded(value) ? formatGrade(value!) : '-',
                  style: typography.xl2.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: isGraded(value) ? gradeColor(context, value!) : colors.mutedForeground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exam.name, style: typography.lg.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (exam.date != null) formatDayShort(fromApiDate(exam.date!)),
                        if ((grade?.weighting ?? 1) != 1) 'weight ${formatGrade(grade!.weighting ?? 1)}',
                      ].join(' · '),
                      style: typography.sm.copyWith(color: colors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((exam.description?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            Text(exam.description!, style: typography.sm.copyWith(color: colors.mutedForeground)),
          ],
          const SizedBox(height: 20),
          Row(children: [figure('Your grade', score), figure('Class average', classAvg)]),
          if (diff != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  diff >= 0 ? FIcons.trendingUp : FIcons.trendingDown,
                  size: 16,
                  color: diff >= 0 ? Accent.green.color : Accent.amber.color,
                ),
                const SizedBox(width: 6),
                Text(
                  diff == 0
                      ? 'Exactly the class average'
                      : '${diff > 0 ? '+' : ''}${formatGrade(diff)} compared to the class',
                  style: typography.sm.copyWith(color: colors.mutedForeground),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
