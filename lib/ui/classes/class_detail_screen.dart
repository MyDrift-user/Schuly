import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:schuly_api/schuly_api.dart';

import '../../config/oidc_config.dart';
import '../../services/api_client.dart';
import '../../services/api_time.dart';
import '../../services/demo_data.dart';
import '../../services/api_error.dart';
import '../core/dates.dart';
import '../core/grade_color.dart';
import '../core/ui/empty_state.dart';
import '../core/ui/chips.dart';
import '../core/ui/section_header.dart';
import '../core/ui/stat_card.dart';
import '../core/ui/status_view.dart';
import '../timetable/entry_style.dart';

class ClassDetailScreen extends StatefulWidget {
  final String classId;
  final String title;
  const ClassDetailScreen({super.key, required this.classId, required this.title});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  ClassDto? _class;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (DemoData.enabled) {
        if (mounted) setState(() => _class = DemoData.classDetail(widget.classId));
        return;
      }
      final res = await ApiClient.instance.api
          .getClassApi()
          .apiClassSearchGet(classId: widget.classId);
      final data = res.data;
      if (mounted) setState(() => _class = data == null ? null : ApiTime.schoolClass(data));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final c = _class;

    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null) {
      body = ErrorView(message: ApiError.describe(_error!), onRetry: _load);
    } else if (c == null) {
      body = const EmptyState(icon: FIcons.circleQuestionMark, title: 'Class not found');
    } else {
      final students = (c.students ?? const <ClassMemberDto>[]).toList()
        ..sort((a, b) => a.lastName.compareTo(b.lastName));
      final exams = (c.exams ?? const <ExamDto>[]).toList()
        ..sort((a, b) => (b.date?.compareTo(a.date ?? b.date!) ?? 0));
      final agenda = (c.agenda ?? const <AgendaEntryDto>[]).where((a) => !dayOf(a.date).isBefore(today)).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.viewPaddingOf(context).bottom),
          children: [
            if ((c.description?.isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: Text(c.description!, style: typography.sm.copyWith(color: colors.mutedForeground)),
              ),
            StatRow(children: [
              StatCard(icon: FIcons.users, value: '${students.length}', label: 'Students'),
              StatCard(icon: FIcons.fileText, value: '${exams.length}', label: 'Exams'),
              StatCard(icon: FIcons.calendarDays, value: '${agenda.length}', label: 'Upcoming'),
            ]),
            const SizedBox(height: 24),
            if (exams.isNotEmpty) ...[
              const SectionHeader(icon: FIcons.fileText, title: 'Exams'),
              FTileGroup(
                divider: FItemDivider.full,
                children: [
                  for (final e in exams)
                    FTile(
                      prefix: e.date != null ? DateChip(fromApiDate(e.date!)) : const Icon(FIcons.fileText),
                      title: Text(e.name),
                      subtitle: isGraded(e.classAverage) ? Text('class Ø ${formatGrade(e.classAverage)}') : null,
                      suffix: isGraded(e.classAverage) ? GradePill(e.classAverage) : null,
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            if (agenda.isNotEmpty) ...[
              const SectionHeader(icon: FIcons.calendarDays, title: 'Upcoming'),
              FTileGroup(
                divider: FItemDivider.full,
                children: [
                  for (final a in agenda.take(20))
                    FTile(
                      prefix: DateChip(a.date, accent: a.entryType == AgendaEntryType.lesson ? null : entryStyle(context, a.entryType).accent),
                      title: Text(a.title.isNotEmpty ? a.title : entryStyle(context, a.entryType).label),
                      subtitle: Text([formatTime(a.date), if (a.place?.isNotEmpty ?? false) a.place!].join(' · ')),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            if (students.isNotEmpty) ...[
              SectionHeader(icon: FIcons.users, title: 'Students (${students.length})'),
              FTileGroup(
                divider: FItemDivider.full,
                children: [
                  for (final s in students)
                    FTile(
                      prefix: _StudentAvatar(
                        url: OidcConfig.resolveUrl(s.profilePictureUrl),
                        name: '${s.firstName} ${s.lastName}'.trim(),
                      ),
                      title: Text('${s.firstName} ${s.lastName}'.trim()),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return FScaffold(
      header: FHeader.nested(
        title: Text(widget.title),
        prefixes: [FHeaderAction.back(onPress: () => Navigator.of(context).pop())],
      ),
      childPad: false,
      child: body,
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  final String? url;
  final String name;
  const _StudentAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    final fallback = Text(initial,
        style: TextStyle(color: colors.mutedForeground, fontWeight: FontWeight.w600));
    return url == null
        ? FAvatar.raw(size: 36, child: fallback)
        : FAvatar(size: 36, image: NetworkImage(url!), fallback: fallback);
  }
}
