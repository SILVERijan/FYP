class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? profile_picture;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.profile_picture,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'] ?? 'user',
      profile_picture: json['profile_picture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'profile_picture': profile_picture,
    };
  }
}
