import 'package:schuly_api/schuly_api.dart';

import '../../services/grade_settings.dart';
import '../core/grade_color.dart';

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
