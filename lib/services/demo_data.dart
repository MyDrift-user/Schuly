import 'package:schuly_api/schuly_api.dart';

import '../domain/student_id.dart';
import 'app_mode_service.dart';
import 'school_data_service.dart';
import 'school_data_snapshot.dart';

/// Sample school data for UI work and screenshots. Enabled with
/// `--dart-define=SCHULY_DEMO=true`; in that build the app skips sign-in and
/// every screen shows this data instead of talking to a backend.
class DemoData {
  DemoData._();

  static const enabled = bool.fromEnvironment('SCHULY_DEMO');
  static const displayName = 'Lara Meier';
  static const schoolName = 'Kantonsschule Zürich Nord';

  static Future<void> install() async {
    if (!enabled) return;
    await AppModeService.instance.setMode(AppMode.private);
    SchoolDataService.instance.seed(snapshot());
  }

  static StudentIdCard studentId(StudentIdCard card) =>
      card.copyWith(programme: 'Informatikerin EFZ - Fachrichtung Plattformentwicklung', validUntil: Date(2027, 7, 31), signerName: 'Rektorat');

  static ClassDto? classDetail(String classId) {
    final svc = SchoolDataService.instance;
    final cls = svc.classes.where((c) => c.id == classId).firstOrNull;
    if (cls == null) return null;
    return cls.rebuild((b) => b
      ..exams.addAll(svc.exams.where((e) => e.classId == classId))
      ..agenda.addAll(svc.agenda.where((a) => a.classId == classId)));
  }

  static const _classes = [
    ('c-math', 'Mathematik', 'BaMa', 'B204'),
    ('c-de', 'Deutsch', 'KeSa', 'A112'),
    ('c-en', 'Englisch', 'RoTh', 'A115'),
    ('c-phy', 'Physik', 'HuPe', 'C301'),
    ('c-hist', 'Geschichte', 'MeAn', 'A210'),
    ('c-sport', 'Sport', 'FiLu', 'Halle 2'),
    ('c-bio', 'Biologie', 'WeCl', 'C210'),
  ];

  static const _teachers = [
    ('BaMa', 'Manuel', 'Bachofner'),
    ('KeSa', 'Sarah', 'Keller'),
    ('RoTh', 'Thomas', 'Roth'),
    ('HuPe', 'Petra', 'Huber'),
    ('MeAn', 'Andreas', 'Meier'),
    ('FiLu', 'Luca', 'Fischer'),
    ('WeCl', 'Claudia', 'Weber'),
  ];

  static SchoolDataSnapshot snapshot() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final me = SchoolUserDto((b) => b
      ..id = 'demo-me'
      ..schoolId = 'demo-school'
      ..schoolName = schoolName
      ..firstName = 'Lara'
      ..lastName = 'Meier'
      ..email = 'lara.meier@stud.ksz.ch'
      ..phoneNumber = '+41 79 123 45 67'
      ..street = 'Birchstrasse 12'
      ..zip = '8050'
      ..city = 'Zürich'
      ..birthday = Date(2008, 4, 17)
      ..role = Roles.student
      ..state = UserState.active
      ..classes.addAll([for (final c in _classes) UserClassDto((u) => u..classId = c.$1..className = c.$2)])
      ..grades.addAll(_grades()));

