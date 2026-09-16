import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HomeSection {
  hero('Now / up next'),
  tiles('Summary tiles'),
  today('Today'),
  tests('Upcoming tests'),
  grades('Latest grades'),
  holiday('Next holiday'),
  absences('Recent absences');

  const HomeSection(this.label);

  final String label;
}

enum HomeTile {
  average('Average grade'),
  absences('Absences'),
  holiday('Days to holiday'),
  tests('Upcoming tests'),
  lessons('Lessons today'),
  documents('Documents'),
  authenticator('Authenticator');

  const HomeTile(this.label);

  final String label;
}

enum TimeColumnSide {
  left('Left'),
  right('Right');

  const TimeColumnSide(this.label);

  final String label;
}

enum DayStripPosition {
  top('Above the title'),
  belowTitle('Below the title'),
  bottom('Bottom, above the tabs');

  const DayStripPosition(this.label);

  final String label;
}

/// Per-page layout choices: section order and visibility on the home page,
/// which summary tiles to show, and a few options on the other tabs.
class LayoutPrefs extends ChangeNotifier {
  LayoutPrefs._();
  static final LayoutPrefs instance = LayoutPrefs._();

  static const _key = 'settings.layout';
  static const defaultTiles = [HomeTile.average, HomeTile.absences, HomeTile.holiday];

  List<HomeSection> _homeOrder = HomeSection.values;
  Set<HomeSection> _homeHidden = const {};
  List<HomeTile> _homeTiles = defaultTiles;
  TimeColumnSide _timeColumn = TimeColumnSide.left;
  DayStripPosition _dayStrip = DayStripPosition.top;
  bool _absencesTiles = true;

  List<HomeSection> get homeOrder => _homeOrder;
  Set<HomeSection> get homeHidden => _homeHidden;
  List<HomeTile> get homeTiles => _homeTiles;
  TimeColumnSide get timeColumn => _timeColumn;
  DayStripPosition get dayStrip => _dayStrip;
  bool get absencesTiles => _absencesTiles;

  bool get isDefault => jsonEncode(toJson()) == jsonEncode(LayoutPrefs._().toJson());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        applyJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // A corrupt or outdated blob falls back to the defaults.
      }
    }
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'homeOrder': [for (final s in _homeOrder) s.name],
        'homeHidden': [for (final s in _homeHidden) s.name],
        'homeTiles': [for (final t in _homeTiles) t.name],
        'timeColumn': _timeColumn.name,
        'dayStrip': _dayStrip.name,
        'absencesTiles': _absencesTiles,
      };

  /// Unknown names are dropped and sections missing from a stored order are
  /// appended, so an older blob keeps working after sections are added.
  void applyJson(Map<String, dynamic> json) {
    final order = <HomeSection>[];
    for (final name in (json['homeOrder'] as List?) ?? const []) {
      final s = HomeSection.values.where((v) => v.name == name).firstOrNull;
      if (s != null && !order.contains(s)) order.add(s);
    }
    for (final s in HomeSection.values) {
      if (!order.contains(s)) order.add(s);
    }
    _homeOrder = order;
    _homeHidden = {
      for (final name in (json['homeHidden'] as List?) ?? const [])
        ...HomeSection.values.where((v) => v.name == name),
    };
    if (json['homeTiles'] is List) {
      _homeTiles = [
        for (final name in json['homeTiles'] as List) ...HomeTile.values.where((v) => v.name == name),
      ].take(3).toList();
    }
    _timeColumn = TimeColumnSide.values.where((v) => v.name == json['timeColumn']).firstOrNull ?? TimeColumnSide.left;
    _dayStrip = DayStripPosition.values.where((v) => v.name == json['dayStrip']).firstOrNull ?? DayStripPosition.top;
    _absencesTiles = json['absencesTiles'] as bool? ?? true;
  }

  Future<void> _save() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  Future<void> reset() async {
    applyJson(const {});
    _homeTiles = defaultTiles;
    await _save();
  }

  Future<void> moveHomeSection(HomeSection section, int delta) async {
    final order = List.of(_homeOrder);
    final i = order.indexOf(section);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= order.length) return;
    order.removeAt(i);
    order.insert(j, section);
    _homeOrder = order;
    await _save();
  }

  Future<void> setHomeSectionVisible(HomeSection section, bool visible) async {
    _homeHidden = visible ? (Set.of(_homeHidden)..remove(section)) : {..._homeHidden, section};
    await _save();
  }

  Future<void> setHomeTiles(List<HomeTile> tiles) async {
    _homeTiles = tiles.take(3).toList();
    await _save();
  }

  Future<void> setTimeColumn(TimeColumnSide side) async {
    _timeColumn = side;
    await _save();
  }

  Future<void> setDayStrip(DayStripPosition position) async {
    _dayStrip = position;
    await _save();
  }

  Future<void> setAbsencesTiles(bool show) async {
    _absencesTiles = show;
    await _save();
  }
}
