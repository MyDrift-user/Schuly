import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:schuly_api/schuly_api.dart';

import '../core/ui/chips.dart';
import 'break_card.dart';
import 'day_schedule.dart';
import 'entry_style.dart';
import 'lesson_tile.dart';

class TimelineRow extends StatelessWidget {
  const TimelineRow({super.key, required this.item, required this.now, required this.isLast});

  final DayItem item;
  final DateTime now;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final dayItem = item;
    final showEndTime = dayItem is! LessonItem || dayItem.hasEndTime;
    final current = item.isCurrentAt(now);
    final past = !now.isBefore(item.end);
    final Color accent;
    if (dayItem is LessonItem) {
      final style = entryStyle(context, dayItem.entry.entryType);
      final title = dayItem.entry.title.isNotEmpty ? dayItem.entry.title : style.label;
      accent = dayItem.entry.entryType == AgendaEntryType.lesson ? subjectAccent(title).color : style.accent.color;
    } else {
      accent = colors.mutedForeground;
    }
    final dotColor = current ? accent : (past ? colors.border : colors.mutedForeground.withValues(alpha: 0.5));

    final tile = Padding(
      padding: EdgeInsets.only(left: 74, bottom: isLast ? 0 : 8),
      child: Opacity(
        opacity: past && !current ? 0.6 : 1,
        child: switch (item) {
          LessonItem lesson => LessonTile(item: lesson, now: now, showTime: false),
          BreakItem brk => BreakCard(item: brk, now: now, showTime: false),
        },
      ),
    );

    // Android's first frame can come with a zero-width viewport, which Forui's
    // item layout cannot handle; skip that frame.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 120
          ? const SizedBox.shrink()
          : Stack(
      children: [
        tile,
        Positioned(
          left: 0,
          top: 12,
          width: 50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatHm(item.start),
                  style: typography.xs.copyWith(
                    fontWeight: FontWeight.w700,
                    color: past && !current ? colors.mutedForeground : colors.foreground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              if (showEndTime)
                Text(formatHm(item.end),
                    style: typography.xs.copyWith(color: colors.mutedForeground, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ),
        Positioned(
          left: 61,
          top: 0,
          bottom: isLast ? null : 0,
          height: isLast ? 20 : null,
          child: Container(width: 2, color: colors.border),
        ),
        Positioned(
          left: current ? 56 : 57,
          top: 14,
          child: Container(
            width: current ? 12 : 10,
            height: current ? 12 : 10,
            decoration: BoxDecoration(
              color: current ? dotColor : colors.background,
              shape: BoxShape.circle,
              border: Border.all(color: dotColor, width: 2),
            ),
          ),
        ),
      ],
    ),
    );
  }
}
