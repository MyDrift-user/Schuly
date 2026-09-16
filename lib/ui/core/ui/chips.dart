import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';

import 'accents.dart';

const _subjectPalette = [
  Accent.blue,
  Accent.violet,
  Accent.green,
  Accent.amber,
  Accent.orange,
  Accent.red,
  Accent.teal,
  Accent.pink,
];

/// A stable colour per subject name, so "Mathematik" looks the same in the
/// timetable, the grades and the class list.
Accent subjectAccent(String name) {
  final key = subjectCode(name);
  var h = 0;
  for (final c in key.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _subjectPalette[h % _subjectPalette.length];
}

/// "Mathematik" → "MA", "Bildnerisches Gestalten" → "BG",
/// "Mathematik: Prüfung" → "MA".
String subjectCode(String name) {
  final base = name.split(':').first.trim();
  final words = base.split(RegExp(r'[\s\-/]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  final code = words.length == 1 ? words.first.substring(0, words.first.length.clamp(0, 2)) : words.take(2).map((w) => w[0]).join();
  return code.toUpperCase();
}

/// The two-letter subject code in a bordered square, the way a printed
/// timetable abbreviates subjects.
class SubjectChip extends StatelessWidget {
  const SubjectChip(this.name, {super.key, this.size = 38, this.highlighted = false, this.bordered = true});

  final String name;
  final double size;

  /// Without the square: just the coloured code, for inline use in headers.
  final bool bordered;

  /// Draws the border in the subject colour, for the lesson running now.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final accent = subjectAccent(name);
    return Container(
      width: bordered ? size : null,
      height: bordered ? size : null,
      alignment: Alignment.center,
      decoration: bordered
          ? BoxDecoration(
              border: Border.all(color: highlighted ? accent.color : colors.border, width: highlighted ? 1.5 : 1),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Text(
        subjectCode(name),
        style: typography.sm.copyWith(
          color: accent.color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          height: 1,
        ),
      ),
    );
  }
}

/// The date column of a schedule list: weekday over the day number, the way
/// calendar agenda views mark each day. Today's number sits in a filled disc.
class DateChip extends StatelessWidget {
  const DateChip(this.date, {super.key, this.accent});

  final DateTime date;

  /// Colours the day number; defaults to the foreground.
  final Accent? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final local = date.toLocal();
    final isToday = DateTime.now().year == local.year && DateTime.now().month == local.month && DateTime.now().day == local.day;
    return SizedBox(
      width: 38,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('EEE').format(local).toUpperCase(),
            style: typography.xs.copyWith(fontSize: 10, height: 1, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: colors.mutedForeground),
          ),
          const SizedBox(height: 3),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: isToday ? BoxDecoration(color: colors.primary, shape: BoxShape.circle) : null,
            child: Text(
              '${local.day}',
              style: typography.base.copyWith(
                fontWeight: FontWeight.w700,
                height: 1,
                color: isToday ? colors.primaryForeground : (accent?.color ?? colors.foreground),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
