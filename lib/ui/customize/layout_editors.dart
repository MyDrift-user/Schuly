import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'package:schuly_api/schuly_api.dart';

import '../../services/grade_settings.dart';
import '../../services/layout_prefs.dart';
import '../../services/school_data_service.dart';
import '../core/ui/chips.dart';

/// Half-height sheet so the page behind it shows every change as it is made.
Future<void> showCustomizeSheet(BuildContext context, {required String title, required List<Widget> Function(BuildContext context) builder}) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: 0.55,
    builder: (sheetContext) => _CustomizeSheet(title: title, builder: builder),
  );
}

class _CustomizeSheet extends StatelessWidget {
  const _CustomizeSheet({required this.title, required this.builder});

  final String title;
  final List<Widget> Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    return ListenableBuilder(
      listenable: Listenable.merge([LayoutPrefs.instance, GradeSettings.instance]),
      builder: (context, _) => Container(
        decoration: BoxDecoration(color: colors.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
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
                Expanded(child: Text(title, style: typography.lg.copyWith(fontWeight: FontWeight.w700))),
                FButton(
                  style: FButtonStyle.ghost(),
                  mainAxisSize: MainAxisSize.min,
                  prefix: const Icon(FIcons.rotateCcw),
                  onPress: LayoutPrefs.instance.isDefault && GradeSettings.instance.isDefault
                      ? null
                      : () {
                          LayoutPrefs.instance.reset();
                          GradeSettings.instance.reset();
                        },
                  child: const Text('Reset'),
                ),
                FButton.icon(style: FButtonStyle.ghost(), onPress: () => Navigator.of(context).pop(), child: const Icon(FIcons.x)),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: builder(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The option widgets for each tab; shared by the sheet and the settings screen.
List<Widget> homeLayoutOptions(LayoutPrefs prefs) => [
      SectionOrderEditor(
        order: prefs.homeOrder,
        hidden: prefs.homeHidden,
        labelOf: (s) => s.label,
        onMove: prefs.moveHomeSection,
        onToggle: prefs.setHomeSectionVisible,
      ),
      const SectionLabel('Summary tiles'),
      for (var i = 0; i < 3; i++)
        OptionRow<String>(
          label: 'Tile ${i + 1}',
          value: i < prefs.homeTiles.length ? prefs.homeTiles[i].name : 'none',
          items: {'None': 'none', for (final t in HomeTile.values) t.label: t.name},
          onChange: (name) {
            final tiles = List.of(prefs.homeTiles);
            final chosen = HomeTile.values.where((t) => t.name == name).firstOrNull;
            if (chosen == null) {
              if (i < tiles.length) tiles.removeAt(i);
            } else if (i < tiles.length) {
              tiles[i] = chosen;
            } else {
              tiles.add(chosen);
            }
            prefs.setHomeTiles(tiles);
          },
        ),
    ];

List<Widget> timetableLayoutOptions(LayoutPrefs prefs) => [
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

List<Widget> gradesLayoutOptions(BuildContext context) {
  final settings = GradeSettings.instance;
  final tileItems = {
    'None': 'none',
    ...{for (final e in GradeSettings.tileLabels.entries) e.value: e.key},
    for (final g in settings.groups) 'Ø ${g.name}': 'group:${g.id}',
  };
  final slots = settings.tiles.length < GradeSettings.maxTiles ? settings.tiles.length + 1 : settings.tiles.length;
  return [
    const SectionLabel('Summary tiles'),
    for (var i = 0; i < slots; i++)
      OptionRow<String>(
        label: 'Tile ${i + 1}',
        value: i < settings.tiles.length ? settings.tiles[i] : 'none',
        items: tileItems,
        onChange: (key) {
          final tiles = List.of(settings.tiles);
          if (key == 'none') {
            if (i < tiles.length) tiles.removeAt(i);
          } else if (i < tiles.length) {
            tiles[i] = key;
          } else {
            tiles.add(key);
          }
          settings.setTiles(tiles);
        },
      ),
    const SectionLabel('Average calculation'),
    OptionRow<AverageMethod>(
      label: 'Method',
      value: settings.method,
      items: {for (final v in AverageMethod.values) v.label: v},
      onChange: settings.setMethod,
    ),
    if (settings.method == AverageMethod.subjectMean)
      OptionRow<Rounding>(
        label: 'Round each subject',
        value: settings.subjectRounding,
        items: {for (final v in Rounding.values) v.label: v},
        onChange: settings.setSubjectRounding,
      ),
    OptionRow<Rounding>(
      label: 'Round the result',
      value: settings.overallRounding,
      items: {for (final v in Rounding.values) v.label: v},
      onChange: settings.setOverallRounding,
    ),
    const SectionLabel('Subject groups'),
    if (settings.groups.isNotEmpty)
      FTileGroup(
        divider: FItemDivider.full,
        children: [
          for (final g in settings.groups)
            FTile(
              prefix: const Icon(FIcons.layers),
              title: Text(g.name),
              subtitle: Text('${g.classIds.length} ${g.classIds.length == 1 ? 'subject' : 'subjects'}'),
              suffix: FButton.icon(style: FButtonStyle.ghost(), onPress: () => settings.removeGroup(g.id), child: const Icon(FIcons.trash2)),
              onPress: () => showGroupEditor(context, g),
            ),
        ],
      ),
    Padding(
      padding: const EdgeInsets.only(top: 10),
      child: FButton(
        style: FButtonStyle.outline(),
        prefix: const Icon(FIcons.plus),
        onPress: () => showGroupEditor(context, null),
        child: const Text('Add subject group'),
      ),
    ),
  ];
}

/// Name a group and pick the subjects that average together.
Future<void> showGroupEditor(BuildContext context, GradeGroup? existing) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: 0.85,
    builder: (sheetContext) => _GroupEditor(existing: existing),
  );
}

class _GroupEditor extends StatefulWidget {
  const _GroupEditor({required this.existing});

  final GradeGroup? existing;

  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final Set<String> _classIds = {...?widget.existing?.classIds};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _classIds.isEmpty) return;
    final id = widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    await GradeSettings.instance.saveGroup(GradeGroup(id: id, name: name, classIds: _classIds));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final svc = SchoolDataService.instance;
    final classes = <String, String>{
      ...svc.classNameById,
      for (final c in svc.me?.classes ?? const <UserClassDto>[]) c.classId: c.className,
    };
    final entries = classes.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final navBar = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(color: colors.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + (keyboard > navBar ? keyboard : navBar)),
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
          Text(widget.existing == null ? 'New subject group' : 'Edit subject group', style: typography.lg.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Subjects in a group are averaged together, like the promotion groups in Schulnetz.', style: typography.sm.copyWith(color: colors.mutedForeground)),
          const SizedBox(height: 16),
          FTextField(control: FTextFieldControl.managed(controller: _name), label: const Text('Name'), hint: 'e.g. Languages', textInputAction: TextInputAction.done),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: FTileGroup(
                divider: FItemDivider.full,
                children: [
                  for (final e in entries)
                    FTile(
                      prefix: SubjectChip(e.value, size: 32),
                      title: Text(e.value),
                      suffix: FSwitch(value: _classIds.contains(e.key), onChange: (v) => setState(() => v ? _classIds.add(e.key) : _classIds.remove(e.key))),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FButton(prefix: const Icon(FIcons.check), onPress: _save, child: Text(widget.existing == null ? 'Add group' : 'Save')),
        ],
      ),
    );
  }
}

List<Widget> absencesLayoutOptions(LayoutPrefs prefs) => [
      SwitchRow(label: 'Summary tiles', value: prefs.absencesTiles, onChange: prefs.setAbsencesTiles),
    ];

/// Opens the sheet for a dashboard tab; null for tabs with nothing to customise.
Future<void>? showTabCustomizeSheet(BuildContext context, int tab) {
  final prefs = LayoutPrefs.instance;
  return switch (tab) {
    0 => showCustomizeSheet(context, title: 'Customise home', builder: (_) => homeLayoutOptions(prefs)),
    1 => showCustomizeSheet(context, title: 'Customise timetable', builder: (_) => timetableLayoutOptions(prefs)),
    2 => showCustomizeSheet(context, title: 'Customise grades', builder: gradesLayoutOptions),
    3 => showCustomizeSheet(context, title: 'Customise absences', builder: (_) => absencesLayoutOptions(prefs)),
    _ => null,
  };
}

/// A list of sections with a visibility switch and up/down controls.
class SectionOrderEditor extends StatelessWidget {
  const SectionOrderEditor({super.key, required this.order, required this.hidden, required this.labelOf, required this.onMove, required this.onToggle});

  final List<HomeSection> order;
  final Set<HomeSection> hidden;
  final String Function(HomeSection section) labelOf;
  final void Function(HomeSection section, int delta) onMove;
  final void Function(HomeSection section, bool visible) onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return FTileGroup(
      divider: FItemDivider.full,
      children: [
        for (final (i, section) in order.indexed)
          FTile(
            prefix: FSwitch(value: !hidden.contains(section), onChange: (v) => onToggle(section, v)),
            title: Text(labelOf(section), style: hidden.contains(section) ? TextStyle(color: colors.mutedForeground) : null),
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FButton.icon(style: FButtonStyle.ghost(), onPress: i == 0 ? null : () => onMove(section, -1), child: const Icon(FIcons.chevronUp)),
                FButton.icon(style: FButtonStyle.ghost(), onPress: i == order.length - 1 ? null : () => onMove(section, 1), child: const Icon(FIcons.chevronDown)),
              ],
            ),
          ),
      ],
    );
  }
}

/// A labelled dropdown row for a single option.
class OptionRow<T> extends StatelessWidget {
  const OptionRow({super.key, required this.label, required this.value, required this.items, required this.onChange});

  final String label;
  final T value;
  final Map<String, T> items;
  final ValueChanged<T> onChange;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(child: Text(label, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w600))),
            SizedBox(
              width: 190,
              child: FSelect<T>(
                control: FSelectControl<T>.lifted(value: value, onChange: (v) => v == null ? null : onChange(v)),
                items: items,
              ),
            ),
          ],
        ),
      );
}

class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.label, required this.value, required this.onChange});

  final String label;
  final bool value;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) => FTileGroup(
        divider: FItemDivider.full,
        children: [FTile(title: Text(label), suffix: FSwitch(value: value, onChange: onChange))],
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
        child: Text(text, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w700)),
      );
}
