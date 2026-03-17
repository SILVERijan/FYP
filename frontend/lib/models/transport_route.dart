import 'dart:convert';
import 'stop.dart';

class TransportRoute {
  final int id;
  final String name;
  final String type;
  final List<Stop>? stops;
  final List<List<double>>? polyline;

  TransportRoute({
    required this.id,
    required this.name,
    required this.type,
    this.stops,
    this.polyline,
  });

  factory TransportRoute.fromJson(Map<String, dynamic> json) {
    List<List<double>>? parsedPolyline;
    if (json['polyline'] != null) {
      final raw = json['polyline'];
      // polyline may come as a JSON string or already-decoded list
      final List list = raw is String ? jsonDecode(raw) as List : raw as List;
      parsedPolyline = list.map<List<double>>((pt) {
        final p = pt as List;
        return [p[0].toDouble(), p[1].toDouble()];
      }).toList();
    }

    return TransportRoute(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      stops: json['stops'] != null
          ? (json['stops'] as List).map((i) => Stop.fromJson(i)).toList()
          : null,
      polyline: parsedPolyline,
    );
  }
}
