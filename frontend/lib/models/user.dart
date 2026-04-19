class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? profile_picture;
  final String? company_name;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.profile_picture,
    this.company_name,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'] ?? 'user',
      profile_picture: json['profile_picture'],
      company_name: json['company_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'profile_picture': profile_picture,
      'company_name': company_name,
    };
  }
}
