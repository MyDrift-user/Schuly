import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'package:schuly_api/schuly_api.dart' show AgendaEntryType;

import '../../l10n/app_localizations.dart';
import '../core/ui/accents.dart';
import '../core/ui/chips.dart';
import 'day_schedule.dart';
import 'entry_style.dart';

/// A lesson, test or event as a tile: tinted icon, title, one-line subtitle
/// and, while it is running, the remaining time.
class LessonTile extends StatelessWidget with FTileMixin {
  const LessonTile({super.key, required this.item, required this.now, this.showTime = true, this.onPress});

  final LessonItem item;
  final DateTime now;

  /// Whether the time range is part of the subtitle. The timetable's timeline
  /// already shows it in its own column.
  final bool showTime;

  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final t = AppLocalizations.of(context)!;
    final style = entryStyle(context, item.entry.entryType);
    final current = item.isCurrentAt(now);

    final time = item.hasEndTime ? '${formatHm(item.start)} - ${formatHm(item.end)}' : formatHm(item.start);
    final description = item.entry.description;
    final meta = [item.entry.place, description == null ? null : stripShortCode(description)]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');
    final remaining = current ? t.minutesLeft(item.remainingMinutesAt(now)) : null;
    final title = item.entry.title.isNotEmpty ? item.entry.title : style.label;
    final accent = item.entry.entryType == AgendaEntryType.lesson ? subjectAccent(title) : style.accent;

    // A narrow tile ellipsises "details", so the remaining minutes are folded
    // into the subtitle there instead. The wide home tile keeps the slot.
    final Widget? subtitle;
    if (!showTime && remaining != null) {
      subtitle = Text.rich(TextSpan(children: [
        if (meta.isNotEmpty) TextSpan(text: '$meta · '),
        TextSpan(text: remaining, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]));
    } else {
      subtitle = meta.isEmpty ? null : Text(meta);
    }

    return FTile(
      prefix: item.entry.entryType == AgendaEntryType.lesson
          ? SubjectChip(title, highlighted: current)
          : Icon(style.icon, color: style.accent.color),
      title: Text(title, style: current ? TextStyle(color: accent.color, fontWeight: FontWeight.w700) : null),
      subtitle: subtitle,
      details: showTime
          ? Text(remaining ?? time,
              style: typography.sm.copyWith(
                fontWeight: FontWeight.w600,
                color: remaining == null ? colors.mutedForeground : accent.color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ))
          : (item.entry.entryType != AgendaEntryType.lesson && !current ? _TypeChip(label: style.label, accent: style.accent) : null),
      onPress: onPress,
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.accent});

  final String label;
  final Accent accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: accent.color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: context.theme.typography.xs.copyWith(color: accent.color, fontWeight: FontWeight.w600)),
      );
}
