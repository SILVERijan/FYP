# dart_polylabel2

A fast algorithm for finding polygon pole of inaccessibility. Useful for optimal placement of a text label on a polygon.

Dart port of [mapbox's polylabel algorithm](https://github.com/mapbox/polylabel). Thanks to [beroso's original port (`polylabel`)](https://github.com/beroso/dart_polylabel) for inspiration.

This has a few changes from `polylabel`, which make it not backwards compatible:

* No usage of 'dart:math's `Point`  
  * It's been described as [legacy since Feb 2024](https://github.com/dart-lang/sdk/commit/885126e51bf2d0c612a42ba55395ac4f4d9f7b42) in Dart/Flutter, and will be [deprecated in future](https://github.com/dart-lang/sdk/issues/54852)
  * This reduces internal & external casting and usage of generic types (which are inefficient), which has increased performance
  * It was overkill for the simple 2D Cartesian coordinate container needed
* Uses newer Dart lanaguage features

## Usage

```dart
import 'package:dart_polylabel2/dart_polylabel2.dart';

final polygon = [[(x: 0, y: 0), (x: 1, y: 0), (x: 1, y: 1), (x: 0, y: 1), (x: 0, y: 0)]];
final (point: (:x, :y), :distance) = polylabel(polygon);
```
