
// lib/core/food_repository.dart

import 'package:dio/dio.dart';

import 'api_client.dart';
import 'lifestyle_models.dart';

class FoodRepository {
  FoodRepository._internal();
  static final FoodRepository _instance = FoodRepository._internal();
  factory FoodRepository() => _instance;

  final Dio _dio = ApiClient().dio;

  // --------------------------------------------------
  // LIST FOODS
  // Backend: GET /api/v1/lifestyle/foods?limit=5&lang=en
  // Response: { "ok": true, "rows": [ {...}, ... ], "total": 344 }
  // --------------------------------------------------
  Future<List<Food>> searchFoods({
    String? q,
    int limit = 20,
    int offset = 0,
    String? lang,
  }) async {
    try {
      final res = await _dio.get(
        '/lifestyle/foods',
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          'limit': limit,
          'offset': offset,
          if (lang != null && lang.isNotEmpty) 'lang': lang,
        },
      );

      final data = res.data;

      if (data is Map<String, dynamic>) {
        final rows = data['rows'];
        if (rows is List) {
          return rows
              .whereType<Map<String, dynamic>>()
              .map((j) => Food.fromJson(j))
              .toList();
        }
      }

      // Fallback: if somehow backend ever returns a raw list
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((j) => Food.fromJson(j))
            .toList();
      }

      return <Food>[];
    } catch (e) {
      // You can uncomment this for debugging:
      // print('searchFoods error: $e');
      return <Food>[];
    }
  }

  // --------------------------------------------------
  // ONE FOOD DETAIL
  // Backend: GET /api/v1/lifestyle/foods/:id?lang=en
  // Response: { "ok": true, "data": { ... } }
  // --------------------------------------------------
  Future<Food?> getFood(int id, String lang) async {
    try {
      final res = await _dio.get(
        '/lifestyle/foods/$id',
        queryParameters: {'lang': lang},
      );

      final data = res.data;

      if (data is Map<String, dynamic>) {
        final raw = data['data'];
        if (raw is Map<String, dynamic>) {
          return Food.fromJson(raw);
        }
      }

      return null;
    } catch (e) {
      // print('getFood error: $e');
      return null;
    }
  }

  // --------------------------------------------------
  // PORTIONS
  // Backend: GET /api/v1/lifestyle/foods/:id/portions
  // Response: { "ok": true, "portions": [ {...}, ... ] }
  // --------------------------------------------------
  Future<List<FoodPortion>> getPortions(int foodId) async {
    try {
      final res = await _dio.get('/lifestyle/foods/$foodId/portions');

      final data = res.data;

      if (data is Map<String, dynamic>) {
        final rows = data['portions'];
        if (rows is List) {
          return rows
              .whereType<Map<String, dynamic>>()
              .map((j) => FoodPortion.fromJson(j))
              .toList();
        }
      }

      // Fallback, just in case
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((j) => FoodPortion.fromJson(j))
            .toList();
      }

      return <FoodPortion>[];
    } catch (e) {
      // print('getPortions error: $e');
      return <FoodPortion>[];
    }
  }
}
