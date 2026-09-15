import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';

import '../core/dates.dart';

/// Horizontal day picker that keeps the selected day centred.
class DayStrip extends StatefulWidget {
  const DayStrip({super.key, required this.selected, required this.onSelect, required this.start, required this.end, this.marked = const {}});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final DateTime start;
  final DateTime end;

  /// Days that have entries; shown with a small dot.
  final Set<DateTime> marked;

  @override
  State<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<DayStrip> {
  static const _extent = 60.0;
  static const _height = 68.0;

  final _controller = ScrollController();
  double _viewport = 0;

  int get _count => daysBetween(widget.start, widget.end) + 1;

  int _indexOf(DateTime d) => daysBetween(widget.start, d);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _center(animate: false));
  }

  @override
  void didUpdateWidget(covariant DayStrip old) {
    super.didUpdateWidget(old);
    if (!isSameDay(old.selected, widget.selected)) _center();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _center({bool animate = true}) {
    if (!_controller.hasClients || _viewport == 0) return;
    final target = (_indexOf(widget.selected) * _extent - (_viewport - _extent) / 2)
        .clamp(0.0, _controller.position.maxScrollExtent);
    if (animate) {
      _controller.animateTo(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;

    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_viewport != constraints.maxWidth) {
            _viewport = constraints.maxWidth;
            WidgetsBinding.instance.addPostFrameCallback((_) => _center(animate: false));
          }
          return ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemExtent: _extent,
            itemCount: _count,
            itemBuilder: (context, i) {
              final day = addDays(widget.start, i);
              final selected = isSameDay(day, widget.selected);
              final isToday = isSameDay(day, today);
              final weekend = day.weekday > 5;
              final marked = widget.marked.contains(day);
              final fg = selected ? colors.primaryForeground : (weekend ? colors.mutedForeground : colors.foreground);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: FTappable(
                  onPress: () => widget.onSelect(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: selected ? colors.primary : null,
                      border: Border.all(color: selected ? colors.primary : (isToday ? colors.foreground : colors.border)),
                      borderRadius: context.theme.style.borderRadius,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(day),
                          style: typography.xs.copyWith(color: selected ? fg : colors.mutedForeground, height: 1),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${day.day}',
                          style: typography.lg.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: fg,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: marked ? (selected ? colors.primaryForeground : colors.primary) : const Color(0x00000000),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
