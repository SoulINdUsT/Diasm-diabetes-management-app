import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_record.dart';

abstract interface class SessionVault {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}
class SecureSessionVault implements SessionVault {
  static const _key = 'diasm_session_v1';
  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false, migrateWithBackup: true),
  );
  @override
  Future<String?> read() => _secure.read(key: _key);
  @override
  Future<void> write(String value) => _secure.write(key: _key, value: value);
  @override
  Future<void> delete() => _secure.delete(key: _key);
}

class AuthStorage {
  static final AuthStorage _instance = AuthStorage.withVault(SecureSessionVault());
  factory AuthStorage() => _instance;
  AuthStorage.withVault(this._vault, {Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance;
  final SessionVault _vault;
  final Future<SharedPreferences> Function() _preferences;
  static const signedOutKey = 'auth_signed_out_v1';
  Future<void> _tail = Future.value();
  bool _blocked = false;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
  Future<void> _removeLegacy(SharedPreferences prefs) async {
    for (final key in ['access_token', 'user_email']) {
      if (!await prefs.remove(key)) throw StateError('Could not remove legacy session');
    }
  }
  Future<SessionRecord?> readSession() => _serial(() async {
    final prefs = await _preferences();
    if (_blocked || prefs.getBool(signedOutKey) == true) return null;
    final value = await _vault.read();
    if (value != null) {
      final record = SessionRecord.fromJson(jsonDecode(value) as Map<String, dynamic>);
      await _removeLegacy(prefs);
      return record;
    }
    final token = prefs.getString('access_token');
    if (token == null || token.trim().isEmpty) return null;
    final record = SessionRecord(accessToken: token, email: prefs.getString('user_email') ?? '');
    final encoded = jsonEncode(record.toJson());
    await _vault.write(encoded);
    if (await _vault.read() != encoded) throw StateError('Could not verify secure session storage');
    await _removeLegacy(prefs); // Delete only after successful secure write/readback.
    return record;
  });
  Future<void> saveSession(SessionRecord record) => _serial(() async {
    final prefs = await _preferences();
    final encoded = jsonEncode(record.toJson());
    await _vault.write(encoded);
    if (await _vault.read() != encoded) throw StateError('Could not verify secure session storage');
    await _removeLegacy(prefs);
    if (!await prefs.remove(signedOutKey)) throw StateError('Could not finish saving session');
    _blocked = false;
  });
  Future<void> clearSession() {
    _blocked = true;
    return _serial(() async {
      final prefs = await _preferences();
      // Non-secret tombstone prevents reopening stale data if deletion fails.
      if (!await prefs.setBool(signedOutKey, true)) throw StateError('Could not persist logout');
      await _vault.delete();
      await _removeLegacy(prefs);
      await _clearUserCache(prefs);
    });
  }
  Future<void> clearUserCache() => _serial(() async => _clearUserCache(await _preferences()));
  Future<T> withUserCache<T>(Future<T> Function(SharedPreferences) action) =>
      _serial(() async => action(await _preferences()));
  Future<void> _clearUserCache(SharedPreferences prefs) async {
    for (final key in prefs.getKeys().where((key) => key.startsWith('rightpath_today_cache'))) {
      if (!await prefs.remove(key)) throw StateError('Could not clear account cache');
    }
  }
  // Preserve interfaces used by activity, hydration, and lifestyle screens.
  Future<String?> getAccessToken() async => (await readSession())?.accessToken;
  Future<String?> getUserEmail() async => (await readSession())?.email;
  Future<int?> getUserId() async => (await readSession())?.userId;
  Future<void> clear() => clearSession();
}
