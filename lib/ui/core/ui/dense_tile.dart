import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Tighter tile padding for one-line rows on glance surfaces.
FItemStyle denseTileStyle(FItemStyle s) => s.copyWith(
      contentStyle: (c) => c.copyWith(padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 10, 9), prefixIconSpacing: 10),
    );

/// A single-line row: small prefix, title, muted trailing text.
class DenseTile extends StatelessWidget with FTileMixin {
  const DenseTile({super.key, this.prefix, required this.title, this.trailing, this.suffix, this.onPress});

  final Widget? prefix;
  final String title;
  final String? trailing;
  final Widget? suffix;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    return FTile(
      style: denseTileStyle,
      prefix: prefix,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      details: trailing == null ? null : Text(trailing!, style: typography.sm.copyWith(color: colors.mutedForeground)),
      suffix: suffix,
      onPress: onPress,
    );
  }
}

/// "23.09." in a fixed-width slot, the dense stand-in for a date chip. Day
/// and month, since the weekday alone says nothing in a list spanning weeks.
class DenseDate extends StatelessWidget {
  const DenseDate(this.date, {super.key, this.color});

  final DateTime date;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final l = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return SizedBox(
      width: 52,
      child: Text(
        '${two(l.day)}.${two(l.month)}.',
        maxLines: 1,
        softWrap: false,
        style: typography.sm.copyWith(color: color ?? colors.mutedForeground, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}
