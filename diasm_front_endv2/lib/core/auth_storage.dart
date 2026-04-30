
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple storage for auth session (JWT + email)
class AuthStorage {
  AuthStorage._internal();
  static final AuthStorage _instance = AuthStorage._internal();
  factory AuthStorage() => _instance;

  static const _keyAccessToken = 'access_token';
  static const _keyUserEmail = 'user_email';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> saveSession({
    required String accessToken,
    required String email,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyUserEmail, email);
  }

  Future<String?> getAccessToken() async {
    final prefs = await _prefs;
    return prefs.getString(_keyAccessToken);
  }

  Future<String?> getUserEmail() async {
    final prefs = await _prefs;
    return prefs.getString(_keyUserEmail);
  }

  /// Extract user id from JWT payload.
  /// Tries both `id` and `user_id`, and handles int or String.
  Future<int?> getUserId() async {
    final token = await getAccessToken();
    if (token == null || token.trim().isEmpty) return null;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final decodedJson = utf8.decode(base64Url.decode(normalized));
      final data = json.decode(decodedJson) as Map<String, dynamic>;

      final rawId = data['id'] ?? data['user_id'];
      if (rawId is int) return rawId;
      if (rawId is String) return int.tryParse(rawId);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyUserEmail);
  }

  Future<void> clearSession() => clear();
}
