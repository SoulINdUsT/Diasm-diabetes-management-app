import 'dart:convert';

/// A nullable refresh token is supported only for migrated legacy sessions.
class SessionRecord {
  final String accessToken;
  final String? refreshToken;
  final String email;
  const SessionRecord({required this.accessToken, this.refreshToken, required this.email});

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    if (access is! String || access.trim().isEmpty ||
        (refresh != null && (refresh is! String || refresh.trim().isEmpty))) {
      throw const FormatException('Invalid session record');
    }
    return SessionRecord(accessToken: access, refreshToken: refresh as String?,
        email: json['email'] as String? ?? '');
  }
  Map<String, dynamic> toJson() => {
    'version': 1, 'accessToken': accessToken, 'refreshToken': refreshToken, 'email': email,
  };
  // Claims are hints for scheduling/identity only, never authorization.
  Map<String, dynamic>? get _claims {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return null;
      return jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
    } catch (_) { return null; }
  }
  int? get userId => int.tryParse('${_claims?['id'] ?? _claims?['user_id']}');
  bool get accessExpired {
    final exp = _claims?['exp'];
    return exp is! num || exp <= DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }
}
