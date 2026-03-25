import 'dart:convert';
import 'lib/models/transport_route.dart';

void main() {
  final jsonString = '''
  [{
    "id": 1,
    "name": "Ratnapark - Suryabinayak",
    "type": "Bus",
    "polyline": "[[27.705626,85.322828],[27.705978,85.322839]]"
  }]
  ''';

  try {
    final list = jsonDecode(jsonString) as List;
    for (var json in list) {
      final route = TransportRoute.fromJson(json);
      print('Successfully parsed: \${route.name}');
    }
  } catch (e, stacktrace) {
    print('Failed to parse: \$e');
    print(stacktrace);
  }
}
