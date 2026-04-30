// lib/core/auth_repository.dart
import 'dart:async';
import 'package:dio/dio.dart';

import 'api_client.dart';
import 'auth_storage.dart';

/// Simple user model from backend JSON
class AuthUser {
  final int id;
  final String email;
  final String role;

  AuthUser({
    required this.id,
    required this.email,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
    );
  }
}

/// Result object for a successful login
class AuthResult {
  final String message;
  final AuthUser user;
  final String accessToken;
  final bool profileCompleted;

  AuthResult({
    required this.message,
    required this.user,
    required this.accessToken,
    required this.profileCompleted,
  });
}

/// Custom exception so UI can show nice messages
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

/// Repository that talks to the backend auth API
class AuthRepository {
  AuthRepository._internal();
  static final AuthRepository _instance = AuthRepository._internal();
  factory AuthRepository() => _instance;

  final Dio _dio = ApiClient().dio;
  final AuthStorage _storage = AuthStorage();

  /// Login with email + password
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final Response res = await _dio.post(
        '/auth/login',
        data: <String, dynamic>{
          'email': email.trim(),
          'password': password,
        },
      );

      final status = res.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw const AuthException('Login failed. Please try again.');
      }

      final data = res.data;
      if (data is! Map<String, dynamic>) {
        throw const AuthException('Unexpected response from server.');
      }

      final userJson = data['user'];
      if (userJson is! Map<String, dynamic>) {
        throw const AuthException('User data missing in response.');
      }

      // ✅ Accept common token keys from backend
      final token = (data['accessToken'] ??
              data['token'] ??
              data['access_token'] ??
              data['jwt'])
          ?.toString();

      if (token == null || token.isEmpty) {
        throw const AuthException('Token missing in response.');
      }

      final user = AuthUser.fromJson(userJson);
      final profileCompleted = (data['profileCompleted'] as bool?) ?? false;

      // ✅ Prevent stale session remnants
      await _storage.clearSession();

      // save access token
      await _storage.saveSession(
        accessToken: token,
        email: user.email,
      );

      return AuthResult(
        message: data['message']?.toString() ?? 'Login successful.',
        user: user,
        accessToken: token,
        profileCompleted: profileCompleted,
      );
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e);
      throw AuthException(msg);
    } catch (_) {
      throw const AuthException('Something went wrong. Please try again.');
    }
  }

  /// Register user
  ///
  /// IMPORTANT:
  /// - Registration does NOT log the user in (your backend returns token: null)
  /// - So we clear any previous session to prevent showing old user data.
  Future<void> register({
    required String email,
    required String password,
  }) async {
    try {
      // ✅ ensure no old user session survives a new registration
      await _storage.clearSession();

      final Response res = await _dio.post(
        '/auth/register',
        data: <String, dynamic>{
          'email': email.trim(),
          'password': password,
        },
      );

      final status = res.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw const AuthException('Registration failed.');
      }

      // Do not save session here (token is null from backend)
      // UI must redirect to Login after success.
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e);
      throw AuthException(msg);
    } catch (_) {
      throw const AuthException('Registration failed.');
    }
  }

  /// GET user profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final res = await _dio.get('/auth/profile');
      final data = res.data;

      if (data is! Map<String, dynamic>) {
        throw const AuthException('Invalid server response.');
      }

      if (data['user'] is! Map<String, dynamic>) {
        throw const AuthException('Profile not found.');
      }

      return data['user'] as Map<String, dynamic>;
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e);
      throw AuthException(msg);
    } catch (_) {
      throw const AuthException('Failed to load profile.');
    }
  }

  /// Update profile
  Future<void> updateProfile({
    String? name,
    String? dob,
    String? sex,
    String? location,
    String? diabetesType,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (name != null) body['name'] = name;
      if (dob != null) body['dob'] = dob;
      if (sex != null) body['sex'] = sex;
      if (location != null) body['location'] = location;
      if (diabetesType != null) {
        body['diabetes_type'] = diabetesType;
      }

      final Response res = await _dio.patch(
        '/auth/profile',
        data: body,
      );

      final status = res.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw const AuthException('Failed to update profile.');
      }
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e);
      throw AuthException(msg);
    } catch (_) {
      throw const AuthException('Failed to update profile.');
    }
  }

  /// Extract backend error
  String _extractErrorMessage(DioException e) {
    final res = e.response;
    if (res == null) {
      return 'Network error. Please check your connection.';
    }

    final data = res.data;
    if (data is Map<String, dynamic>) {
      if (data['message'] is String) return data['message'] as String;
      if (data['error'] is String) return data['error'] as String;
    }

    switch (res.statusCode) {
      case 400:
        return 'Invalid request. Please check your details.';
      case 401:
        return 'Invalid email or password.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return 'Login failed. Please try again.';
    }
  }
}
