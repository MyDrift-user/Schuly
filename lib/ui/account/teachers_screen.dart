import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/school_data_service.dart';
import '../core/ui/empty_state.dart';

class TeachersScreen extends StatelessWidget {
  const TeachersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final teachers = SchoolDataService.instance.teachers.toList()..sort((a, b) => a.lastName.compareTo(b.lastName));
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Teachers'),
        prefixes: [FHeaderAction.back(onPress: () => Navigator.of(context).pop())],
      ),
      childPad: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          if (teachers.isEmpty)
            const EmptyState(icon: FIcons.graduationCap, title: 'No teachers', message: 'Teachers appear here once the school data has synced.')
          else
            FTileGroup(
              divider: FItemDivider.full,
              children: [
                for (final t in teachers)
                  FTile(
                    prefix: _Initials(name: '${t.firstName} ${t.lastName}'),
                    title: Text('${t.lastName} ${t.firstName}'.trim()),
                    subtitle: t.code.isNotEmpty ? Text(t.code) : null,
                    suffix: (t.email?.isNotEmpty ?? false) ? Icon(FIcons.mail, color: colors.mutedForeground) : null,
                    onPress: (t.email?.isNotEmpty ?? false) ? () => launchUrl(Uri(scheme: 'mailto', path: t.email)) : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
    return FAvatar.raw(size: 38, child: Text(initials.isEmpty ? '?' : initials, style: TextStyle(color: colors.mutedForeground, fontWeight: FontWeight.w700, fontSize: 13)));
  }
}
