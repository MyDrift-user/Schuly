import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../domain/student_id.dart';
import '../core/dates.dart';

/// Cross-fades the profile tile's content into the card's content while the
/// hero rectangle grows, so the tile looks like it expands rather than being
/// replaced.
Widget studentIdShuttle(BuildContext context, Animation<double> animation, HeroFlightDirection direction, BuildContext fromContext, BuildContext toContext) {
  final from = (fromContext.widget as Hero).child;
  final to = (toContext.widget as Hero).child;
  final colors = context.theme.colors;
  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = Curves.easeInOut.transform(direction == HeroFlightDirection.push ? animation.value : 1 - animation.value);
      return ClipRRect(
        borderRadius: BorderRadius.lerp(BorderRadius.circular(8), BorderRadius.circular(20), t)!,
        child: ColoredBox(
          color: colors.background,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(opacity: (1 - t * 2).clamp(0.0, 1.0), child: OverflowBox(alignment: Alignment.topLeft, maxWidth: double.infinity, maxHeight: double.infinity, child: from)),
              Opacity(opacity: ((t - 0.4) / 0.6).clamp(0.0, 1.0), child: OverflowBox(alignment: Alignment.topLeft, maxWidth: double.infinity, maxHeight: double.infinity, child: to)),
            ],
          ),
        ),
      );
    },
  );
}

/// Full-screen student ID, laid out like a physical card so it can be shown
/// at the door. Opens from the profile card on the account tab.
class StudentIdScreen extends StatefulWidget {
  const StudentIdScreen({super.key, required this.card});

  final StudentIdCard card;

  @override
  State<StudentIdScreen> createState() => _StudentIdScreenState();
}

class _StudentIdScreenState extends State<StudentIdScreen> {
  @override
  void initState() {
    super.initState();
    // A card shown to someone else should stay upright and readable.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final card = widget.card;

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Student ID'),
        prefixes: [FHeaderAction(icon: const Icon(FIcons.chevronDown), onPress: () => Navigator.of(context).pop())],
      ),
      childPad: false,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: AspectRatio(aspectRatio: 1 / 1.586, child: Hero(tag: 'student-id-card', flightShuttleBuilder: studentIdShuttle, child: _Card(card: card))),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + MediaQuery.viewPaddingOf(context).bottom),
            child: Text(
              card.number == null ? 'The student number and validity appear once the school connection provides them.' : 'Show this card at the entrance or the library.',
              textAlign: TextAlign.center,
              style: typography.xs.copyWith(color: colors.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.card});

  final StudentIdCard card;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final initial = card.fullName.isNotEmpty ? card.fullName.characters.first.toUpperCase() : '?';
    final photoUrl = card.photoUrl;

    Widget field(String label, String? value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: typography.xs.copyWith(color: colors.mutedForeground, fontSize: 10, letterSpacing: 0.6, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value?.isNotEmpty == true ? value! : '-', style: typography.sm.copyWith(fontWeight: FontWeight.w600)),
          ],
        );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors.foreground.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: colors.primary,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Row(
              children: [
                Icon(FIcons.graduationCap, size: 22, color: colors.primaryForeground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(card.schoolName.isEmpty ? 'School' : card.schoolName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.base.copyWith(color: colors.primaryForeground, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 96,
                        height: 120,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(color: colors.muted, borderRadius: BorderRadius.circular(10), border: Border.all(color: colors.border)),
                        child: photoUrl == null || photoUrl.isEmpty
                            ? Center(child: Text(initial, style: typography.xl3.copyWith(color: colors.mutedForeground, fontWeight: FontWeight.w700)))
                            : Image.network(photoUrl, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(card.fullName, style: typography.lg.copyWith(fontWeight: FontWeight.w800, height: 1.1)),
                            const SizedBox(height: 12),
                            field('Class', card.className),
                            const SizedBox(height: 10),
                            field('Date of birth', card.birthday == null ? null : formatDate(fromApiDate(card.birthday!))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: field('Student number', card.number)),
                      const SizedBox(width: 12),
                      Expanded(child: field('Valid until', card.validUntil == null ? null : formatDate(fromApiDate(card.validUntil!)))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 56,
                    child: CustomPaint(painter: _BarcodePainter(seed: card.number ?? card.fullName, color: card.number == null ? colors.border : colors.foreground)),
                  ),
                  if (card.number != null) ...[
                    const SizedBox(height: 4),
                    Center(child: Text(card.number!, style: typography.xs.copyWith(letterSpacing: 2, fontFeatures: const [FontFeature.tabularFigures()]))),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bars derived from the number so the card looks complete; replaced by the
/// real code once the school connection provides one.
class _BarcodePainter extends CustomPainter {
  const _BarcodePainter({required this.seed, required this.color});

  final String seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    var h = 7;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    const bars = 60;
    final unit = size.width / (bars * 1.5);
    var x = 0.0;
    for (var i = 0; i < bars; i++) {
      h = (h * 1103515245 + 12345) & 0x7fffffff;
      final w = unit * (1 + (h >> 4) % 3);
      if (i.isEven) canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w;
      if (x >= size.width) break;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.seed != seed || old.color != color;
}
