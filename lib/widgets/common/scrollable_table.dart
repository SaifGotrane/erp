import 'package:flutter/material.dart';

/// Wraps a [DataTable] with both horizontal and vertical scrolling so that
/// wide tables don't overflow on narrow screens and long lists scroll
/// vertically. Replaces the bare `SingleChildScrollView(child: DataTable(...))`
/// pattern found across many screens.
class ScrollableTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double headingRowHeight;
  final double dataRowHeight;
  final double columnSpacing;
  final double horizontalMargin;

  const ScrollableTable({
    super.key,
    required this.columns,
    required this.rows,
    this.headingRowHeight = 56,
    this.dataRowHeight = 52,
    this.columnSpacing = 24,
    this.horizontalMargin = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 72,
          ),
          child: SingleChildScrollView(
            child: DataTable(
              headingRowHeight: headingRowHeight,
              dataRowHeight: dataRowHeight,
              columnSpacing: columnSpacing,
              horizontalMargin: horizontalMargin,
              columns: columns,
              rows: rows,
            ),
          ),
        ),
      ),
    );
  }
}
