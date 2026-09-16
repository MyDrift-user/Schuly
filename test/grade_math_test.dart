import 'package:flutter_test/flutter_test.dart';
import 'package:schuly/services/grade_settings.dart';
import 'package:schuly/ui/grades/grade_math.dart';
import 'package:schuly_api/schuly_api.dart';

ExamDto _exam(String id, String classId) => ExamDto((b) => b..id = id..name = id..classId = classId..classAverage = 0);
GradeDto _grade(String examId, double score, [double weight = 1]) => GradeDto((b) => b..examId = examId..score = score..weighting = weight);

void main() {
  final byClass = {
    'math': [_exam('m1', 'math'), _exam('m2', 'math')],
    'german': [_exam('d1', 'german')],
  };
  final grades = {'m1': _grade('m1', 4.0), 'm2': _grade('m2', 5.0, 2), 'd1': _grade('d1', 5.5)};

  test('subject average weights exams', () {
    expect(subjectAverage(byClass['math']!, grades), closeTo(4.667, 0.001));
  });

  test('rounding steps round half up', () {
    expect(Rounding.half.apply(4.74), 4.5);
    expect(Rounding.half.apply(4.75), 5.0);
    expect(Rounding.quarter.apply(4.6), 4.5);
    expect(Rounding.tenth.apply(4.667), 4.7);
    expect(Rounding.whole.apply(4.5), 5.0);
    expect(Rounding.none.apply(4.6667), 4.67);
  });

  test('subject-mean rounds each subject before averaging', () {
    final s = GradeSettings.instance..applyJson({'method': 'subjectMean', 'subjectRounding': 'half', 'overallRounding': 'none'});
    // math 4.667 -> 4.5, german 5.5 -> 5.5, mean 5.0
    expect(overallAverage(byClass, grades, s), 5.0);
  });

  test('exam-weighted pools every exam', () {
    final s = GradeSettings.instance..applyJson({'method': 'examWeighted'});
    // (4 + 5*2 + 5.5) / 4 = 4.875
    expect(overallAverage(byClass, grades, s), closeTo(4.88, 0.001));
  });

  test('a group restricts the average to its subjects', () {
    final s = GradeSettings.instance..applyJson({'method': 'subjectMean'});
    expect(overallAverage(byClass, grades, s, classIds: {'german'}), 5.5);
    expect(overallAverage(byClass, grades, s, classIds: {'nothing'}), isNull);
  });

  test('settings json keeps groups and drops tiles of removed groups', () {
    final s = GradeSettings.instance
      ..applyJson({
        'groups': [
          {'id': 'g1', 'name': 'Languages', 'classIds': ['german', 'english']},
        ],
        'tiles': ['average', 'group:g1', 'group:gone', 'bogus'],
      });
    expect(s.groups.single.classIds, {'german', 'english'});
    expect(s.tiles, ['average', 'group:g1']);
  });
}
