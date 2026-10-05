import 'package:schuly_api/schuly_api.dart';

import '../../services/grade_settings.dart';
import '../core/grade_color.dart';

/// Swiss school semesters: August to January is the first half, February to
/// July the second. Keyed as year*10 + half; 0 for undated.
int semesterKey(Date? d) {
  if (d == null) return 0;
  if (d.month >= 8) return d.year * 10 + 1;
  if (d.month <= 1) return (d.year - 1) * 10 + 1;
  return (d.year - 1) * 10 + 2;
}

/// "Semester 1 · 26/27", "School year 26/27", or "Undated".
String periodLabel(int key) {
  if (key == 0) return 'Undated';
  final year = key ~/ 10, half = key % 10;
  final a = (year % 100).toString().padLeft(2, '0');
  final b = ((year + 1) % 100).toString().padLeft(2, '0');
  return half == 0 ? 'School year $a/$b' : 'Semester $half · $a/$b';
}

/// Weighted average of the graded exams in [exams], or null when none is graded.
double? subjectAverage(Iterable<ExamDto> exams, Map<String, GradeDto> myGrades) {
  double ws = 0, ss = 0;
  for (final e in exams) {
    final g = myGrades[e.id];
    if (g == null || !isGraded(g.score)) continue;
    final w = (g.weighting ?? 1).toDouble();
    ws += w;
    ss += g.score!.toDouble() * w;
  }
  return ws > 0 ? ss / ws : null;
}

/// The average across [byClass] according to [settings]: either the plain
/// mean of the (rounded) subject averages, or every exam weighted together.
/// Restrict to [classIds] for a group average.
double? overallAverage(Map<String, List<ExamDto>> byClass, Map<String, GradeDto> myGrades, GradeSettings settings, {Set<String>? classIds}) {
  final selected = classIds == null ? byClass : {for (final e in byClass.entries) if (classIds.contains(e.key)) e.key: e.value};
  final double? raw;
  if (settings.method == AverageMethod.examWeighted) {
    raw = subjectAverage(selected.values.expand((e) => e), myGrades);
  } else {
    final averages = [for (final exams in selected.values) ?subjectAverage(exams, myGrades)].map(settings.subjectRounding.apply).toList();
    raw = averages.isEmpty ? null : averages.reduce((a, b) => a + b) / averages.length;
  }
  return raw == null ? null : settings.overallRounding.apply(raw);
}
