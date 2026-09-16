import 'package:flutter_test/flutter_test.dart';
import 'package:schuly/services/layout_prefs.dart';

void main() {
  test('defaults keep every home section in order and visible', () {
    final p = LayoutPrefs.instance;
    p.applyJson(const {});
    expect(p.homeOrder, HomeSection.values);
    expect(p.homeHidden, isEmpty);
    expect(p.timeColumn, TimeColumnSide.left);
    expect(p.dayStrip, DayStripPosition.top);
  });

  test('json round trip keeps order, hidden set and options', () {
    final p = LayoutPrefs.instance;
    p.applyJson({
      'homeOrder': ['grades', 'hero', 'tiles'],
      'homeHidden': ['holiday'],
      'homeTiles': ['documents', 'average'],
      'timeColumn': 'right',
      'dayStrip': 'bottom',
      'absencesTiles': true,
    });
    expect(p.homeOrder.take(3), [HomeSection.grades, HomeSection.hero, HomeSection.tiles]);
    expect(p.homeOrder.length, HomeSection.values.length);
    expect(p.homeHidden, {HomeSection.holiday});
    expect(p.homeTiles, [HomeTile.documents, HomeTile.average]);
    expect(p.timeColumn, TimeColumnSide.right);
    expect(p.dayStrip, DayStripPosition.bottom);
    final copy = LayoutPrefs.instance..applyJson(p.toJson());
    expect(copy.toJson(), p.toJson());
  });

  test('unknown names are ignored and tiles are capped at three', () {
    final p = LayoutPrefs.instance;
    p.applyJson({
      'homeOrder': ['bogus', 'today'],
      'homeHidden': ['bogus'],
      'homeTiles': ['average', 'absences', 'holiday', 'tests'],
      'timeColumn': 'middle',
    });
    expect(p.homeOrder.first, HomeSection.today);
    expect(p.homeHidden, isEmpty);
    expect(p.homeTiles.length, 3);
    expect(p.timeColumn, TimeColumnSide.left);
  });
}
