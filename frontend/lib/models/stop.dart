class Stop {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final int? sortOrder;

  Stop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.sortOrder,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      sortOrder: json['pivot'] != null ? json['pivot']['sort_order'] : null,
    );
  }
}
