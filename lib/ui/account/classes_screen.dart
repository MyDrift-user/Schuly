import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:schuly_api/schuly_api.dart';

import '../../services/school_data_service.dart';
import '../classes/class_detail_screen.dart';
import '../core/ui/chips.dart';
import '../core/ui/empty_state.dart';

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final classes = (SchoolDataService.instance.me?.classes ?? const <UserClassDto>[]).toList()
      ..sort((a, b) => a.className.compareTo(b.className));
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Classes'),
        prefixes: [FHeaderAction.back(onPress: () => Navigator.of(context).pop())],
      ),
      childPad: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          if (classes.isEmpty)
            const EmptyState(icon: FIcons.bookOpen, title: 'No classes', message: 'Your classes appear here once the school has assigned them.')
          else
            FTileGroup(
              divider: FItemDivider.full,
              children: [
                for (final c in classes)
                  FTile(
                    prefix: SubjectChip(c.className),
                    title: Text(c.className),
                    suffix: const Icon(FIcons.chevronRight),
                    onPress: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClassDetailScreen(classId: c.classId, title: c.className))),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
