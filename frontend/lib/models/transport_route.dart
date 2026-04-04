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
      try {
        final raw = json['polyline'];
        // polyline comes as a List from backend (with 'array' cast),
        // but fallback handles JSON string just in case
        final List list = raw is String ? jsonDecode(raw) as List : raw as List;
        parsedPolyline = list.map<List<double>>((pt) {
          final p = pt as List;
          return [
            (p[0] is num ? p[0] as num : double.parse(p[0].toString())).toDouble(),
            (p[1] is num ? p[1] as num : double.parse(p[1].toString())).toDouble(),
          ];
        }).toList();
      } catch (e) {
        parsedPolyline = null;
      }
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
