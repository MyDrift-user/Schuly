import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../domain/student_id.dart';
import '../core/dates.dart';

/// The ID laid out like a physical card so it can be shown at the door.
class StudentIdCardView extends StatelessWidget {
  const StudentIdCardView({super.key, required this.card, this.photoKey, this.nameKey, this.hideShared = false});

  final StudentIdCard card;

  /// Keys on the photo and the name so the expansion can fly them in from the
  /// profile tile; [hideShared] blanks them while they are in flight.
  final Key? photoKey;
  final Key? nameKey;
  final bool hideShared;

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
                    Opacity(
                      opacity: hideShared ? 0 : 1,
                      child: StudentIdPhoto(key: photoKey, initial: initial, photoUrl: photoUrl, width: 96, height: 120, radius: 10),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Opacity(opacity: hideShared ? 0 : 1, child: Text(card.fullName, key: nameKey, style: typography.lg.copyWith(fontWeight: FontWeight.w800, height: 1.1))),
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

/// The photo slot, shared between the tile's avatar and the card, so the same
/// widget can be drawn at any size in between.
class StudentIdPhoto extends StatelessWidget {
  const StudentIdPhoto({super.key, required this.initial, required this.photoUrl, required this.width, required this.height, required this.radius, this.fontSize = 34});

  final String initial;
  final String? photoUrl;
  final double width;
  final double height;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: colors.muted, borderRadius: BorderRadius.circular(radius), border: Border.all(color: colors.border)),
      child: photoUrl == null || photoUrl!.isEmpty
          ? Center(child: Text(initial, style: typography.xl3.copyWith(fontSize: fontSize, color: colors.mutedForeground, fontWeight: FontWeight.w700)))
          : Image.network(photoUrl!, fit: BoxFit.cover),
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

/// Where the shared pieces of the profile tile sit, in global coordinates,
/// captured when the expansion starts.
class TileGeometry {
  const TileGeometry({required this.tile, required this.avatar, required this.name});

  final Rect tile;
  final Rect avatar;
  final Rect name;
}

/// The profile tile growing into the full card, on top of everything, driven
/// by [animation] (0 = tile in place, 1 = card open).
///
/// Follows Material's container transform: both contents are laid out at their
/// own final size and scaled with the container, the tile content fades out in
/// the first fifth of the flight, the card content fades in over the rest, and
/// the avatar and the name fly from their tile positions into the card.
class StudentIdOverlay extends StatefulWidget {
  const StudentIdOverlay({super.key, required this.animation, required this.from, required this.tileBuilder, required this.card, required this.initial, required this.onClose, required this.onDragUpdate, required this.onDragEnd});

  final Animation<double> animation;
  final TileGeometry from;
  final Widget Function(bool hideShared) tileBuilder;
  final StudentIdCard card;
  final String initial;
  final VoidCallback onClose;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  @override
  State<StudentIdOverlay> createState() => _StudentIdOverlayState();
}

class _StudentIdOverlayState extends State<StudentIdOverlay> {
  final _measureKey = GlobalKey();
  final _photoKey = GlobalKey();
  final _nameKey = GlobalKey();
  Rect? _photoInCard;
  Rect? _nameInCard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  // The card's own layout decides where the photo and the name end up; an
  // offstage copy at the final size is measured once instead of hard-coding it.
  void _measure() {
    final card = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    final photo = _photoKey.currentContext?.findRenderObject() as RenderBox?;
    final name = _nameKey.currentContext?.findRenderObject() as RenderBox?;
    if (card == null || photo == null || name == null || !mounted) return;
    setState(() {
      _photoInCard = photo.localToGlobal(Offset.zero, ancestor: card) & photo.size;
      _nameInCard = name.localToGlobal(Offset.zero, ancestor: card) & name.size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final padding = MediaQuery.viewPaddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final from = widget.from.tile;

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

    Widget scaled(Widget child, Size s) => FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topLeft,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(width: s.width, height: s.height, child: child),
        );

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final v = widget.animation.value;
        final t = Curves.fastOutSlowIn.transform(v);
        final rect = Rect.lerp(from, to, t)!;
        final flying = v > 0 && v < 1 && _photoInCard != null && _nameInCard != null;
        final tileOpacity = (1 - v / 0.2).clamp(0.0, 1.0);
        final cardOpacity = ((v - 0.2) / 0.8).clamp(0.0, 1.0);
        final photoRect = flying ? Rect.lerp(widget.from.avatar, _photoInCard!.shift(to.topLeft), t)! : null;
        final nameRect = flying ? Rect.lerp(widget.from.name, _nameInCard!.shift(to.topLeft), t)! : null;

        return Stack(
          children: [
            Positioned.fill(child: IgnorePointer(ignoring: v == 0, child: Opacity(opacity: t, child: ColoredBox(color: colors.background)))),
            Offstage(
              child: SizedBox(
                width: to.width,
                height: to.height,
                child: StudentIdCardView(key: _measureKey, card: widget.card, photoKey: _photoKey, nameKey: _nameKey),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: padding.top,
              child: IgnorePointer(
                ignoring: v < 0.5,
                child: Opacity(
                  opacity: ((v - 0.5) * 2).clamp(0.0, 1.0),
                  child: SizedBox(
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text('Student ID', style: typography.xl.copyWith(fontWeight: FontWeight.w700)),
                        Positioned(left: 8, child: FButton.icon(style: FButtonStyle.ghost(), onPress: widget.onClose, child: const Icon(FIcons.chevronDown))),
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
                  opacity: ((v - 0.6) * 2.5).clamp(0.0, 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      widget.card.number == null ? 'The student number and validity appear once the school connection provides them.' : 'Show this card at the entrance or the library.',
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
                onVerticalDragUpdate: (d) => widget.onDragUpdate(d.delta.dy),
                onVerticalDragEnd: (d) => widget.onDragEnd(d.primaryVelocity ?? 0),
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
                      if (tileOpacity > 0) Opacity(opacity: tileOpacity, child: scaled(widget.tileBuilder(flying), from.size)),
                      if (cardOpacity > 0) Opacity(opacity: cardOpacity, child: scaled(StudentIdCardView(card: widget.card, hideShared: flying), to.size)),
                    ],
                  ),
                ),
              ),
            ),
            if (photoRect != null)
              Positioned.fromRect(
                rect: photoRect,
                child: IgnorePointer(
                  child: StudentIdPhoto(
                    initial: widget.initial,
                    photoUrl: widget.card.photoUrl,
                    width: photoRect.width,
                    height: photoRect.height,
                    radius: lerpDouble(32, 10, t)!,
                    fontSize: lerpDouble(20, 34, t)!,
                  ),
                ),
              ),
            if (nameRect != null)
              Positioned.fromRect(
                rect: nameRect,
                child: IgnorePointer(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(widget.card.fullName, maxLines: 1, style: typography.lg.copyWith(fontWeight: FontWeight.w800, height: 1.1)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
