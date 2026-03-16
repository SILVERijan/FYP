import 'dart:convert';

import 'package:dart_polylabel2/dart_polylabel2.dart';
import 'package:test/test.dart';

import 'fixtures/fixture_reader.dart';

List<List<Point>> toPolygon(List<dynamic> original) => original
    .map(
      (polygon) => (polygon as List).map((p) {
        p as List;
        return (x: (p.first as int).toDouble(), y: (p.last as int).toDouble());
      }).toList(),
    )
    .toList();

List<List<Point>> loadData(String fixtureFile) =>
    toPolygon(jsonDecode(fixture(fixtureFile)) as List);

void main() {
  group('polylabel', () {
    final water1 = loadData('water1.json');
    final water2 = loadData('water2.json');

    test('finds pole of inaccessibility for water1 and precision 1', () {
      // We want to be sure to test correctly if the default changes
      // ignore: avoid_redundant_argument_values
      final p = polylabel(water1, precision: 1);
      expect(p.point, (x: 3865.85009765625, y: 2124.87841796875));
      expect(p.distance, 288.8493574779127);
    });

    test('finds pole of inaccessibility for water1 and precision 50', () {
      final p = polylabel(water1, precision: 50);
      expect(p.point, (x: 3854.296875, y: 2123.828125));
      expect(p.distance, 278.5795872381558);
    });

    test(
      'finds pole of inaccessibility for water2 and default precision 1',
      () {
        final p = polylabel(water2);
        expect(p.point, (x: 3263.5, y: 3263.5));
        expect(p.distance, 960.5);
      },
    );

    test('works on degenerate polygons', () {
      final p1 = polylabel(
        toPolygon([
          [
            [0, 0],
            [1, 0],
            [2, 0],
            [0, 0],
          ]
        ]),
      );
      expect(p1.point, (x: 0, y: 0));
      expect(p1.distance, 0);

      final p2 = polylabel(
        toPolygon([
          [
            [0, 0],
            [1, 0],
            [1, 1],
            [1, 0],
            [0, 0],
          ]
        ]),
      );
      expect(p2.point, (x: 0, y: 0));
      expect(p2.distance, 0);
    });
  });
}
