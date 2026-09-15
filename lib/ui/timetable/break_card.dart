import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../l10n/app_localizations.dart';
import 'day_schedule.dart';

/// A gap between two lessons. Same tile language as [LessonTile] but visibly
/// slimmer and muted, since breaks are secondary information.
class BreakCard extends StatelessWidget with FTileMixin {
  const BreakCard({super.key, required this.item, required this.now, this.showTime = true});

  final BreakItem item;
  final DateTime now;

  /// Whether the time range is appended to the label. The timetable's
  /// timeline already shows it in its own column.
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final t = AppLocalizations.of(context)!;
    final current = item.isCurrentAt(now);

    final label = item.isLunch ? t.lunchBreakDuration(item.minutes) : t.breakDuration(item.minutes);
    final range = showTime ? '${formatHm(item.start)} - ${formatHm(item.end)}' : null;
    final base = range == null ? label : '$label · $range';
    final remaining = current ? t.minutesLeft(item.remainingMinutesAt(now)) : null;

    // The timeline's tile is narrow, so "details" ellipsises there - fold the
    // remaining-minutes text into the title instead. The home page keeps the
    // roomier "details" slot.
    final Widget title;
    if (!showTime && remaining != null) {
      title = Text.rich(TextSpan(children: [
        TextSpan(text: '$base · ', style: typography.sm.copyWith(color: colors.mutedForeground)),
        TextSpan(text: remaining, style: typography.sm.copyWith(color: colors.primary, fontWeight: FontWeight.w600)),
      ]));
    } else {
      title = Text(base, style: typography.sm.copyWith(color: colors.mutedForeground));
    }

    return FTile(
      style: (style) => style.copyWith(
        backgroundColor: FWidgetStateMap.all(colors.muted.withValues(alpha: 0.4)),
        contentStyle: (content) => content.copyWith(padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8)),
      ),
      prefix: Icon(item.isLunch ? FIcons.utensils : FIcons.coffee, size: 16, color: colors.mutedForeground),
      title: title,
      details: showTime && remaining != null
          ? Text(remaining, style: typography.sm.copyWith(color: colors.primary, fontWeight: FontWeight.w600))
          : null,
    );
  }
}
