import 'package:flutter/widgets.dart';

import '../../services/layout_prefs.dart';
import 'day_schedule.dart';
import 'timeline_row.dart';

/// The day's timeline, scrolled so the running item sits at the top: what
/// is over matters least. Follows the clock while the day runs and stops
/// scrolling once the list cannot go further.
class DayList extends StatefulWidget {
  const DayList({super.key, required this.items, required this.now, required this.dayRunning, required this.side});

  final List<DayItem> items;
  final DateTime now;
  final bool dayRunning;
  final TimeColumnSide side;

  @override
  State<DayList> createState() => _DayListState();
}

class _DayListState extends State<DayList> {
  final _controller = ScrollController();
  final _keys = <int, GlobalKey>{};
  int? _anchored;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _anchor(animate: false));
  }

  @override
  void didUpdateWidget(covariant DayList old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _anchor());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _currentIndex {
    if (!widget.dayRunning) return null;
    for (final (i, item) in widget.items.indexed) {
      if (item.end.isAfter(widget.now)) return i;
    }
    return null;
  }

  // Only re-anchors when the running item changes, so a user who scrolled
  // away is not dragged back every tick.
  void _anchor({bool animate = true}) {
    final index = _currentIndex;
    if (index == null || index == _anchored || !mounted || !_controller.hasClients) return;
    _anchored = index;
    final context = _keys[index]?.currentContext;
    if (context == null) return;
    final box = context.findRenderObject() as RenderBox;
    final list = _controller.position.context.storageContext.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero, ancestor: list).dy + _controller.offset - 4;
    final target = offset.clamp(0.0, _controller.position.maxScrollExtent);
    if (animate) {
      _controller.animateTo(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return ListView(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 24),
      children: [
        for (var i = 0; i < items.length; i++)
          KeyedSubtree(
            key: _keys.putIfAbsent(i, GlobalKey.new),
            child: TimelineRow(item: items[i], now: widget.now, isFirst: i == 0, isLast: i == items.length - 1, dimPast: widget.dayRunning, side: widget.side),
          ),
      ],
    );
  }
}
