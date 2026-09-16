import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:schuly_api/schuly_api.dart';

import '../../l10n/app_localizations.dart';
import '../../services/layout_prefs.dart';
import '../../services/school_data_service.dart';
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
  late final DateTime _start = DateTime(DateTime.now().year - 1);
  late final DateTime _end = DateTime(DateTime.now().year + 2);
  late final PageController _pages = PageController(initialPage: _indexOf(today));

  DateTime? _selected; // null until the user picks or we auto-anchor
  bool _userPicked = false;

  int _indexOf(DateTime d) => daysBetween(_start, d);

  @override
  void initState() {
    super.initState();
    SchoolDataService.instance.addListener(_autoAnchor);
    _autoAnchor();
  }

  @override
  void dispose() {
    SchoolDataService.instance.removeListener(_autoAnchor);
    _pages.dispose();
    super.dispose();
  }

  void _autoAnchor() {
    if (_userPicked || _selected != null) return;
    final day = _nearestEntryDay(SchoolDataService.instance.agenda, today);
    if (day != null && mounted) _goTo(day, animate: false);
  }

  static DateTime? _nearestEntryDay(List<AgendaEntryDto> agenda, DateTime today) {
    final days = <DateTime>{for (final a in agenda) dayOf(a.date)}.toList()..sort();
    if (days.isEmpty) return null;
    for (final d in days) {
      if (!d.isBefore(today)) return d; // soonest upcoming (incl. today)
    }
    return days.last; // everything is in the past → most recent
  }

  /// Selects [day] and brings its page into view. A distant day jumps rather
  /// than scrolling through every page in between.
  void _goTo(DateTime day, {bool animate = true, bool picked = false}) {
    final target = dayOf(day);
    setState(() {
      if (picked) _userPicked = true;
      _selected = target;
    });
    if (!_pages.hasClients) return;
    final index = _indexOf(target);
    final current = _pages.page?.round() ?? index;
    if (!animate || (index - current).abs() > 7) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(index, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _pickFromCalendar() async {
    final picked = await showFSheet<DateTime>(
      context: context,
      side: FLayout.btt,
      builder: (sheetContext) => _CalendarSheet(selected: _selected ?? today, start: _start, end: _end),
    );
    if (picked != null && mounted) _goTo(picked, picked: true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: LayoutPrefs.instance, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final t = AppLocalizations.of(context)!;
    final svc = SchoolDataService.instance;
    final selected = _selected ?? today;
    final isToday = isSameDay(selected, today);
    final prefs = LayoutPrefs.instance;

    List<AgendaEntryDto> entriesOn(DateTime day) => svc.agenda.where((a) => isSameDay(a.date, day)).toList()
      ..sort((a, b) => a.date.toLocal().compareTo(b.date.toLocal()));

    String summary(List<AgendaEntryDto> entries) {
      final holidays = entries.where((a) => a.entryType == AgendaEntryType.holiday).toList();
      final scheduled = entries.where((a) => a.entryType != AgendaEntryType.holiday).toList();
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

    final strip = Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: DayStrip(
        selected: selected,
        start: _start,
        end: _end,
        marked: {for (final a in svc.agenda) if (a.entryType != AgendaEntryType.holiday) dayOf(a.date)},
        onSelect: (d) => _goTo(d, picked: true),
      ),
    );

    final titleRow = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: FTappable(
              onPress: _pickFromCalendar,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isToday ? 'Today' : formatDayLong(selected),
                          style: typography.lg.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(FIcons.chevronDown, size: 18, color: colors.mutedForeground),
                    ],
                  ),
                  Text(summary(entriesOn(selected)), style: typography.sm.copyWith(color: colors.mutedForeground)),
                ],
              ),
            ),
          ),
          if (!isToday)
            FButton.icon(style: FButtonStyle.outline(), onPress: () => _goTo(today, picked: true), child: const Icon(FIcons.locate)),
        ],
      ),
    );

    Widget dayPage(DateTime day) {
      final entries = entriesOn(day);
      final holidays = entries.where((a) => a.entryType == AgendaEntryType.holiday).toList();
      final scheduled = entries.where((a) => a.entryType != AgendaEntryType.holiday).toList();
      final dayIsToday = isSameDay(day, today);
      return RefreshIndicator(
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
                      icon: day.weekday > 5 ? FIcons.sun : FIcons.calendarOff,
                      title: t.nothingScheduled,
                      message: day.weekday > 5 ? 'Enjoy your weekend!' : 'No lessons on this day.',
                    ),
                ],
              )
            : NowTicker(
                builder: (context, now) {
                  final items = buildDaySchedule(scheduled);
                  final dayRunning = dayIsToday && items.isNotEmpty && now.isBefore(items.last.end);
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
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prefs.dayStrip == DayStripPosition.top) strip,
        titleRow,
        if (prefs.dayStrip == DayStripPosition.belowTitle) strip,
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: daysBetween(_start, _end) + 1,
            onPageChanged: (i) => setState(() {
              _userPicked = true;
              _selected = addDays(_start, i);
            }),
            itemBuilder: (context, i) => dayPage(addDays(_start, i)),
          ),
        ),
        if (prefs.dayStrip == DayStripPosition.bottom) ...[
          FDivider(style: (s) => s.copyWith(padding: EdgeInsets.zero)),
          strip,
        ],
      ],
    );
  }
}

/// Month calendar for jumping to any date; pops with the picked day.
class _CalendarSheet extends StatelessWidget {
  const _CalendarSheet({required this.selected, required this.start, required this.end});

  final DateTime selected;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    return Container(
      decoration: BoxDecoration(color: colors.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            children: [
              Expanded(child: Text('Jump to a day', style: typography.lg.copyWith(fontWeight: FontWeight.w700))),
              FButton(
                style: FButtonStyle.ghost(),
                mainAxisSize: MainAxisSize.min,
                prefix: const Icon(FIcons.locate),
                onPress: () => Navigator.of(context).pop(today),
                child: const Text('Today'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: FCalendar(
              control: FCalendarControl.managedDate(initial: selected, onChange: (d) => d == null ? null : Navigator.of(context).pop(d)),
              start: start,
              end: end,
              today: today,
              initialMonth: selected,
            ),
          ),
        ],
      ),
    );
  }
}
