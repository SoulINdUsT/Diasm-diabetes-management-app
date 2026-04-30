class AuthUser {
  final int id;
  final String email;
  final String role;

  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
    };
  }
}

class AuthResult {
  final String message;
  final AuthUser user;
  final String accessToken;

  const AuthResult({
    required this.message,
    required this.user,
    required this.accessToken,
  });
}

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
