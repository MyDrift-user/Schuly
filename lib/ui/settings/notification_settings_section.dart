import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../l10n/app_localizations.dart';
import '../../services/app_mode_service.dart';
import '../../services/push_service.dart';
import '../core/ui/accents.dart';
import '../core/ui/section_header.dart';

class NotificationSettingsSection extends StatefulWidget {
  const NotificationSettingsSection({super.key, this.service});
  final PushService? service;

  @override
  State<NotificationSettingsSection> createState() => _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState extends State<NotificationSettingsSection> {
  PushService get _service => widget.service ?? PushService.instance;

  @override
  Widget build(BuildContext context) {
    if (AppModeService.instance.isPrivate) return const SizedBox.shrink();

    final t = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final status = _service.status;
        final disabled = !_service.supported || _service.busy;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(icon: FIcons.bell, title: t.notifications),
            FTileGroup(
              divider: FItemDivider.full,
              children: [
                FTile(
                  prefix: Icon(
                    status == PushStatus.on ? FIcons.bellRing : FIcons.bellOff,
                    color: status == PushStatus.on ? context.theme.colors.primary : null,
                  ),
                  title: Text(t.pushNotifications),
                  subtitle: Text(
                    !_service.supported
                        ? t.pushUnavailable
                        : status == PushStatus.denied
                            ? t.pushDenied
                            : t.pushNotificationsSubtitle,
                  ),
                  suffix: FSwitch(
                    value: status == PushStatus.on,
                    enabled: !disabled,
                    onChange: disabled
                        ? null
                        : (v) => v ? _service.enable() : _service.disable(),
                  ),
                ),
                if (status == PushStatus.on) ...[
                  _PreferenceTile(
                    icon: FIcons.chartColumn,
                    accent: Accent.green,
                    title: t.notifyGrades,
                    value: _service.preferences.grades,
                    onChange: (v) => _service.setPreferences(_service.preferences.rebuild((b) => b..grades = v)),
                  ),
                  _PreferenceTile(
                    icon: FIcons.calendarOff,
                    accent: Accent.red,
                    title: t.notifyAbsences,
                    value: _service.preferences.absences,
                    onChange: (v) => _service.setPreferences(_service.preferences.rebuild((b) => b..absences = v)),
                  ),
                  _PreferenceTile(
                    icon: FIcons.calendarDays,
                    accent: Accent.blue,
                    title: t.notifyAgenda,
                    value: _service.preferences.agenda,
                    onChange: (v) => _service.setPreferences(_service.preferences.rebuild((b) => b..agenda = v)),
                  ),
                  _PreferenceTile(
                    icon: FIcons.eye,
                    accent: Accent.amber,
                    title: t.notifyGradeValue,
                    subtitle: t.notifyGradeValueSubtitle,
                    value: _service.preferences.includeGradeValue,
                    onChange: (v) =>
                        _service.setPreferences(_service.preferences.rebuild((b) => b..includeGradeValue = v)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _PreferenceTile extends StatelessWidget with FTileMixin {
  final IconData icon;
  final Accent accent;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChange;
  const _PreferenceTile({
    required this.icon,
    required this.accent,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) => FTile(
        prefix: Icon(icon, color: value ? context.theme.colors.primary : null),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        suffix: FSwitch(value: value, onChange: onChange),
      );
}
