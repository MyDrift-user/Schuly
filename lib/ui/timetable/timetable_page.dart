import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:schuly_api/schuly_api.dart';

import '../../l10n/app_localizations.dart';
import '../../services/layout_prefs.dart';
import '../../services/school_data_service.dart';
import '../customize/customize_sheet.dart';
import '../core/dates.dart';
import '../core/ui/accents.dart';
import '../core/ui/empty_state.dart';
import '../core/ui/now_ticker.dart';
import 'day_schedule.dart';
import 'day_strip.dart';
import 'timeline_row.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  DateTime? _selected; // null until the user picks or we auto-anchor
  bool _userPicked = false;

  @override
  void initState() {
    super.initState();
    SchoolDataService.instance.addListener(_autoAnchor);
    _autoAnchor();
  }

  @override
  void dispose() {
    SchoolDataService.instance.removeListener(_autoAnchor);
    super.dispose();
  }

  void _autoAnchor() {
    if (_userPicked || _selected != null) return;
    final day = _nearestEntryDay(SchoolDataService.instance.agenda, today);
    if (day != null && mounted) setState(() => _selected = day);
  }

  static DateTime? _nearestEntryDay(List<AgendaEntryDto> agenda, DateTime today) {
    final days = <DateTime>{for (final a in agenda) dayOf(a.date)}.toList()..sort();
    if (days.isEmpty) return null;
    for (final d in days) {
      if (!d.isBefore(today)) return d; // soonest upcoming (incl. today)
    }
    return days.last; // everything is in the past → most recent
  }

  void _jumpToToday() => setState(() {
        _userPicked = true;
        _selected = today;
      });

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: LayoutPrefs.instance, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final t = AppLocalizations.of(context)!;
    final svc = SchoolDataService.instance;
    final now = DateTime.now();
    final selected = _selected ?? today;

    final entries = svc.agenda.where((a) => isSameDay(a.date, selected)).toList()
      ..sort((a, b) => a.date.toLocal().compareTo(b.date.toLocal()));
    final holidays = entries.where((a) => a.entryType == AgendaEntryType.holiday).toList();
    final scheduled = entries.where((a) => a.entryType != AgendaEntryType.holiday).toList();
    final isToday = isSameDay(selected, today);

    String summary() {
      if (scheduled.isEmpty) return holidays.isNotEmpty ? holidays.first.title : t.nothingScheduled;
      final lessons = scheduled.where((a) => a.entryType == AgendaEntryType.lesson).length;
      final tests = scheduled.where((a) => a.entryType == AgendaEntryType.test).length;
      final first = scheduled.first.date.toLocal();
      final last = scheduled.last.endDate?.toLocal() ?? scheduled.last.date.toLocal();
      final counts = [
        if (lessons > 0) '$lessons ${lessons == 1 ? 'lesson' : 'lessons'}',
        if (tests > 0) '$tests ${tests == 1 ? 'test' : 'tests'}',
      ].join(', ');
      return '$counts · ${formatHm(first)} - ${formatHm(last)}';
    }

    final prefs = LayoutPrefs.instance;
    final strip = Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: DayStrip(
        selected: selected,
        start: DateTime(now.year - 1),
        end: DateTime(now.year + 2),
        marked: {for (final a in svc.agenda) if (a.entryType != AgendaEntryType.holiday) dayOf(a.date)},
        onSelect: (d) => setState(() {
          _userPicked = true;
          _selected = d;
        }),
      ),
    );
    final titleRow = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'Today' : formatDayLong(selected),
                  style: typography.lg.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(summary(), style: typography.sm.copyWith(color: colors.mutedForeground)),
              ],
            ),
          ),
          if (!isToday)
            FButton(
              style: FButtonStyle.outline(),
              mainAxisSize: MainAxisSize.min,
              prefix: const Icon(FIcons.locate),
              onPress: _jumpToToday,
              child: const Text('Today'),
            ),
          CustomizeButton(onPress: _customize),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prefs.dayStrip == DayStripPosition.top) strip,
        titleRow,
        if (prefs.dayStrip == DayStripPosition.belowTitle) strip,
        Expanded(
          child: RefreshIndicator(
            onRefresh: svc.refresh,
            child: scheduled.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    children: [
                      if (holidays.isNotEmpty)
                        EmptyState(
                          icon: FIcons.treePalm,
                          accent: Accent.orange,
                          title: holidays.first.title.isNotEmpty ? holidays.first.title : t.entryTypeHoliday,
                          message: formatDayRange(holidays.first.date, holidays.first.endDate),
                        )
                      else
                        EmptyState(
                          icon: selected.weekday > 5 ? FIcons.sun : FIcons.calendarOff,
                          accent: selected.weekday > 5 ? Accent.amber : Accent.blue,
                          title: t.nothingScheduled,
                          message: selected.weekday > 5 ? 'Enjoy your weekend!' : 'No lessons on this day.',
                        ),
                    ],
                  )
                : NowTicker(
                    builder: (context, now) {
                      final items = buildDaySchedule(scheduled);
                      final dayRunning = isToday && items.isNotEmpty && now.isBefore(items.last.end);
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(8, 4, 16, 24),
                        children: [
                          for (var i = 0; i < items.length; i++)
                            TimelineRow(item: items[i], now: now, isFirst: i == 0, isLast: i == items.length - 1, dimPast: dayRunning, side: prefs.timeColumn),
                        ],
                      );
                    },
                  ),
          ),
        ),
        if (prefs.dayStrip == DayStripPosition.bottom) ...[
          FDivider(style: (s) => s.copyWith(padding: EdgeInsets.zero)),
          strip,
        ],
      ],
    );
  }

  Future<void> _customize() => showCustomizeSheet(
        context,
        title: 'Customise timetable',
        builder: (context) {
          final prefs = LayoutPrefs.instance;
          return [
            OptionRow<TimeColumnSide>(
              label: 'Time column',
              value: prefs.timeColumn,
              items: {for (final v in TimeColumnSide.values) v.label: v},
              onChange: prefs.setTimeColumn,
            ),
            OptionRow<DayStripPosition>(
              label: 'Day picker',
              value: prefs.dayStrip,
              items: {for (final v in DayStripPosition.values) v.label: v},
              onChange: prefs.setDayStrip,
            ),
          ];
        },
      );
}
