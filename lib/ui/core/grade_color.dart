import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'ui/accents.dart';

Color gradeColor(BuildContext context, num grade) => gradeAccent(grade).color;

bool isGraded(num? score) => score != null && score > 0;

String formatGrade(num grade) {
  final s = grade.toStringAsFixed(2);
  return s.endsWith('00')
      ? grade.toStringAsFixed(0)
      : (s.endsWith('0') ? grade.toStringAsFixed(1) : s);
}

/// A grade in a tinted pill. [large] is for hero placements such as the
/// exam detail sheet.
class GradePill extends StatelessWidget {
  const GradePill(this.score, {super.key, this.large = false});

  final num? score;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final graded = isGraded(score);
    final accent = graded ? gradeAccent(score!) : Accent.neutral;
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: graded ? accent.color.withValues(alpha: 0.5) : colors.border, width: large ? 1.5 : 1),
        borderRadius: BorderRadius.circular(large ? 12 : 8),
      ),
      child: Text(
        graded ? formatGrade(score!) : '-',
        style: (large ? typography.xl2 : typography.sm).copyWith(
          color: graded ? accent.color : colors.mutedForeground,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
