import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rounding steps used by Swiss schools. [none] keeps two decimals.
enum Rounding {
  none('Exact', 0),
  tenth('0.1', 0.1),
  quarter('0.25', 0.25),
  half('0.5', 0.5),
  whole('Whole grade', 1);

  const Rounding(this.label, this.step);

  final String label;
  final double step;

  double apply(double value) {
    if (step == 0) return (value * 100).roundToDouble() / 100;
    return (value / step).roundToDouble() * step;
  }
}

enum AverageMethod {
  subjectMean('Mean of subject averages'),
  examWeighted('All exams weighted together');

  const AverageMethod(this.label);

  final String label;
}

/// A set of subjects averaged together, the way Schulnetz groups classes for
/// promotion (e.g. all language classes, or the science block).
class GradeGroup {
  const GradeGroup({required this.id, required this.name, required this.classIds});

  final String id;
  final String name;
  final Set<String> classIds;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'classIds': classIds.toList()};

  static GradeGroup? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'], ids = json['classIds'];
    if (id is! String || name is! String || ids is! List) return null;
    return GradeGroup(id: id, name: name, classIds: {for (final c in ids) if (c is String) c});
  }

  GradeGroup copyWith({String? name, Set<String>? classIds}) => GradeGroup(id: id, name: name ?? this.name, classIds: classIds ?? this.classIds);
}

/// How averages are computed and which summary tiles the grades tab shows.
class GradeSettings extends ChangeNotifier {
  GradeSettings._();
  static final GradeSettings instance = GradeSettings._();

  static const _key = 'settings.grades';
  static const defaultTiles = ['average', 'exams', 'best'];
  static const maxTiles = 6;

  /// Fixed tile keys; group tiles use `group:<id>`.
  static const tileLabels = {
    'average': 'Overall average',
    'exams': 'Exam count',
    'best': 'Best subject',
    'below': 'Subjects below 4',
  };

  AverageMethod _method = AverageMethod.subjectMean;
  Rounding _subjectRounding = Rounding.none;
  Rounding _overallRounding = Rounding.none;
  List<GradeGroup> _groups = const [];
  List<String> _tiles = defaultTiles;

  AverageMethod get method => _method;
  Rounding get subjectRounding => _subjectRounding;
  Rounding get overallRounding => _overallRounding;
  List<GradeGroup> get groups => _groups;
  List<String> get tiles => _tiles;

  bool get isDefault => jsonEncode(toJson()) == jsonEncode(GradeSettings._().toJson());

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
        'method': _method.name,
        'subjectRounding': _subjectRounding.name,
        'overallRounding': _overallRounding.name,
        'groups': [for (final g in _groups) g.toJson()],
        'tiles': _tiles,
      };

  void applyJson(Map<String, dynamic> json) {
    _method = AverageMethod.values.where((v) => v.name == json['method']).firstOrNull ?? AverageMethod.subjectMean;
    _subjectRounding = Rounding.values.where((v) => v.name == json['subjectRounding']).firstOrNull ?? Rounding.none;
    _overallRounding = Rounding.values.where((v) => v.name == json['overallRounding']).firstOrNull ?? Rounding.none;
    _groups = [for (final g in (json['groups'] as List?) ?? const []) ?GradeGroup.fromJson(g)];
    final groupIds = {for (final g in _groups) g.id};
    _tiles = json['tiles'] is List
        ? [
            for (final t in json['tiles'] as List)
              if (t is String && (tileLabels.containsKey(t) || (t.startsWith('group:') && groupIds.contains(t.substring(6))))) t,
          ].take(maxTiles).toList()
        : defaultTiles;
  }

  Future<void> _save() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  Future<void> reset() async {
    applyJson(const {});
    await _save();
  }

  Future<void> setMethod(AverageMethod m) async {
    _method = m;
    await _save();
  }

  Future<void> setSubjectRounding(Rounding r) async {
    _subjectRounding = r;
    await _save();
  }

  Future<void> setOverallRounding(Rounding r) async {
    _overallRounding = r;
    await _save();
  }

  Future<void> setTiles(List<String> tiles) async {
    _tiles = tiles.take(maxTiles).toList();
    await _save();
  }

  Future<void> saveGroup(GradeGroup group) async {
    final i = _groups.indexWhere((g) => g.id == group.id);
    _groups = i < 0 ? [..._groups, group] : [for (final g in _groups) g.id == group.id ? group : g];
    if (i < 0 && _tiles.length < maxTiles) _tiles = [..._tiles, 'group:${group.id}'];
    await _save();
  }

  Future<void> removeGroup(String id) async {
    _groups = [for (final g in _groups) if (g.id != id) g];
    _tiles = [for (final t in _tiles) if (t != 'group:$id') t];
    await _save();
  }
}
