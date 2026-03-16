import 'dart:math' hide Point;

import 'package:collection/collection.dart';

import 'point.dart';
import 'utils.dart';

/// Finds the polygon pole of inaccessibility using a port of
/// [mapbox's polylabel algorithm](https://github.com/mapbox/polylabel)
///
/// [precision] is specified in the same units as your input polygon. A higher
/// number means less precision (less optimal placement), which is
/// computationally cheaper (requires fewer iterations).
///
/// [debug] is only effective in debug mode.
({Point point, double distance}) polylabel(
  List<List<Point>> polygon, {
  double precision = 1.0,
  bool debug = false,
}) {
  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = double.negativeInfinity;
  double maxY = double.negativeInfinity;

  for (final (:x, :y) in polygon[0]) {
    if (x < minX) minX = x;
    if (y < minY) minY = y;
    if (x > maxX) maxX = x;
    if (y > maxY) maxY = y;
  }

  final width = maxX - minX;
  final height = maxY - minY;
  final cellSize = max(precision, min(width, height));

  if (cellSize == precision) {
    return (point: (x: minX, y: minY), distance: 0);
  }

  final cellQueue = PriorityQueue<Cell>((a, b) => b.max.compareTo(a.max));

  Cell getCentroidCell() {
    double area = 0;
    double x = 0;
    double y = 0;
    final ring = polygon[0];

    for (var i = 0, len = ring.length, j = len - 1; i < len; j = i++) {
      final a = ring[i];
      final b = ring[j];
      final f = a.x * b.y - b.x * a.y;
      x += (a.x + b.x) * f;
      y += (a.y + b.y) * f;
      area += f * 3;
    }

    if (area == 0) return Cell(ring[0].x, ring[0].y, 0, polygon);
    return Cell(x / area, y / area, 0, polygon);
  }

  var bestCell = getCentroidCell();

  final bboxCell = Cell(minX + width / 2, minY + height / 2, 0, polygon);
  if (bboxCell.d > bestCell.d) bestCell = bboxCell;

  int numProbes = 2;

  void potentiallyQueue(double x, double y, double h) {
    final cell = Cell(x, y, h, polygon);
    numProbes++;
    if (cell.max > bestCell.d + precision) cellQueue.add(cell);

    if (cell.d > bestCell.d) {
      bestCell = cell;

      // To perform action in debug mode
      // ignore: prefer_asserts_with_message
      assert(() {
        if (debug) {
          // Only executed in debug mode
          // ignore: avoid_print
          print('found best ${(1e4 * cell.d).round() / 1e4}'
              'after $numProbes probes');
        }
        return true;
      }());
    }
  }

  double h = cellSize / 2;

  for (double x = minX; x < maxX; x += cellSize) {
    for (double y = minY; y < maxY; y += cellSize) {
      potentiallyQueue(x + h, y + h, h);
    }
  }

  while (cellQueue.isNotEmpty) {
    final Cell(:x, :y, h: ch, :max) = cellQueue.removeFirst();

    // do not drill down further if there's no chance of a better solution
    if (max - bestCell.d <= precision) break;

    // split the cell into four cells
    h = ch / 2;
    potentiallyQueue(x - h, y - h, h);
    potentiallyQueue(x + h, y - h, h);
    potentiallyQueue(x - h, y + h, h);
    potentiallyQueue(x + h, y + h, h);
  }

  // To perform action in debug mode
  // ignore: prefer_asserts_with_message
  assert(() {
    if (debug) {
      // Only executed in debug mode
      // ignore: avoid_print
      print('num probes: $numProbes\nbest distance: ${bestCell.d}');
    }
    return true;
  }());

  return (point: (x: bestCell.x, y: bestCell.y), distance: bestCell.d);
}
