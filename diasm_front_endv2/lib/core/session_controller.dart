import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'auth_storage.dart';
import 'session_record.dart';

enum SessionStatus { loading, authenticated, signedOut, unavailable, restricted }
class SessionChanged implements Exception { const SessionChanged(); }

class SessionController extends ChangeNotifier {
  SessionController({required this.storage, required this.transport});
  final AuthStorage storage;
  /// No interceptor: refresh and logout cannot recurse.
  final Dio transport;
  SessionRecord? _record;
  SessionRecord? _pendingSave;
  SessionRecord? get record => _record;
  int _generation = 0;
  int get generation => _generation;
  SessionStatus status = SessionStatus.loading;
  String? message;
  bool needsLogin = false;
  bool _logoutPending = false;
  Future<void>? _restoring;
  Future<String>? _refreshing;
  int? _refreshGeneration;

  bool isCurrent(int generation) => generation == _generation;
  void _check(int generation) { if (!isCurrent(generation)) throw const SessionChanged(); }
  void _state(SessionStatus next, [String? text]) {
    status = next;
    message = text;
    notifyListeners();
  }
  Future<void> restore() {
    if (_restoring != null) return _restoring!;
    final generation = _generation;
    late final Future<void> operation;
    operation = _restore(generation).whenComplete(() {
      if (identical(_restoring, operation)) _restoring = null;
    });
    _restoring = operation;
    return operation;
  }
  Future<void> _restore(int generation) async {
    _state(SessionStatus.loading);
    try {
      if (_logoutPending) {
        await storage.clearSession();
        _check(generation);
        _logoutPending = false;
        _state(SessionStatus.signedOut);
        return;
      }
      // Retry persistence of a returned pair after a storage failure, without
      // rotating its already-revoked predecessor again in this process.
      if (_pendingSave != null) {
        final pending = _pendingSave!;
        await storage.saveSession(pending);
        _check(generation);
        _record = pending;
        _pendingSave = null;
      }
      final saved = _record ?? await storage.readSession();
      _check(generation);
      _record = saved;
      if (saved == null) { _state(SessionStatus.signedOut); return; }
      var refreshed = false;
      if (saved.accessExpired && saved.refreshToken != null) {
        await refreshAccess(saved.accessToken, generation);
        refreshed = true;
      }
      _check(generation);
      try {
        await _validateProfile();
      } on DioException catch (error) {
        if (error.response?.statusCode != 401 || refreshed) rethrow;
        await refreshAccess(_record!.accessToken, generation);
        _check(generation);
        await _validateProfile();
      }
      _check(generation);
      _state(SessionStatus.authenticated);
    } on SessionChanged {
      // A logout/login owns the newer state.
    } catch (_) {
      if (isCurrent(generation) && status == SessionStatus.loading) {
        _state(SessionStatus.unavailable, 'We could not restore your session. Check your connection and try again.');
      }
    }
  }
  Future<void> _validateProfile() async {
    final response = await transport.get('/auth/profile', options: Options(
      headers: {'Authorization': 'Bearer ${_record!.accessToken}'},
    ));
    final data = response.data;
    if (data is! Map || data['user'] is! Map || data['user']['id'] == null) {
      throw const FormatException('Invalid profile response');
    }
  }
  int beginLogin() {
    _generation++;
    _pendingSave = null;
    return _generation;
  }
  Future<void> acceptLogin(SessionRecord record, int generation) async {
    _check(generation);
    _pendingSave = record;
    try {
      await storage.clearUserCache();
      _check(generation);
      await storage.saveSession(record);
      _check(generation);
    } catch (_) {
      if (isCurrent(generation)) _state(SessionStatus.unavailable, 'Your login could not be saved securely. Please try again.');
      rethrow;
    }
    _record = record;
    _pendingSave = null;
    _logoutPending = false;
    needsLogin = false;
    _state(SessionStatus.authenticated);
  }
  Future<String> refreshAccess(String rejectedAccess, int generation) {
    _check(generation);
    final current = _record;
    if (current == null) return Future.error(const SessionChanged());
    if (_refreshing != null && _refreshGeneration == generation) return _refreshing!;
    if (_pendingSave != null) return Future.error(StateError('Session storage requires retry'));
    if (current.accessToken != rejectedAccess) return Future.value(current.accessToken);
    late final Future<String> operation;
    operation = _refresh(current, generation).whenComplete(() {
      if (identical(_refreshing, operation)) { _refreshing = null; _refreshGeneration = null; }
    });
    _refreshGeneration = generation;
    _refreshing = operation;
    return operation;
  }
  Future<String> _refresh(SessionRecord previous, int generation) async {
    if (previous.refreshToken == null) {
      await _invalidate(generation, 'Please log in once to renew your session.');
      throw const SessionChanged();
    }
    SessionRecord next;
    try {
      final response = await transport.post('/auth/refresh', data: {'refreshToken': previous.refreshToken});
      final data = Map<String, dynamic>.from(response.data as Map);
      next = SessionRecord.fromJson({...data, 'email': previous.email});
      if (next.refreshToken == null) throw const FormatException('Missing replacement refresh token');
    } on DioException catch (error) {
      _check(generation);
      final data = error.response?.data;
      final code = data is Map ? data['code'] : null;
      if (error.response?.statusCode == 401 && const {
        'REFRESH_TOKEN_INVALID', 'REFRESH_TOKEN_EXPIRED', 'REFRESH_SESSION_INVALID',
      }.contains(code)) {
        await _invalidate(generation, 'Your session has expired. Please log in again.');
      } else if (error.response?.statusCode == 403 && const {
        'ACCOUNT_INACTIVE', 'EMAIL_VERIFICATION_REQUIRED',
      }.contains(code)) {
        await _invalidate(generation, code == 'ACCOUNT_INACTIVE'
            ? 'This account is inactive. Contact support or use another account.'
            : 'Verify your email before logging in again.', restricted: true);
      }
      rethrow;
    }
    if (!isCurrent(generation)) {
      unawaited(_revoke(next.refreshToken));
      throw const SessionChanged();
    }
    _pendingSave = next;
    try {
      await storage.saveSession(next);
      _check(generation);
    } on SessionChanged {
      unawaited(_revoke(next.refreshToken));
      rethrow;
    } catch (_) {
      if (isCurrent(generation)) _state(SessionStatus.unavailable, 'Your session could not be saved securely. Please try again.');
      rethrow;
    }
    _record = next;
    _pendingSave = null;
    return next.accessToken;
  }
  Future<void> _invalidate(int generation, String text, {bool restricted = false}) async {
    _check(generation);
    _record = null;
    _pendingSave = null;
    needsLogin = true;
    try {
      await storage.clearSession();
      _check(generation);
      _state(restricted ? SessionStatus.restricted : SessionStatus.signedOut, text);
    } on SessionChanged { rethrow; }
    catch (_) {
      _logoutPending = true;
      _state(SessionStatus.unavailable, 'Could not clear this session. Please retry.');
    }
  }
  Future<void> logout() async {
    final old = _pendingSave ?? _record;
    final generation = ++_generation;
    _record = null;
    _pendingSave = null;
    _restoring = null;
    needsLogin = true;
    _logoutPending = true;
    final clearing = storage.clearSession(); // Enqueue before any newer login.
    _state(SessionStatus.loading);
    unawaited(_revoke(old?.refreshToken));
    try {
      await clearing;
      _check(generation);
      _logoutPending = false;
      _state(SessionStatus.signedOut);
    } on SessionChanged { /* Newer login wins. */ }
    catch (_) {
      if (isCurrent(generation)) _state(SessionStatus.unavailable, 'You are signed out here, but storage cleanup failed. Please retry.');
    }
  }
  Future<void> _revoke(String? refreshToken) async {
    if (refreshToken == null) return;
    try { await transport.post('/auth/logout', data: {'refreshToken': refreshToken}); }
    catch (_) { /* Offline logout still clears the local session. */ }
  }
}
