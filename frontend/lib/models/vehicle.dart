import 'transport_route.dart';

class Vehicle {
  final int id;
  final String plateNumber;
  final double latitude;
  final double longitude;
  final String status;
  final TransportRoute? route;

  Vehicle({
    required this.id,
    required this.plateNumber,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.route,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      plateNumber: json['plate_number'],
      latitude: json['current_lat'].toDouble(),
      longitude: json['current_lng'].toDouble(),
      status: json['status'],
      route: json['route'] != null ? TransportRoute.fromJson(json['route']) : null,
    );
  }
}
