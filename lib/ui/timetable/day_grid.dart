import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:schuly_api/schuly_api.dart';

import '../../l10n/app_localizations.dart';
import '../core/dates.dart';
import '../core/ui/accents.dart';
import '../core/ui/chips.dart';
import 'day_schedule.dart';
import 'entry_style.dart';

/// A day as a proportional time grid: hour gutter on the left, each entry a
/// block whose height is its duration, a marker at the current time.
class DayGrid extends StatelessWidget {
  const DayGrid({super.key, required this.entries, required this.now});

  final List<AgendaEntryDto> entries;
  final DateTime now;

  static const _pxPerMinute = 1.7;
  static const _gutter = 52.0;
  static const _hourLabelHeight = 14.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final t = AppLocalizations.of(context)!;
    final items = buildDaySchedule(entries);
    final lessons = items.whereType<LessonItem>().toList();
    if (lessons.isEmpty) return const SizedBox.shrink();

    final first = lessons.first.start;
    final last = lessons.map((l) => l.end).reduce((a, b) => a.isAfter(b) ? a : b);
    final gridStart = DateTime(first.year, first.month, first.day, first.hour);
    final gridEnd = DateTime(last.year, last.month, last.day, last.hour + 1);
    final totalMinutes = gridEnd.difference(gridStart).inMinutes;
    double offsetOf(DateTime d) => d.difference(gridStart).inMinutes * _pxPerMinute;
    final isToday = isSameDay(now, gridStart);
    final showNow = isToday && !now.isBefore(gridStart) && now.isBefore(gridEnd);

    return SizedBox(
      height: totalMinutes * _pxPerMinute + _hourLabelHeight,
      child: Stack(
        children: [
          for (var h = gridStart; !h.isAfter(gridEnd); h = h.add(const Duration(hours: 1)))
            Positioned(
              left: 0,
              right: 0,
              top: offsetOf(h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _gutter,
                    child: Text(formatHm(h),
                        style: typography.xs.copyWith(
                          color: colors.mutedForeground,
                          height: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ),
                  Expanded(child: Container(height: 1, margin: const EdgeInsets.only(top: 5), color: colors.border)),
                ],
              ),
            ),
          for (final brk in items.whereType<BreakItem>())
            if (brk.minutes >= 30)
              Positioned(
                left: _gutter,
                right: 0,
                top: offsetOf(brk.start) + _hourLabelHeight / 2,
                height: brk.minutes * _pxPerMinute - _hourLabelHeight,
                child: Center(
                  child: Text(
                    brk.isLunch ? t.lunchBreakDuration(brk.minutes) : t.breakDuration(brk.minutes),
                    style: typography.xs.copyWith(color: colors.mutedForeground),
                  ),
                ),
              ),
          for (final lesson in lessons)
            Positioned(
              left: _gutter,
              right: 0,
              top: offsetOf(lesson.start) + _hourLabelHeight / 2,
              height: (lesson.end.difference(lesson.start).inMinutes * _pxPerMinute - 3).clamp(28.0, double.infinity),
              child: _Block(item: lesson, now: now),
            ),
          if (showNow)
            Positioned(
              left: _gutter - 5,
              right: 0,
              top: offsetOf(now) + _hourLabelHeight / 2 - 5,
              child: IgnorePointer(
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: Accent.red.color, shape: BoxShape.circle)),
                    Expanded(child: Container(height: 2, color: Accent.red.color)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.item, required this.now});

  final LessonItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final style = entryStyle(context, item.entry.entryType);
    final title = item.entry.title.isNotEmpty ? item.entry.title : style.label;
    final accent = item.entry.entryType == AgendaEntryType.lesson ? subjectAccent(title) : style.accent;
    final current = item.isCurrentAt(now);
    final past = !now.isBefore(item.end);
    final description = item.entry.description;
    final meta = [item.entry.place, description == null ? null : stripShortCode(description)]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');
    final remaining = current ? AppLocalizations.of(context)!.minutesLeft(item.remainingMinutesAt(now)) : null;

    return Opacity(
      opacity: past ? 0.55 : 1,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: current ? accent.color : colors.border, width: current ? 1.5 : 1),
          borderRadius: context.theme.style.borderRadius,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final roomy = constraints.maxHeight >= 40;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.sm.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
                            ),
                            if (item.entry.entryType != AgendaEntryType.lesson) ...[
                              const SizedBox(width: 6),
                              Icon(style.icon, size: 14, color: style.accent.color),
                            ],
                          ],
                        ),
                        if (roomy && (meta.isNotEmpty || remaining != null))
                          Text(
                            remaining == null ? meta : (meta.isEmpty ? remaining : '$meta · $remaining'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.xs.copyWith(color: remaining == null ? colors.mutedForeground : accent.color, height: 1.3),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
