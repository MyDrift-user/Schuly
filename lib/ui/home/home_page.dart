import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:schuly_api/schuly_api.dart';

import '../../services/grade_settings.dart';
import '../../services/layout_prefs.dart';
import '../../services/school_data_service.dart';
import '../authenticator/authenticator_vault_screen.dart';
import '../core/dates.dart';
import '../core/grade_color.dart';
import '../core/ui/accents.dart';
import '../core/ui/chips.dart';
import '../core/ui/dense_tile.dart';
import '../core/ui/now_ticker.dart';
import '../core/ui/section_header.dart';
import '../core/ui/stat_card.dart';
import '../dashboard/tab_requests.dart';
import '../documents/documents_page.dart';
import '../grades/grade_math.dart';
import '../timetable/day_schedule.dart';
import '../timetable/timeline_row.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Listenable.merge([LayoutPrefs.instance, GradeSettings.instance]), builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final svc = SchoolDataService.instance;

    bool isHoliday(AgendaEntryDto a) => a.entryType == AgendaEntryType.holiday;

    final todayEntries = svc.agenda.where((a) => !isHoliday(a) && isSameDay(a.date, today)).toList()
      ..sort((a, b) => a.date.toLocal().compareTo(b.date.toLocal()));

    final holidays = svc.agenda
        .where((a) => isHoliday(a) && !dayOf(a.endDate ?? a.date).isBefore(today))
        .toList()
      ..sort((a, b) => a.date.toLocal().compareTo(b.date.toLocal()));
    final nextHoliday = holidays.isEmpty ? null : holidays.first;

    final upcomingTests = svc.agenda
        .where((a) =>
            a.entryType == AgendaEntryType.test &&
            !dayOf(a.date).isBefore(today) &&
            daysBetween(today, a.date) <= 7)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final myGrades = svc.myGradesByExam;
    final examById = {for (final e in svc.exams) e.id: e};
    final classNameById = <String?, String?>{
      for (final c in (svc.me?.classes ?? const <UserClassDto>[])) c.classId: c.className,
      ...svc.classNameById,
    };
    final graded = myGrades.entries.where((e) => isGraded(e.value.score)).toList()
      ..sort((a, b) {
        final da = examById[a.key]?.date, db = examById[b.key]?.date;
        if (da == null) return db == null ? 0 : 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    // Only what changed lately; the grades tab has the rest.
    final latestGrades = graded.where((e) {
      final d = examById[e.key]?.date;
      return d != null && daysBetween(fromApiDate(d), today) <= 14;
    }).take(3).toList();

    final byClass = <String, List<ExamDto>>{};
    for (final e in graded) {
      final exam = examById[e.key];
      if (exam != null) byClass.putIfAbsent(exam.classId ?? '-', () => []).add(exam);
    }
    final average = overallAverage(byClass, myGrades, GradeSettings.instance);

    final recentAbsences = svc.absences.where((a) => daysBetween(a.from, today) <= 14).toList()..sort((a, b) => b.from.compareTo(a.from));
    final holidaySoon = nextHoliday != null && daysBetween(today, nextHoliday.date) <= 21;
    final firstName = svc.me?.firstName.trim();
    final prefs = LayoutPrefs.instance;

    StatCard? tile(HomeTile t) => switch (t) {
          HomeTile.average => StatCard(
              icon: FIcons.chartColumn,
              accent: average == null ? Accent.neutral : gradeAccent(average),
              value: average == null ? '-' : formatGrade(average),
              label: 'Average',
              onPress: () => TabRequests.request(DashboardTab.grades),
            ),
          HomeTile.absences => StatCard(
              icon: FIcons.calendarOff,
              value: '${svc.absences.length}',
              label: svc.absences.length == 1 ? 'Absence' : 'Absences',
              onPress: () => TabRequests.request(DashboardTab.absences),
            ),
          HomeTile.holiday => StatCard(
              icon: FIcons.treePalm,
              value: nextHoliday == null ? '-' : _daysUntil(nextHoliday.date),
              label: 'Holidays',
              onPress: () => TabRequests.request(DashboardTab.timetable),
            ),
          HomeTile.tests => StatCard(
              icon: FIcons.clipboardList,
              value: '${upcomingTests.length}',
              label: upcomingTests.length == 1 ? 'Test soon' : 'Tests soon',
              onPress: () => TabRequests.request(DashboardTab.timetable),
            ),
          HomeTile.lessons => StatCard(
              icon: FIcons.calendarDays,
              value: '${todayEntries.where((a) => a.entryType == AgendaEntryType.lesson).length}',
              label: 'Lessons today',
              onPress: () => TabRequests.request(DashboardTab.timetable),
            ),
          HomeTile.documents => StatCard(
              icon: FIcons.folder,
              value: '${svc.documents.length}',
              label: 'Documents',
              onPress: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DocumentsScreen())),
            ),
          HomeTile.authenticator => StatCard(
              icon: FIcons.keyRound,
              value: '2FA',
              label: 'Authenticator',
              onPress: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthenticatorVaultScreen())),
            ),
        };

    List<Widget> section(HomeSection s) => switch (s) {
          HomeSection.tiles => [
              if (prefs.homeTiles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: StatRow(children: [for (final t in prefs.homeTiles) ?tile(t)]),
                ),
            ],
          HomeSection.today => [
              if (todayEntries.isNotEmpty)
                NowTicker(
                  builder: (context, now) {
                    final items = upcomingItems(buildDaySchedule(todayEntries), now);
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionHeader(
                            icon: FIcons.calendarDays,
                            title: 'Today',
                            actionLabel: 'Timetable',
                            onAction: () => TabRequests.request(DashboardTab.timetable),
                          ),
                          for (var i = 0; i < items.length; i++)
                            TimelineRow(item: items[i], now: now, isFirst: i == 0, isLast: i == items.length - 1, side: prefs.timeColumn, dense: true),
                        ],
                      ),
                    );
                  },
                ),
            ],
          HomeSection.tests => [
              if (upcomingTests.isNotEmpty) ...[
                const SectionHeader(icon: FIcons.clipboardList, title: 'Upcoming tests'),
                FTileGroup(
                  divider: FItemDivider.full,
                  children: [
                    for (final a in upcomingTests.take(3))
                      DenseTile(prefix: DenseDate(a.date), title: a.title.isNotEmpty ? a.title : 'Test', trailing: countdown(a.date)),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ],
          HomeSection.grades => [
              if (latestGrades.isNotEmpty) ...[
                SectionHeader(
                  icon: FIcons.chartColumn,
                  title: 'New grades',
                  actionLabel: 'All grades',
                  onAction: () => TabRequests.request(DashboardTab.grades),
                ),
                FTileGroup(
                  divider: FItemDivider.full,
                  children: [
                    for (final entry in latestGrades)
                      DenseTile(
                        prefix: SubjectChip(classNameById[examById[entry.key]?.classId] ?? '?', size: 30),
                        title: examById[entry.key]?.name ?? 'Exam',
                        suffix: GradePill(entry.value.score),
                        onPress: () => TabRequests.request(DashboardTab.grades),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ],
          HomeSection.holiday => [
              if (holidaySoon) ...[
                const SectionHeader(icon: FIcons.treePalm, title: 'Next holiday'),
                FTileGroup(
                  divider: FItemDivider.full,
                  children: [
                    DenseTile(
                      prefix: DenseDate(nextHoliday.date),
                      title: nextHoliday.title.isNotEmpty ? nextHoliday.title : 'Holiday',
                      trailing: countdown(nextHoliday.date),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ],
          HomeSection.absences => [
              if (recentAbsences.isNotEmpty) ...[
                SectionHeader(
                  icon: FIcons.calendarOff,
                  title: 'Recent absences',
                  actionLabel: 'All',
                  onAction: () => TabRequests.request(DashboardTab.absences),
                ),
                FTileGroup(
                  divider: FItemDivider.full,
                  children: [
                    for (final a in recentAbsences.take(2))
                      DenseTile(
                        prefix: DenseDate(a.from, color: a.type == AbsenceType.delay ? Accent.amber.color : Accent.red.color),
                        title: a.reason.isNotEmpty ? a.reason : 'Absence',
                        onPress: () => TabRequests.request(DashboardTab.absences),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ],
        };

    return RefreshIndicator(
      onRefresh: svc.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    firstName == null || firstName.isEmpty ? greeting(DateTime.now()) : '${greeting(DateTime.now())}, $firstName',
                    style: typography.lg.copyWith(fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(formatDayShort(today), style: typography.sm.copyWith(color: colors.mutedForeground)),
              ],
            ),
          ),
          for (final s in prefs.homeOrder)
            if (!prefs.homeHidden.contains(s)) ...section(s),
        ],
      ),
    );
  }

  static String _daysUntil(DateTime d) {
    final days = daysBetween(today, d);
    if (days <= 0) return 'Now';
    return '${days}d';
  }
}
