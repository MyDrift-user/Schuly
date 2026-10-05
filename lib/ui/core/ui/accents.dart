import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Semantic accent colours layered on top of the neutral Forui theme. The
/// bright values only pass contrast on the dark palette; on light they are
/// used as 14 px text, so each accent has a darker light-mode variant that
/// clears 4.5:1 on white.
enum Accent {
  blue(Color(0xFF3B82F6), Color(0xFF1D4ED8)),
  violet(Color(0xFF8B5CF6), Color(0xFF6D28D9)),
  green(Color(0xFF22C55E), Color(0xFF15803D)),
  amber(Color(0xFFF59E0B), Color(0xFFB45309)),
  orange(Color(0xFFF97316), Color(0xFFC2410C)),
  red(Color(0xFFEF4444), Color(0xFFB91C1C)),
  teal(Color(0xFF14B8A6), Color(0xFF0F766E)),
  pink(Color(0xFFEC4899), Color(0xFFBE185D)),
  neutral(Color(0xFF71717A), Color(0xFF52525B));

  const Accent(this.dark, this.light);

  final Color dark;
  final Color light;

  /// The variant for the current theme brightness.
  Color of(BuildContext context) => context.theme.colors.brightness == Brightness.dark ? dark : light;
}

Accent gradeAccent(num grade) {
  if (grade >= 5) return Accent.green;
  if (grade >= 4) return Accent.amber;
  return Accent.red;
}
