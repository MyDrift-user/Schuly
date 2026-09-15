import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:schuly_api/schuly_api.dart';

import '../../services/api_client.dart';
import '../../services/api_time.dart';
import '../../services/school_data_service.dart';
import '../core/dates.dart';
import '../core/ui/accents.dart';
import '../core/ui/chips.dart';
import '../core/ui/empty_state.dart';
import '../core/ui/section_header.dart';
import '../core/ui/stat_card.dart';

class AbsencesPage extends StatelessWidget {
  const AbsencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.typography;
    final svc = SchoolDataService.instance;
    final absences = svc.absences.toList()..sort((a, b) => b.from.compareTo(a.from));
    final delays = absences.where((a) => a.type == AbsenceType.delay).length;
    final days = absences.where((a) => a.type != AbsenceType.delay).fold<int>(
        0, (n, a) => n + dayOf(a.until).difference(dayOf(a.from)).inDays + 1);

    final byMonth = <DateTime, List<AbsenceDto>>{};
    for (final a in absences) {
      final l = a.from.toLocal();
      byMonth.putIfAbsent(DateTime(l.year, l.month), () => []).add(a);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FButton(
        mainAxisSize: MainAxisSize.min,
        prefix: const Icon(FIcons.plus),
        onPress: svc.me == null ? null : () => _openForm(context),
        child: const Text('Report'),
      ),
      body: RefreshIndicator(
        onRefresh: svc.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text('Absences', style: typography.xl2.copyWith(fontWeight: FontWeight.w800)),
            ),
            StatRow(children: [
              StatCard(
                icon: FIcons.calendarOff,
                accent: Accent.red,
                value: '${absences.length - delays}',
                label: absences.length - delays == 1 ? 'Absence' : 'Absences',
              ),
              StatCard(icon: FIcons.clock, accent: Accent.amber, value: '$delays', label: delays == 1 ? 'Delay' : 'Delays'),
              StatCard(icon: FIcons.calendarX, value: '$days', label: days == 1 ? 'Day missed' : 'Days missed'),
            ]),
            const SizedBox(height: 24),
            if (absences.isEmpty)
              const EmptyState(
                icon: FIcons.badgeCheck,
                accent: Accent.green,
                title: 'No absences',
                message: 'Perfect attendance so far. Report an absence with the button below.',
              )
            else
              for (final entry in byMonth.entries) ...[
                SectionHeader(icon: FIcons.calendar, title: formatMonthYear(entry.key)),
                FTileGroup(
                  divider: FItemDivider.full,
                  children: [
                    for (final a in entry.value)
                      FTile(
                        prefix: DateChip(a.from, accent: a.type == AbsenceType.delay ? Accent.amber : Accent.red),
                        title: Text(a.reason.isNotEmpty ? a.reason : 'Absence'),
                        subtitle: Text(formatDayRange(a.from, a.until)),
                        suffix: _TypeBadge(a.type),
                        onPress: () => _openForm(context, existing: a),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {AbsenceDto? existing}) async {
    final changed = await showFSheet<bool>(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      builder: (_) => _AbsenceForm(existing: existing),
    );
    if (changed == true) await SchoolDataService.instance.refresh();
  }
}

class _TypeBadge extends StatelessWidget {
  final AbsenceType? type;
  const _TypeBadge(this.type);
  @override
  Widget build(BuildContext context) {
    final isDelay = type == AbsenceType.delay;
    final accent = isDelay ? Accent.amber : Accent.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: accent.color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(isDelay ? 'Delay' : 'Absence',
          style: TextStyle(color: accent.color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _AbsenceForm extends StatefulWidget {
  final AbsenceDto? existing;
  const _AbsenceForm({this.existing});
  @override
  State<_AbsenceForm> createState() => _AbsenceFormState();
}

class _AbsenceFormState extends State<_AbsenceForm> {
  late final TextEditingController _reason;
  late AbsenceType _type;
  late DateTime _from;
  late DateTime _until;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _reason = TextEditingController(text: e?.reason ?? '');
    _type = e?.type ?? AbsenceType.absence;
    _from = e?.from ?? DateTime.now();
    _until = e?.until ?? DateTime.now();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ApiClient.instance.api.getAbsencesApi();
      final existing = widget.existing;
      if (existing == null) {
        final schoolUserId = SchoolDataService.instance.me?.id;
        await api.apiAbsencesPost(
          createAbsenceCommand: CreateAbsenceCommand((b) => b
            ..reason = _reason.text.trim()
            ..type = _type
            ..from = ApiTime.utcDate(_from)
            ..until = ApiTime.utcDate(_until)
            ..schoolUserId = schoolUserId),
        );
      } else {
        await api.apiAbsencesPut(
          updateAbsenceCommand: UpdateAbsenceCommand((b) => b
            ..absenceId = existing.id
            ..reason = _reason.text.trim()
            ..type = _type
            ..from = ApiTime.utcDate(_from)
            ..until = ApiTime.utcDate(_until)
            ..schoolUserId = existing.schoolUserId),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'HTTP ${e.response?.statusCode}: ${e.response?.data}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing?.id == null) return;
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, animation) => FDialog(
        animation: animation,
        title: const Text('Delete this absence?'),
        body: const Text('This removes the entry. You can report it again later.'),
        actions: [
          FButton(style: FButtonStyle.outline(), onPress: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FButton(style: FButtonStyle.destructive(), onPress: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ApiClient.instance.api.getAbsencesApi().apiAbsencesIdDelete(id: existing!.id!);
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'HTTP ${e.response?.statusCode}: ${e.response?.data}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final navBar = MediaQuery.viewPaddingOf(context).bottom;
    final editing = widget.existing != null;

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + (keyboard > navBar ? keyboard : navBar)),
      child: SingleChildScrollView(
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
                Icon(editing ? FIcons.pencil : FIcons.calendarPlus, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(editing ? 'Edit absence' : 'Report absence',
                          style: typography.lg.copyWith(fontWeight: FontWeight.w700)),
                      Text('Tell the school when and why you were away.',
                          style: typography.sm.copyWith(color: colors.mutedForeground)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _TypeToggle(value: _type, onChange: (v) => setState(() => _type = v)),
            const SizedBox(height: 16),
            FTextField(
              control: FTextFieldControl.managed(controller: _reason),
              label: const Text('Reason'),
              hint: _type == AbsenceType.delay ? 'e.g. Train delayed' : 'e.g. Sick, doctor\'s appointment',
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FDateField.calendar(
                    label: const Text('From'),
                    control: FDateFieldControl.lifted(
                      date: _from,
                      onChange: (d) {
                        if (d == null) return;
                        setState(() {
                          _from = d;
                          if (_until.isBefore(_from)) _until = _from;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FDateField.calendar(
                    label: const Text('Until'),
                    control: FDateFieldControl.lifted(
                      date: _until,
                      onChange: (d) {
                        if (d == null) return;
                        setState(() => _until = d.isBefore(_from) ? _from : d);
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              FAlert(
                style: FAlertStyle.destructive(),
                icon: const Icon(FIcons.triangleAlert),
                title: const Text('Could not save'),
                subtitle: Text(_error!),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (editing) ...[
                  FButton.icon(
                    style: FButtonStyle.outline(),
                    onPress: _busy ? null : _delete,
                    child: Icon(FIcons.trash2, color: colors.destructive),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FButton(
                    prefix: _busy ? null : const Icon(FIcons.check),
                    onPress: _busy ? null : _save,
                    child: Text(_busy ? 'Saving…' : (editing ? 'Save changes' : 'Report absence')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final AbsenceType value;
  final ValueChanged<AbsenceType> onChange;
  const _TypeToggle({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;

    Widget option(AbsenceType type, IconData icon, String label, String hint, Accent accent) {
      final selected = value == type;
      return Expanded(
        child: FTappable(
          onPress: () => onChange(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? colors.primary : colors.background,
              border: Border.all(color: selected ? colors.primary : colors.border),
              borderRadius: context.theme.style.borderRadius,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? colors.primaryForeground : accent.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: typography.sm.copyWith(
                              fontWeight: FontWeight.w700, color: selected ? colors.primaryForeground : colors.foreground)),
                      Text(hint,
                          style: typography.xs.copyWith(
                              color: selected ? colors.primaryForeground.withValues(alpha: 0.7) : colors.mutedForeground)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(AbsenceType.absence, FIcons.calendarOff, 'Absence', 'Whole lessons', Accent.red),
        const SizedBox(width: 10),
        option(AbsenceType.delay, FIcons.clock, 'Delay', 'Arrived late', Accent.amber),
      ],
    );
  }
}
