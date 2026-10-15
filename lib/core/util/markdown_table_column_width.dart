/// Shared table sizing for every `MarkdownStyleSheet` in the app.
///
/// flutter_markdown decides whether to wrap a table in a horizontal
/// `SingleChildScrollView` with a runtime type check — `tableColumnWidth is
/// IntrinsicColumnWidth || is FixedColumnWidth` (its builder.dart, `tag ==
/// 'table'`). Its default, `FlexColumnWidth`, fails that check and instead
/// divides the viewport between the columns, so a wide table is squeezed until
/// every cell wraps and the layout falls apart (BR-9AHW8R).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Widest a single table column may grow before its cells start wrapping.
/// Without a cap, one prose-heavy cell drags the whole table out to thousands
/// of pixels and pushes the other columns off-screen — technically scrollable,
/// practically unreadable. Roughly a comfortable line length on a phone.
const double kMaxMarkdownTableColumnWidth = 280.0;

/// Drop into `MarkdownStyleSheet.tableColumnWidth` to get wide tables that
/// scroll sideways instead of reflowing.
const TableColumnWidth kMarkdownTableColumnWidth =
    CappedIntrinsicColumnWidth(kMaxMarkdownTableColumnWidth);

/// Sizes a column to its natural content width, up to [maxWidth]; past that
/// the cells wrap as usual.
///
/// Deliberately extends [IntrinsicColumnWidth] rather than composing
/// `MinColumnWidth(IntrinsicColumnWidth(), FixedColumnWidth(...))`, which would
/// compute the same widths: a `MinColumnWidth` fails flutter_markdown's `is`
/// check above and would quietly bring the squeezed layout back.
class CappedIntrinsicColumnWidth extends IntrinsicColumnWidth {
  const CappedIntrinsicColumnWidth(this.maxWidth);

  final double maxWidth;

  // Both bounds have to be capped: RenderTable asserts
  // `maxIntrinsicWidth >= minIntrinsicWidth`, so clamping only the max would
  // blow up in debug on any column whose longest word exceeds the cap.
  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) =>
      math.min(super.minIntrinsicWidth(cells, containerWidth), maxWidth);

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) =>
      math.min(super.maxIntrinsicWidth(cells, containerWidth), maxWidth);

  @override
  String toString() => 'CappedIntrinsicColumnWidth(maxWidth: $maxWidth)';
}
