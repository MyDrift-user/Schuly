import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../domain/student_id.dart';
import '../core/dates.dart';

/// The ID laid out like a physical card so it can be shown at the door.
class StudentIdCardView extends StatelessWidget {
  const StudentIdCardView({super.key, required this.card});

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

    return Column(
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

/// Draws the profile tile growing into the full card, on top of everything,
/// driven by [animation] (0 = tile in place, 1 = card open). The tile content
/// dissolves into the card content while the frame grows.
class StudentIdOverlay extends StatelessWidget {
  const StudentIdOverlay({super.key, required this.animation, required this.from, required this.tile, required this.card, required this.onClose, required this.onDragUpdate, required this.onDragEnd});

  final Animation<double> animation;
  final Rect from;
  final Widget tile;
  final StudentIdCard card;
  final VoidCallback onClose;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final padding = MediaQuery.viewPaddingOf(context);
    final size = MediaQuery.sizeOf(context);

    final top = padding.top + 64.0;
    final bottom = padding.bottom + 72.0;
    final maxW = size.width - 48;
    final maxH = size.height - top - bottom;
    var cardW = maxW, cardH = cardW * 1.586;
    if (cardH > maxH) {
      cardH = maxH;
      cardW = cardH / 1.586;
    }
    final to = Rect.fromCenter(center: Offset(size.width / 2, top + maxH / 2), width: cardW, height: cardH);

    Widget fixed(Widget child, Size s) => OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: s.width,
          maxHeight: s.height,
          child: SizedBox(width: s.width, height: s.height, child: child),
        );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(animation.value);
        final rect = Rect.lerp(from, to, t)!;
        return Stack(
          children: [
            Positioned.fill(child: IgnorePointer(ignoring: t == 0, child: Opacity(opacity: t, child: ColoredBox(color: colors.background)))),
            Positioned(
              left: 0,
              right: 0,
              top: padding.top,
              child: IgnorePointer(
                ignoring: t < 0.5,
                child: Opacity(
                  opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
                  child: SizedBox(
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text('Student ID', style: typography.xl.copyWith(fontWeight: FontWeight.w700)),
                        Positioned(left: 8, child: FButton.icon(style: FButtonStyle.ghost(), onPress: onClose, child: const Icon(FIcons.chevronDown))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: padding.bottom + 20,
              child: IgnorePointer(
                child: Opacity(
                  opacity: ((t - 0.6) * 2.5).clamp(0.0, 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      card.number == null ? 'The student number and validity appear once the school connection provides them.' : 'Show this card at the entrance or the library.',
                      textAlign: TextAlign.center,
                      style: typography.xs.copyWith(color: colors.mutedForeground),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: GestureDetector(
                onVerticalDragUpdate: (d) => onDragUpdate(d.delta.dy),
                onVerticalDragEnd: (d) => onDragEnd(d.primaryVelocity ?? 0),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: colors.background,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.lerp(context.theme.style.borderRadius, BorderRadius.circular(20), t),
                    boxShadow: [BoxShadow(color: colors.foreground.withValues(alpha: 0.08 * t), blurRadius: 24 * t, offset: Offset(0, 12 * t))],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(opacity: 1 - t, child: fixed(tile, from.size)),
                      Opacity(opacity: t, child: fixed(StudentIdCardView(card: card), to.size)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
