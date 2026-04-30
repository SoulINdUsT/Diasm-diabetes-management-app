
// lib/core/rightpath_repository.dart

import 'dart:convert';

import 'package:diasm_front_endv2/core/api_client.dart';
import 'package:diasm_front_endv2/core/rightpath_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository for Daily Wellness Score / Right Path feature.
class RightPathRepository {
  final ApiClient _client;

  RightPathRepository({ApiClient? client}) : _client = client ?? ApiClient();

  /// Convenience factory to match your other repositories
  factory RightPathRepository.fromClient([ApiClient? client]) {
    return RightPathRepository(client: client);
  }

  // ---------------- Local cache (SharedPreferences) ----------------

  static const String _kTodayCacheKey = 'rightpath_today_cache_v1';
  static const String _kTodayCacheDateKey = 'rightpath_today_cache_date_v1';

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _cacheTodayStatus(Map<String, dynamic> jsonMap) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _fmtDate(DateTime.now());
    await prefs.setString(_kTodayCacheKey, jsonEncode(jsonMap));
    await prefs.setString(_kTodayCacheDateKey, todayKey);
  }

  Future<RightPathTodayStatus?> _readCachedTodayStatusIfValid() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedJson = prefs.getString(_kTodayCacheKey);
    final cachedDate = prefs.getString(_kTodayCacheDateKey);

    if (cachedJson == null || cachedJson.trim().isEmpty) return null;

    final todayKey = _fmtDate(DateTime.now());
    if (cachedDate != todayKey) return null; // only valid for "today"

    try {
      final map = jsonDecode(cachedJson) as Map<String, dynamic>;
      return RightPathTodayStatus.fromJson(map);
    } catch (_) {
      return null;
    }
  }

// ---------------- Save today's status ----------------

Future<RightPathTodayStatus> saveTodayStatus({
  required int walkMinutes,
  required int hydrationGlasses,
  required bool mealsOnTime,
  required double sleepHours,
  required bool glucoseChecked,
}) async {
  final dio = ApiClient().dio;

  final payload = {
    'walkMinutes': walkMinutes,
    'hydrationGlasses': hydrationGlasses,
    'mealsOnTime': mealsOnTime,
    'sleepHours': sleepHours,
    'glucoseChecked': glucoseChecked,
  };

  final res = await dio.post(
    '/right-path/today',
    data: payload,
  );

  Map<String, dynamic>? map;
  final data = res.data;

  if (data is Map<String, dynamic>) {
    map = data;
  } else if (data is String) {
    final trimmed = data.trim();
    if (trimmed.isNotEmpty && trimmed != 'null') {
      map = jsonDecode(trimmed) as Map<String, dynamic>;
    }
  }

  if (map == null) {
    throw Exception('Empty response from /right-path/today');
  }

  // ✅ cache today's data
  await _cacheTodayStatus(map);

  return RightPathTodayStatus.fromJson(map);
}

// ---------------- Get today's status ----------------

Future<RightPathTodayStatus?> getTodayStatus() async {
  try {
    final resp = await _client.dio.get('/right-path/today');
    final data = resp.data;

    if (data == null) {
      return await _readCachedTodayStatusIfValid();
    }

    if (data is Map<String, dynamic>) {
      await _cacheTodayStatus(data);
      return RightPathTodayStatus.fromJson(data);
    }

    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty || trimmed == 'null') {
        return await _readCachedTodayStatusIfValid();
      }
      final map = jsonDecode(trimmed) as Map<String, dynamic>;
      await _cacheTodayStatus(map);
      return RightPathTodayStatus.fromJson(map);
    }

    return await _readCachedTodayStatusIfValid();
  } catch (_) {
    // network / auth / server error → fallback to cache
    return await _readCachedTodayStatusIfValid();
  }
}

// ---------------- Cache-only access (for HomeScreen fallback) ----------------

Future<RightPathTodayStatus?> getCachedTodayStatus() async {
  return await _readCachedTodayStatusIfValid();
}

  // ---------------- Weekly summary ----------------

  /// GET /right-path/weekly-summary
  Future<RightPathWeeklySummary?> getWeeklySummary() async {
    final resp = await _client.dio.get('/right-path/weekly-summary');
    final data = resp.data;

    if (data == null) return null;

    if (data is Map<String, dynamic>) {
      return RightPathWeeklySummary.fromJson(data);
    }

    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty || trimmed == 'null') return null;
      final map = jsonDecode(trimmed) as Map<String, dynamic>;
      return RightPathWeeklySummary.fromJson(map);
    }

    return null;
  }
}
