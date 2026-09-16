import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:schuly/domain/student_id.dart';

// One transparent pixel; the real page embeds JPEG/PNG data URIs the same way.
final _pixel = base64Encode([137, 80, 78, 71, 13, 10, 26, 10]);

String _page() => '''
<div class="EAcontent" id="EAcontent">
  <img src="data:image/jpg;base64,$_pixel" style="border-radius: 25% 10%; width: 16vh;">
  <p style="color: #566D92; font-size: 3vh;">
      Lernendenausweis        </p>
  <hr class="EAhorizontallinie">
  <p class="EAueberschrift">
      Berufsschule
  </p>
  <p class="EAinhalt">
      Berufsfachschule Musterstadt
  </p>
  <hr class="EAhorizontallinie">
  <div style="display: flex;">
    <div><p class="EAueberschrift">Nachname</p><p class="EAinhalt">Muster</p></div>
    <div><p class="EAueberschrift">Vorname</p><p class="EAinhalt">Lea</p></div>
  </div>
  <p class="EAueberschrift">Geburtsdatum</p>
  <p class="EAinhalt">17.05.2007        </p>
  <p class="EAueberschrift">
      Ausbildung            </p>
  <p class="EAinhalt">
      Informatikerin EFZ - Fachrichtung Plattformentwicklung            </p>
  <p class="EAueberschrift">Gültig bis</p>
  <p class="EAinhalt">31.07.2027</p>
  <p class="EAueberschrift">Mensa</p>
  <p class="EAinhalt">Ja</p>
  <p class="EAueberschrift">
      Hanna Beispiel, Rektorin        </p>
  <img src="data:image/png;base64,$_pixel" style="width: 9vh;">
  <hr class="EAhorizontallinie">
  <div style="display: flex;">
    <img src="data:image/png;base64,$_pixel" style="height: 10vh;" alt="Left Image">
    <img src="data:image/png;base64,$_pixel" style="height: 10vh;" alt="Right Image">
  </div>
</div>
''';

void main() {
  test('parses every field of the Schulnetz ID page', () {
    final card = StudentIdCard.fromHtml(_page())!;
    expect(card.title, 'Lernendenausweis');
    expect(card.schoolLabel, 'Berufsschule');
    expect(card.schoolName, 'Berufsfachschule Musterstadt');
    expect(card.lastName, 'Muster');
    expect(card.firstName, 'Lea');
    expect(card.fullName, 'Lea Muster');
    expect((card.birthday!.year, card.birthday!.month, card.birthday!.day), (2007, 5, 17));
    expect(card.programme, 'Informatikerin EFZ - Fachrichtung Plattformentwicklung');
    expect((card.validUntil!.year, card.validUntil!.month, card.validUntil!.day), (2027, 7, 31));
    expect(card.signerName, 'Hanna Beispiel, Rektorin');
    expect(card.photo, isNotNull);
    expect(card.signature, isNotNull);
    expect(card.logos.length, 2);
  });

  test('keeps unknown lines as extras', () {
    final card = StudentIdCard.fromHtml(_page())!;
    expect(card.extras, [('Mensa', 'Ja')]);
  });

  test('returns null for a page without content', () {
    expect(StudentIdCard.fromHtml('<div></div>'), isNull);
  });
}