    return SchoolDataSnapshot(
      me: me,
      exams: _exams(today),
      agenda: _agenda(today),
      absences: _absences(today),
      classes: [for (final c in _classes) ClassDto((b) => b..id = c.$1..name = c.$2..schoolId = 'demo-school')],
      reports: const [],
      teachers: [
        for (final t in _teachers)
          TeacherDto((b) => b
            ..id = 't-${t.$1}'
            ..schoolId = 'demo-school'
            ..code = t.$1
            ..firstName = t.$2
            ..lastName = t.$3
            ..email = '${t.$2.toLowerCase()}.${t.$3.toLowerCase()}@ksz.ch'),
      ],
      documents: [
        StudentDocumentDto((b) => b
          ..id = 'd1'
          ..title = 'Zeugnis 1. Semester 2025/26'
          ..category = 'Zeugnis'
          ..fileName = 'zeugnis-hs25.pdf'
          ..fileSizeBytes = 184320
          ..enteredBy = 'Sekretariat'),
        StudentDocumentDto((b) => b
          ..id = 'd2'
          ..title = 'Zeugnis 2. Semester 2024/25'
          ..category = 'Zeugnis'
          ..fileName = 'zeugnis-fs25.pdf'
          ..fileSizeBytes = 179000
          ..enteredBy = 'Sekretariat'),
        StudentDocumentDto((b) => b
          ..id = 'd3'
          ..title = 'Elternbrief Herbstlager'
          ..category = 'Informationen'
          ..fileName = 'herbstlager.pdf'
          ..fileSizeBytes = 92000
          ..enteredBy = 'A. Meier'),
      ],
    );
  }

  static List<GradeDto> _grades() => [
        for (final e in _examSeed)
          if (e.score != null)
            GradeDto((b) => b
              ..id = 'g-${e.id}'
              ..examId = e.id
              ..score = e.score
              ..weighting = e.weight
              ..schoolUserId = 'demo-me'),
      ];

  static const _examSeed = <({String id, String classId, String name, int y, int m, int d, double? score, double avg, double weight})>[
    (id: 'e1', classId: 'c-math', name: 'Quadratische Funktionen', y: 2025, m: 9, d: 24, score: 5.5, avg: 4.6, weight: 1),
    (id: 'e2', classId: 'c-math', name: 'Trigonometrie', y: 2025, m: 11, d: 12, score: 4.5, avg: 4.3, weight: 1),
    (id: 'e3', classId: 'c-math', name: 'Semesterprüfung', y: 2026, m: 1, d: 15, score: 5, avg: 4.4, weight: 2),
    (id: 'e4', classId: 'c-de', name: 'Aufsatz: Erörterung', y: 2025, m: 10, d: 3, score: 4.5, avg: 4.5, weight: 1),
    (id: 'e5', classId: 'c-de', name: 'Der Besuch der alten Dame', y: 2025, m: 12, d: 9, score: 5.5, avg: 4.8, weight: 1),
    (id: 'e6', classId: 'c-en', name: 'Vocabulary Unit 3', y: 2025, m: 10, d: 17, score: 6, avg: 5.1, weight: 0.5),
    (id: 'e7', classId: 'c-en', name: 'Reading comprehension', y: 2026, m: 1, d: 8, score: 5, avg: 4.7, weight: 1),
    (id: 'e8', classId: 'c-phy', name: 'Kinematik', y: 2025, m: 11, d: 5, score: 3.5, avg: 4.1, weight: 1),
    (id: 'e9', classId: 'c-phy', name: 'Dynamik', y: 2026, m: 1, d: 20, score: 4, avg: 4.2, weight: 1),
    (id: 'e10', classId: 'c-hist', name: 'Französische Revolution', y: 2025, m: 12, d: 2, score: 5, avg: 4.6, weight: 1),
    (id: 'e11', classId: 'c-math', name: 'Vektorgeometrie', y: 2026, m: 3, d: 11, score: 4.5, avg: 4.2, weight: 1),
    (id: 'e12', classId: 'c-de', name: 'Lyrik-Analyse', y: 2026, m: 3, d: 25, score: 5, avg: 4.6, weight: 1),
    (id: 'e13', classId: 'c-en', name: 'Essay: Social media', y: 2026, m: 4, d: 14, score: 5.5, avg: 4.9, weight: 1),
    (id: 'e14', classId: 'c-phy', name: 'Energie und Arbeit', y: 2026, m: 4, d: 29, score: 4.5, avg: 4.3, weight: 1),
    (id: 'e15', classId: 'c-bio', name: 'Zellbiologie', y: 2026, m: 5, d: 6, score: 5.5, avg: 4.8, weight: 1),
    (id: 'e16', classId: 'c-hist', name: 'Industrialisierung', y: 2026, m: 5, d: 20, score: 4, avg: 4.4, weight: 1),
    (id: 'e17', classId: 'c-math', name: 'Wahrscheinlichkeit', y: 2026, m: 6, d: 10, score: 5.5, avg: 4.5, weight: 1),
    (id: 'e18', classId: 'c-math', name: 'Exponentialfunktionen', y: 2026, m: 9, d: 9, score: 5, avg: 4.4, weight: 1),
    (id: 'e19', classId: 'c-en', name: 'Listening test', y: 2026, m: 9, d: 11, score: 5.5, avg: 5.0, weight: 0.5),
    (id: 'e20', classId: 'c-bio', name: 'Genetik', y: 2026, m: 9, d: 30, score: null, avg: 0, weight: 1),
  ];

  static List<ExamDto> _exams(DateTime today) => [
        for (final e in _examSeed)
          ExamDto((b) => b
            ..id = e.id
            ..name = e.name
            ..type = ExamType.classic
            ..date = Date(e.y, e.m, e.d)
            ..classAverage = e.avg
            ..classId = e.classId
            ..schoolId = 'demo-school'),
      ];

  static List<AgendaEntryDto> _agenda(DateTime today) {
    final out = <AgendaEntryDto>[];
    const slots = [(8, 0), (8, 50), (9, 55), (10, 45), (12, 30), (13, 20), (14, 15), (15, 5)];
    var n = 0;
    for (var offset = -7; offset <= 14; offset++) {
      final day = today.add(Duration(days: offset));
      if (day.weekday > 5) continue;
      final count = day.weekday == 3 ? 5 : (day.weekday == 5 ? 6 : 7);
      for (var i = 0; i < count; i++) {
        final c = _classes[(i + day.weekday * 2) % _classes.length];
        final teacher = _teachers.firstWhere((t) => t.$1 == c.$3);
        final start = DateTime(day.year, day.month, day.day, slots[i].$1, slots[i].$2);
        final isTest = offset == 2 && i == 1 || offset == 6 && i == 3;
        out.add(AgendaEntryDto((b) => b
          ..id = 'a${n++}'
          ..entryType = isTest ? AgendaEntryType.test : AgendaEntryType.lesson
          ..title = isTest ? '${c.$2}: Prüfung' : c.$2
          ..description = '${teacher.$3} ${teacher.$2} (${c.$3})'
          ..place = c.$4
          ..date = start
          ..endDate = start.add(const Duration(minutes: 45))
          ..classId = c.$1
          ..schoolId = 'demo-school'));
      }
    }
    final event = today.add(const Duration(days: 4));
    out.add(AgendaEntryDto((b) => b
      ..id = 'a${n++}'
      ..entryType = AgendaEntryType.event
      ..title = 'Berufsinformationstag'
      ..place = 'Aula'
      ..date = DateTime(event.year, event.month, event.day, 16, 0)
      ..endDate = DateTime(event.year, event.month, event.day, 18, 0)
      ..schoolId = 'demo-school'));
    final holiday = today.add(const Duration(days: 19));
    out.add(AgendaEntryDto((b) => b
      ..id = 'a${n++}'
      ..entryType = AgendaEntryType.holiday
      ..title = 'Herbstferien'
      ..date = DateTime(holiday.year, holiday.month, holiday.day)
      ..endDate = holiday.add(const Duration(days: 13))
      ..schoolId = 'demo-school'));
    return out;
  }

  static List<AbsenceDto> _absences(DateTime today) => [
        AbsenceDto((b) => b
          ..id = 'ab1'
          ..reason = 'Grippe'
          ..type = AbsenceType.absence
          ..from = today.subtract(const Duration(days: 12))
          ..until = today.subtract(const Duration(days: 10))
          ..schoolUserId = 'demo-me'
          ..schoolId = 'demo-school'),
        AbsenceDto((b) => b
          ..id = 'ab2'
          ..reason = 'Zug verspätet'
          ..type = AbsenceType.delay
          ..from = today.subtract(const Duration(days: 5))
          ..until = today.subtract(const Duration(days: 5))
          ..schoolUserId = 'demo-me'
          ..schoolId = 'demo-school'),
        AbsenceDto((b) => b
          ..id = 'ab3'
          ..reason = 'Zahnarzt'
          ..type = AbsenceType.absence
          ..from = today.subtract(const Duration(days: 33))
          ..until = today.subtract(const Duration(days: 33))
          ..schoolUserId = 'demo-me'
          ..schoolId = 'demo-school'),
      ];
}
