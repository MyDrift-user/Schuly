import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:schuly_api/schuly_api.dart';

import '../../services/layout_prefs.dart';
import '../core/ui/chips.dart';
import 'break_card.dart';
import 'day_schedule.dart';
import 'entry_style.dart';
import 'lesson_tile.dart';

class TimelineRow extends StatelessWidget {
  const TimelineRow({super.key, required this.item, required this.now, this.isFirst = false, required this.isLast, this.dimPast = false, this.side = TimeColumnSide.left});

  final DayItem item;
  final DateTime now;
  final bool isFirst;
  final bool isLast;

  /// Fade items that are already over. Only meaningful while the day is
  /// still running; a finished or past day reads better at full strength.
  final bool dimPast;

  /// Which side the time column and rail sit on.
  final TimeColumnSide side;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final dayItem = item;
    final showEndTime = dayItem is! LessonItem || dayItem.hasEndTime;
    final current = item.isCurrentAt(now);
    final past = dimPast && !now.isBefore(item.end);
    final Color accent;
    if (dayItem is LessonItem) {
      final style = entryStyle(context, dayItem.entry.entryType);
      final title = dayItem.entry.title.isNotEmpty ? dayItem.entry.title : style.label;
      accent = dayItem.entry.entryType == AgendaEntryType.lesson ? subjectAccent(title).color : style.accent.color;
    } else {
      accent = colors.mutedForeground;
    }
    final dotColor = current ? accent : (past ? colors.border : colors.mutedForeground.withValues(alpha: 0.5));

    final left = side == TimeColumnSide.left;
    final tile = Padding(
      padding: EdgeInsets.only(left: left ? (current ? 82 : 74) : 0, right: left ? 0 : (current ? 82 : 74), bottom: isLast ? 0 : 8),
      child: Opacity(
        opacity: past && !current ? 0.6 : 1,
        child: switch (item) {
          LessonItem lesson => LessonTile(item: lesson, now: now, showTime: false),
          BreakItem brk => BreakCard(item: brk, now: now, showTime: false),
        },
      ),
    );
    final times = Column(
      crossAxisAlignment: left ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
    );
    final dot = Container(
      width: current ? 12 : 10,
      height: current ? 12 : 10,
      decoration: BoxDecoration(
        color: current ? dotColor : colors.background,
        shape: BoxShape.circle,
        border: Border.all(color: dotColor, width: 2),
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
                Positioned(left: left ? 0 : null, right: left ? null : 0, top: 12, width: 50, child: times),
                if (!(isFirst && isLast))
                  Positioned(
                    left: left ? 61 : null,
                    right: left ? null : 61,
                    top: isFirst ? 19 : 0,
                    bottom: isLast ? null : 0,
                    height: isLast ? (isFirst ? 0 : 19) : null,
                    child: Container(width: 2, color: colors.border),
                  ),
                Positioned(left: left ? (current ? 56 : 57) : null, right: left ? null : (current ? 56 : 57), top: 14, child: dot),
              ],
            ),
    );
  }
}
