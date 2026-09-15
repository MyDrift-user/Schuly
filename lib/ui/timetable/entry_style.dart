import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:schuly_api/schuly_api.dart';

import '../../l10n/app_localizations.dart';
import '../core/ui/accents.dart';

({String label, IconData icon, Accent accent}) entryStyle(BuildContext context, AgendaEntryType type) {
  final t = AppLocalizations.of(context)!;
  switch (type) {
    case AgendaEntryType.test:
      return (label: t.entryTypeTest, icon: FIcons.clipboardList, accent: Accent.violet);
    case AgendaEntryType.event:
      return (label: t.entryTypeEvent, icon: FIcons.calendarHeart, accent: Accent.pink);
    case AgendaEntryType.holiday:
      return (label: t.entryTypeHoliday, icon: FIcons.treePalm, accent: Accent.orange);
    case AgendaEntryType.lesson:
    default:
      return (label: t.entryTypeLesson, icon: FIcons.bookOpen, accent: Accent.blue);
  }
}
