import 'dart:convert';

import '../auth_storage.dart';

class Gm700sbSyncProgress {
  final int targetRuid;
  final int importedCount;
  final List<List<int>> recordPayloads;

  Gm700sbSyncProgress({
    required this.targetRuid,
    required this.importedCount,
    required List<List<int>>
    recordPayloads,
  }) : recordPayloads =
           List<List<int>>.unmodifiable(
             recordPayloads.map(
               (payload) =>
                   List<
                     int
                   >.unmodifiable(
                     payload,
                   ),
             ),
           );

  int get totalRecords =>
      recordPayloads.length;

  Map<String, dynamic> toJson() {
    return {
      'targetRuid': targetRuid,
      'importedCount': importedCount,
      'recordPayloads': recordPayloads,
    };
  }

  factory Gm700sbSyncProgress.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawPayloads =
        json['recordPayloads'];

    if (rawPayloads is! List) {
      throw const FormatException(
        'Invalid GM700SB saved sync payloads.',
      );
    }

    final payloads = rawPayloads
        .map<List<int>>((item) {
          if (item is! List) {
            throw const FormatException(
              'Invalid GM700SB saved record payload.',
            );
          }

          return item
              .map<int>(
                (byte) => (byte as num)
                    .toInt(),
              )
              .toList(growable: false);
        })
        .toList(growable: false);

    final targetRuid =
        json['targetRuid'];
    final importedCount =
        json['importedCount'];

    if (targetRuid is! num ||
        importedCount is! num) {
      throw const FormatException(
        'Invalid GM700SB saved sync progress.',
      );
    }

    return Gm700sbSyncProgress(
      targetRuid: targetRuid.toInt(),
      importedCount: importedCount
          .toInt(),
      recordPayloads: payloads,
    );
  }
}

class Gm700sbSyncStore {
  final AuthStorage _authStorage;

  Gm700sbSyncStore({
    AuthStorage? authStorage,
  }) : _authStorage =
           authStorage ?? AuthStorage();

  Future<int> _requireUserId() async {
    final userId = await _authStorage
        .getUserId();

    if (userId == null) {
      throw StateError(
        'Cannot access GM700SB sync state without a logged-in user.',
      );
    }

    return userId;
  }

  String _keyPrefix({
    required int userId,
    required String meterId,
  }) {
    final encodedMeterId =
        Uri.encodeComponent(meterId);

    return 'gm700sb_sync_v1_${userId}_$encodedMeterId';
  }

  Future<int?> readSavedRuid({
    required String meterId,
  }) async {
    final userId =
        await _requireUserId();

    final key =
        '${_keyPrefix(userId: userId, meterId: meterId)}_saved_ruid';

    return _authStorage.withUserCache(
      (prefs) async =>
          prefs.getInt(key),
    );
  }

  Future<void> saveSavedRuid({
    required String meterId,
    required int ruid,
  }) async {
    if (ruid < 0) {
      throw RangeError.value(
        ruid,
        'ruid',
        'RUID cannot be negative.',
      );
    }

    final userId =
        await _requireUserId();

    final key =
        '${_keyPrefix(userId: userId, meterId: meterId)}_saved_ruid';

    await _authStorage.withUserCache((
      prefs,
    ) async {
      final success = await prefs
          .setInt(key, ruid);

      if (!success) {
        throw StateError(
          'Could not save GM700SB RUID.',
        );
      }
    });
  }

  Future<Gm700sbSyncProgress?>
  readProgress({
    required String meterId,
  }) async {
    final userId =
        await _requireUserId();

    final key =
        '${_keyPrefix(userId: userId, meterId: meterId)}_progress';

    return _authStorage.withUserCache((
      prefs,
    ) async {
      final raw = prefs.getString(key);

      if (raw == null) {
        return null;
      }

      final decoded = jsonDecode(raw);

      if (decoded is! Map) {
        throw const FormatException(
          'Invalid GM700SB saved sync state.',
        );
      }

      return Gm700sbSyncProgress.fromJson(
        decoded.map(
          (key, value) => MapEntry(
            key.toString(),
            value,
          ),
        ),
      );
    });
  }

  Future<void> saveProgress({
    required String meterId,
    required Gm700sbSyncProgress
    progress,
  }) async {
    if (progress.targetRuid < 0) {
      throw RangeError.value(
        progress.targetRuid,
        'targetRuid',
        'Target RUID cannot be negative.',
      );
    }

    if (progress.importedCount < 0 ||
        progress.importedCount >
            progress.totalRecords) {
      throw RangeError.value(
        progress.importedCount,
        'importedCount',
        'Imported count is outside the batch.',
      );
    }

    for (final payload
        in progress.recordPayloads) {
      if (payload.length != 18) {
        throw const FormatException(
          'GM700SB stored record payload must be exactly 18 bytes.',
        );
      }
    }

    final userId =
        await _requireUserId();

    final key =
        '${_keyPrefix(userId: userId, meterId: meterId)}_progress';

    final encoded = jsonEncode(
      progress.toJson(),
    );

    await _authStorage.withUserCache((
      prefs,
    ) async {
      final success = await prefs
          .setString(key, encoded);

      if (!success) {
        throw StateError(
          'Could not save GM700SB sync progress.',
        );
      }
    });
  }

  Future<void> clearProgress({
    required String meterId,
  }) async {
    final userId =
        await _requireUserId();

    final key =
        '${_keyPrefix(userId: userId, meterId: meterId)}_progress';

    await _authStorage.withUserCache((
      prefs,
    ) async {
      if (!prefs.containsKey(key)) {
        return;
      }

      final success = await prefs
          .remove(key);

      if (!success) {
        throw StateError(
          'Could not clear GM700SB sync progress.',
        );
      }
    });
  }
}
