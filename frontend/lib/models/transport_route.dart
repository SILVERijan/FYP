import 'stop.dart';

class TransportRoute {
  final int id;
  final String name;
  final String type;
  final List<Stop>? stops;

  TransportRoute({
    required this.id,
    required this.name,
    required this.type,
    this.stops,
  });

  factory TransportRoute.fromJson(Map<String, dynamic> json) {
    return TransportRoute(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      stops: json['stops'] != null
          ? (json['stops'] as List).map((i) => Stop.fromJson(i)).toList()
          : null,
    );
  }
}
