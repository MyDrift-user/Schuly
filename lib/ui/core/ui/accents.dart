import 'package:flutter/widgets.dart';

/// Semantic accent colours layered on top of the neutral Forui theme. Each
/// accent has a strong foreground and a soft tinted background that reads well
/// on both the light and the dark zinc palette.
enum Accent {
  blue(Color(0xFF3B82F6)),
  violet(Color(0xFF8B5CF6)),
  green(Color(0xFF22C55E)),
  amber(Color(0xFFF59E0B)),
  orange(Color(0xFFF97316)),
  red(Color(0xFFEF4444)),
  teal(Color(0xFF14B8A6)),
  pink(Color(0xFFEC4899)),
  neutral(Color(0xFF71717A));

  const Accent(this.color);

  final Color color;
}

Accent gradeAccent(num grade) {
  if (grade >= 5) return Accent.green;
  if (grade >= 4) return Accent.amber;
  return Accent.red;
}
