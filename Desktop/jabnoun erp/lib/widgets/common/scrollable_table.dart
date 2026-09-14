import 'package:flutter/material.dart';

/// Wraps a [DataTable] with both horizontal and vertical scrolling so that
/// on narrow screens (mobile/web-mobile) all columns — including the
/// trailing actions column — remain fully visible via horizontal scroll,
/// instead of being squeezed to fit the viewport width.
class ScrollableTable extends StatelessWidget {
  final DataTable table;

  const ScrollableTable({super.key, required this.table});

  @override
  Widget build(BuildContext context) {
    final horizontalController = ScrollController();
    return Scrollbar(
      controller: horizontalController,
      thumbVisibility: true,
      notificationPredicate: (notif) => notif.depth == 0,
      child: SingleChildScrollView(
        controller: horizontalController,
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: table,
        ),
      ),
    );
  }
}
