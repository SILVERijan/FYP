import 'dart:math' hide Point;

import 'package:meta/meta.dart';

import 'point.dart';

@internal
class Cell {
  Cell(this.x, this.y, this.h, List<List<Point>> polygon) {
    bool inside = false;
    double minDistSq = double.infinity;

    for (var k = 0; k < polygon.length; k++) {
      final ring = polygon[k];

      for (var i = 0, len = ring.length, j = len - 1; i < len; j = i++) {
        final a = ring[i];
        final b = ring[j];

        if ((a.y > y != b.y > y) &&
            (x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x)) {
          inside = !inside;
        }

        minDistSq = min(minDistSq, _getSegDistSq(x, y, a, b));
      }
    }

    d = minDistSq == 0 ? 0 : (inside ? 1 : -1) * sqrt(minDistSq);
  }

  final double x;
  final double y;

  final double h;
  late final double d;

  late final max = d + h * sqrt2;

  static double _getSegDistSq(double px, double py, Point a, Point b) {
    double x = a.x;
    double y = a.y;
    double dx = b.x - x;
    double dy = b.y - y;

    if (dx != 0 || dy != 0) {
      final t = ((px - x) * dx + (py - y) * dy) / (dx * dx + dy * dy);

      if (t > 1) {
        x = b.x;
        y = b.y;
      } else if (t > 0) {
        x += dx * t;
        y += dy * t;
      }
    }

    dx = px - x;
    dy = py - y;

    return dx * dx + dy * dy;
  }
}
