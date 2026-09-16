import 'package:schuly_api/schuly_api.dart';

/// What the student ID card shows. Today it is assembled from the profile;
/// once Schulnetz's ID page is wired up, [number], [validUntil] and the photo
/// come from there instead.
class StudentIdCard {
  const StudentIdCard({required this.fullName, required this.schoolName, this.className, this.birthday, this.number, this.validUntil, this.photoUrl});

  final String fullName;
  final String schoolName;
  final String? className;
  final Date? birthday;
  final String? number;
  final Date? validUntil;
  final String? photoUrl;

  factory StudentIdCard.fromProfile(SchoolUserDto me, {String? schoolName, String? photoUrl}) {
    final classes = me.classes?.map((c) => c.className).where((n) => n.isNotEmpty).toList() ?? const [];
    return StudentIdCard(
      fullName: '${me.firstName} ${me.lastName}'.trim(),
      schoolName: schoolName ?? me.schoolName ?? '',
      className: classes.isEmpty ? null : classes.join(', '),
      birthday: me.birthday,
      photoUrl: photoUrl,
    );
  }
}
