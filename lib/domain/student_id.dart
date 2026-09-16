import 'dart:convert';
import 'dart:typed_data';

import 'package:schuly_api/schuly_api.dart';

/// The Schulnetz "Lernendenausweis": photo, school, name, date of birth,
/// programme, validity, the rector's signature and the school logos.
class StudentIdCard {
  const StudentIdCard({
    required this.title,
    required this.schoolLabel,
    required this.schoolName,
    required this.lastName,
    required this.firstName,
    this.birthday,
    this.programme,
    this.validUntil,
    this.signerName,
    this.photo,
    this.photoUrl,
    this.signature,
    this.logos = const [],
    this.extras = const [],
  });

  final String title;
  final String schoolLabel;
  final String schoolName;
  final String lastName;
  final String firstName;
  final Date? birthday;
  final String? programme;
  final Date? validUntil;
  final String? signerName;
  final Uint8List? photo;
  final String? photoUrl;
  final Uint8List? signature;
  final List<Uint8List> logos;

  /// Label and value pairs the parser did not recognise, shown as they are so
  /// a school that adds a line still gets it on the card.
  final List<(String, String)> extras;

  String get fullName => '$firstName $lastName'.trim();

  /// Filled from the profile while the Schulnetz ID page is not wired up yet.
  factory StudentIdCard.fromProfile(SchoolUserDto me, {String? schoolName, String? photoUrl}) => StudentIdCard(
        title: 'Student ID',
        schoolLabel: 'School',
        schoolName: schoolName ?? me.schoolName ?? '',
        lastName: me.lastName,
        firstName: me.firstName,
        birthday: me.birthday,
        photoUrl: photoUrl,
      );

  StudentIdCard copyWith({String? programme, Date? validUntil, String? signerName}) => StudentIdCard(
        title: title,
        schoolLabel: schoolLabel,
        schoolName: schoolName,
        lastName: lastName,
        firstName: firstName,
        birthday: birthday,
        programme: programme ?? this.programme,
        validUntil: validUntil ?? this.validUntil,
        signerName: signerName ?? this.signerName,
        photo: photo,
        photoUrl: photoUrl,
        signature: signature,
        logos: logos,
        extras: extras,
      );

  /// Parses the `EAcontent` block of the Schulnetz ID page.
  static StudentIdCard? fromHtml(String html) {
    final images = [for (final m in _img.allMatches(html)) m];
    if (images.isEmpty) return null;

    final fields = <String, String>{};
    final extras = <(String, String)>[];
    final order = <String>[];
    for (final m in _pair.allMatches(html)) {
      final label = _text(m.group(1)!);
      final value = _text(m.group(2)!);
      fields[label] = value;
      order.add(label);
    }
    String? take(List<String> labels) {
      for (final l in labels) {
        final v = fields.remove(l);
        if (v != null) return v;
      }
      return null;
    }

    final schoolLabel = order.firstWhere((l) => _schoolLabels.contains(l), orElse: () => 'Schule');
    final schoolName = take(_schoolLabels) ?? '';
    final lastName = take(['Nachname', 'Name']) ?? '';
    final firstName = take(['Vorname']) ?? '';
    final birthday = _date(take(['Geburtsdatum']));
    final programme = take(['Ausbildung', 'Beruf', 'Lehrgang']);
    final validUntil = _date(take(['Gültig bis', 'Gueltig bis']));
    for (final e in fields.entries) {
      extras.add((e.key, e.value));
    }

    final titleMatch = _title.firstMatch(html);
    final signer = _signer.firstMatch(html);

    Uint8List? decode(RegExpMatch? m) => m == null ? null : _decodeDataUri(m.group(1)!);
    final logos = [for (final m in _logo.allMatches(html)) ?_decodeDataUri(m.group(1)!)];
    final signatureMatch = signer == null ? null : _img.firstMatch(html.substring(signer.end));

    return StudentIdCard(
      title: titleMatch == null ? 'Lernendenausweis' : _text(titleMatch.group(1)!),
      schoolLabel: schoolLabel,
      schoolName: schoolName,
      lastName: lastName,
      firstName: firstName,
      birthday: birthday,
      programme: programme,
      validUntil: validUntil,
      signerName: signer == null ? null : _text(signer.group(1)!),
      photo: decode(images.first),
      signature: decode(signatureMatch),
      logos: logos,
      extras: extras,
    );
  }

  static const _schoolLabels = ['Berufsschule', 'Schule', 'Kantonsschule', 'Gymnasium'];
  static final _img = RegExp(r'<img[^>]+src="(data:image/[^"]+)"', caseSensitive: false);
  static final _pair = RegExp(r'<p class="EAueberschrift">\s*(.*?)\s*</p>\s*<p class="EAinhalt">\s*(.*?)\s*</p>', dotAll: true);
  static final _title = RegExp(r'<p style="color:[^"]*">\s*(.*?)\s*</p>', dotAll: true);
  static final _signer = RegExp(r'<p class="EAueberschrift">\s*([^<]*?)\s*</p>\s*<img', dotAll: true);
  static final _logo = RegExp(r'<img[^>]+src="(data:image/[^"]+)"[^>]*alt="(?:Left|Right) Image"', caseSensitive: false);

  static String _text(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  static Date? _date(String? s) {
    if (s == null) return null;
    final m = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(s);
    if (m == null) return null;
    return Date(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
  }

  static Uint8List? _decodeDataUri(String uri) {
    final comma = uri.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(uri.substring(comma + 1).replaceAll(RegExp(r'\s'), ''));
    } catch (_) {
      return null;
    }
  }
}
