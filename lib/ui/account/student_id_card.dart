import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../domain/student_id.dart';
import '../core/dates.dart';

/// The ID laid out the way the Schulnetz page does: photo, title, school,
/// name, date of birth, programme, validity, signature, QR code and logo.
class StudentIdCardView extends StatelessWidget {
  const StudentIdCardView({super.key, required this.card, this.photoKey, this.hideShared = false});

  final StudentIdCard card;

  /// Key on the photo so the expansion can fly it in from the profile tile;
  /// [hideShared] blanks it while it is in flight.
  final Key? photoKey;
  final bool hideShared;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final initial = card.fullName.isNotEmpty ? card.fullName.characters.first.toUpperCase() : '?';
    final divider = Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: FDivider(style: (s) => s.copyWith(padding: EdgeInsets.zero)));

    Widget label(String text) => Text(text.toUpperCase(),
        textAlign: TextAlign.center,
        style: typography.xs.copyWith(color: colors.mutedForeground, fontSize: 10, letterSpacing: 0.6, fontWeight: FontWeight.w600));
    Widget value(String? text, {TextStyle? style}) =>
        Text(text?.isNotEmpty == true ? text! : '-', textAlign: TextAlign.center, style: style ?? typography.sm.copyWith(fontWeight: FontWeight.w600));
    Widget field(String l, String? v) => Column(children: [label(l), const SizedBox(height: 2), value(v)]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Opacity(
              opacity: hideShared ? 0 : 1,
              child: StudentIdPhoto(key: photoKey, initial: initial, photo: card.photo, photoUrl: card.photoUrl, width: 96, height: 120, radius: 14),
            ),
          ),
          const SizedBox(height: 12),
          Text(card.title, textAlign: TextAlign.center, style: typography.lg.copyWith(fontWeight: FontWeight.w800, color: colors.primary)),
          divider,
          field(card.schoolLabel, card.schoolName),
          divider,
          Row(
            children: [
              Expanded(child: field('Nachname', card.lastName)),
              const SizedBox(width: 16),
              Expanded(child: field('Vorname', card.firstName)),
            ],
          ),
          divider,
          field('Geburtsdatum', card.birthday == null ? null : formatDate(fromApiDate(card.birthday!))),
          if (card.programme != null) ...[divider, field('Ausbildung', card.programme)],
          if (card.validUntil != null) ...[divider, field('Gültig bis', formatDate(fromApiDate(card.validUntil!)))],
          for (final (l, v) in card.extras) ...[divider, field(l, v)],
          if (card.signerName != null) ...[
            divider,
            if (card.signature != null) Center(child: Image.memory(card.signature!, height: 56, fit: BoxFit.contain)),
            const SizedBox(height: 4),
            label(card.signerName!),
          ],
          if (card.qrCode != null || card.logo != null) ...[
            divider,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (card.qrCode != null) Image.memory(card.qrCode!, width: 96, height: 96, fit: BoxFit.contain, filterQuality: FilterQuality.none),
                if (card.qrCode != null && card.logo != null) const SizedBox(width: 24),
                if (card.logo != null) Flexible(child: Image.memory(card.logo!, height: 64, fit: BoxFit.contain)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The photo slot, shared between the tile's avatar and the card, so the same
/// widget can be drawn at any size in between.
class StudentIdPhoto extends StatelessWidget {
  const StudentIdPhoto({super.key, required this.initial, this.photo, this.photoUrl, required this.width, required this.height, required this.radius, this.fontSize = 34});

  final String initial;
  final Uint8List? photo;
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
      child: photo != null
          ? Image.memory(photo!, fit: BoxFit.cover)
          : photoUrl == null || photoUrl!.isEmpty
              ? Center(child: Text(initial, style: typography.xl3.copyWith(fontSize: fontSize, color: colors.mutedForeground, fontWeight: FontWeight.w700)))
              : Image.network(photoUrl!, fit: BoxFit.cover),
    );
  }
}

/// Where the shared pieces of the profile tile sit, in global coordinates,
/// captured when the expansion starts.
class TileGeometry {
  const TileGeometry({required this.tile, required this.avatar});

  final Rect tile;
  final Rect avatar;
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
  Size? _cardSize;
  Rect? _photoInCard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  // The card sizes itself to its content and decides where the photo sits; an
  // offstage copy at the final width is measured once instead of hard-coding it.
  void _measure() {
    final card = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    final photo = _photoKey.currentContext?.findRenderObject() as RenderBox?;
    if (card == null || photo == null || !mounted) return;
    setState(() {
      _cardSize = card.size;
      _photoInCard = photo.localToGlobal(Offset.zero, ancestor: card) & photo.size;
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
    final bottom = padding.bottom + 24.0;
    final cardW = size.width - 48;
    final maxH = size.height - top - bottom;
    final cardH = (_cardSize?.height ?? cardW * 1.4).clamp(0.0, maxH);
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
        final flying = v > 0 && v < 1 && _photoInCard != null;
        final tileOpacity = (1 - v / 0.2).clamp(0.0, 1.0);
        final cardOpacity = ((v - 0.2) / 0.8).clamp(0.0, 1.0);
        final photoRect = flying ? Rect.lerp(widget.from.avatar, _photoInCard!.shift(to.topLeft), t)! : null;

        return Stack(
          children: [
            Positioned.fill(child: IgnorePointer(ignoring: v == 0, child: Opacity(opacity: t, child: ColoredBox(color: colors.background)))),
            Offstage(
              child: SizedBox(
                width: cardW,
                child: StudentIdCardView(key: _measureKey, card: widget.card, photoKey: _photoKey),
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
                      widget.card.validUntil == null ? 'Programme, validity and signature appear once the school connection provides them.' : 'Show this card at the entrance or the library.',
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
                      if (cardOpacity > 0)
                        Opacity(
                          opacity: cardOpacity,
                          child: scaled(SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: StudentIdCardView(card: widget.card, hideShared: flying)), Size(cardW, _cardSize?.height ?? to.height)),
                        ),
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
                    photo: widget.card.photo,
                    photoUrl: widget.card.photoUrl,
                    width: photoRect.width,
                    height: photoRect.height,
                    radius: lerpDouble(32, 14, t)!,
                    fontSize: lerpDouble(20, 34, t)!,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
