

import 'package:diasm_front_endv2/core/api_client.dart';
import 'package:diasm_front_endv2/core/auth_storage.dart';
import 'package:diasm_front_endv2/core/lifestyle_models.dart';
import 'package:dio/dio.dart';

class LifestyleRepository {
  final ApiClient _api = ApiClient();
  final AuthStorage _auth = AuthStorage();

  LifestyleRepository();

  Future<int> _resolveUserId() async {
    final id = await _auth.getUserId();
    if (id != null) return id;
    return 1;
  }

  /// Backwards-compatible alias so older code using `recommendMealPlan`
  /// still compiles. Uses daily calories as target.
  Future<MealPlanRecommendation?> recommendMealPlan(
    double targetCalories,
  ) {
    return recommendMealPlanForCalories(targetCalories);
  }

  // ---------------------------------------------------
  // SNAPSHOT
  // ---------------------------------------------------
  Future<LifestyleSnapshot?> getSnapshot() async {
    final userId = await _resolveUserId();

    try {
      final Response res = await _api.dio.get(
        '/lifestyle/snapshot',
        queryParameters: {'user_id': userId},
      );

      if (res.statusCode == 200 &&
          res.data is Map &&
          res.data['ok'] == true) {
        return LifestyleSnapshot.fromJson(res.data);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------
  // HYDRATION
  // ---------------------------------------------------
  Future<bool> logHydration(int volumeMl) async {
    final userId = await _resolveUserId();

    final body = {
      'user_id': userId,
      'volume_ml': volumeMl,
      'event_at': 'NOW()',
    };

    try {
      final Response res = await _api.dio.post(
        '/hydration/event',
        data: body,
      );

      return res.statusCode == 200 && res.data['ok'] == true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------
  // FASTING – ACTIVE
  // ---------------------------------------------------
  Future<FastingActiveSession?> getFastingActive() async {
    final userId = await _resolveUserId();

    try {
      final Response res = await _api.dio.get(
        '/lifestyle/fasting/active',
        queryParameters: {'user_id': userId},
      );

      if (res.statusCode != 200) return null;

      final data = res.data;
      if (data is! Map<String, dynamic>) return null;

      final rows = (data['data']?['rows'] as List<dynamic>? ?? const []);
      if (rows.isEmpty) return null;

      final first = rows.first;
      if (first is! Map<String, dynamic>) return null;

      return FastingActiveSession.fromJson(first);
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------
  // FASTING – HISTORY
  // ---------------------------------------------------
  Future<List<FastingHistoryItem>> getFastingHistory({int limit = 30}) async {
    final userId = await _resolveUserId();

    try {
      final Response res = await _api.dio.get(
        '/lifestyle/fasting/history',
        queryParameters: {'user_id': userId, 'limit': limit},
      );

      if (res.statusCode != 200) return const [];

      final data = res.data;

      final list = (data is Map<String, dynamic>)
          ? (data['data'] as List<dynamic>? ?? const [])
          : (data as List<dynamic>? ?? const []);

      return list
          .whereType<Map<String, dynamic>>()
          .map((j) => FastingHistoryItem.fromJson(j))
          .toList();
    } catch (e) {
      return const [];
    }
  }

  // ---------------------------------------------------
  // FASTING – SUMMARY
  // ---------------------------------------------------
  Future<List<FastingSummaryDay>> getFastingSummary() async {
    final userId = await _resolveUserId();

    try {
      final Response res = await _api.dio.get(
        '/lifestyle/fasting/summary',
        queryParameters: {'user_id': userId},
      );

      if (res.statusCode != 200) return const [];

      final data = res.data;
      final rows = (data is Map<String, dynamic>)
          ? (data['data']?['rows'] as List<dynamic>? ?? const [])
          : (data as List<dynamic>? ?? const []);

      return rows
          .whereType<Map<String, dynamic>>()
          .map((j) => FastingSummaryDay.fromJson(j))
          .toList();
    } catch (e) {
      return const [];
    }
  }

  // ---------------------------------------------------
  // FASTING – COMMANDS
  // ---------------------------------------------------
  Future<bool> startFast({
    required String fastKind,
    required String protocol,
    required double targetHours,
    String? notes,
  }) async {
    final userId = await _resolveUserId();

    final body = {
      'user_id': userId,
      'fast_kind': fastKind,
      'protocol': protocol,
      'target_hours': targetHours,
      'start_at': 'NOW()',
    };

    if (notes != null && notes.trim().isNotEmpty) {
      body['notes'] = notes.trim();
    }

    try {
      final Response res = await _api.dio.post(
        '/lifestyle/fasting/start',
        data: body,
      );

      return res.statusCode == 200 && res.data['ok'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> endFast({String reason = 'completed'}) async {
    final userId = await _resolveUserId();

    final body = {
      'user_id': userId,
      'end_at': 'NOW()',
      'reason': reason,
    };

    try {
      final Response res = await _api.dio.post(
        '/lifestyle/fasting/end',
        data: body,
      );

      return res.statusCode == 200 && res.data['ok'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addFastingEvent({
    required String eventType,
    int? valueNum,
    String? valueText,
  }) async {
    final userId = await _resolveUserId();

    final body = {
      'user_id': userId,
      'event_at': 'NOW()',
      'event_type': eventType,
    };

    if (valueNum != null) body['value_num'] = valueNum;
    if (valueText != null && valueText.trim().isNotEmpty) {
      body['value_text'] = valueText.trim();
    }

    try {
      final Response res = await _api.dio.post(
        '/lifestyle/fasting/event',
        data: body,
      );

      return res.statusCode == 200 && res.data['ok'] == true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------
  // MEAL PLANS
  // ---------------------------------------------------

  /// List all templates
  Future<List<MealPlan>> getAllMealPlans({int limit = 50}) async {
    try {
      final Response res = await _api.dio.get(
        '/lifestyle/mealplans',
        queryParameters: {'limit': limit},
      );

      if (res.statusCode != 200) return const [];

      final data = res.data;

      List<dynamic> rows;
      if (data is List) {
        rows = data;
      } else if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is List) {
          rows = inner;
        } else if (inner is Map<String, dynamic>) {
          rows = (inner['rows'] as List<dynamic>? ?? const []);
        } else {
          rows = (data['rows'] as List<dynamic>? ?? const []);
        }
      } else {
        return const [];
      }

      return rows
          .whereType<Map<String, dynamic>>()
          .map((j) => MealPlan.fromJson(j))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Get user's assigned plans
  Future<List<MealPlanAssignment>> getUserMealPlans() async {
    final userId = await _resolveUserId();

    try {
      final Response res =
          await _api.dio.get('/lifestyle/mealplans/user/$userId');

      if (res.statusCode != 200) return const [];

      final data = res.data;
      final plans =
          (data is Map<String, dynamic> ? data['plans'] : null)
              as List<dynamic>? ??
          const [];

      return plans
          .whereType<Map<String, dynamic>>()
          .map((j) => MealPlanAssignment.fromJson(j))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Get detailed plan
  Future<MealPlan?> getMealPlanById(int planId) async {
    try {
      final Response res =
          await _api.dio.get('/lifestyle/mealplans/$planId');

      if (res.statusCode != 200) return null;

      final data = res.data;
      if (data is! Map<String, dynamic>) return null;

      final inner = data['data'];
      if (inner is! Map<String, dynamic>) return null;

      return MealPlan.fromJson(inner);
    } catch (_) {
      return null;
    }
  }

  /// Assign a plan to user
  /// Correct endpoint: POST /lifestyle/mealplans/assign
  Future<bool> assignMealPlan(int mealPlanId, {DateTime? startDate}) async {
    final userId = await _resolveUserId();

    final body = {
      'user_id': userId,
      'meal_plan_id': mealPlanId,
      'start_date':
          (startDate ?? DateTime.now()).toIso8601String().split('T')[0],
      'active': 1,
    };

    try {
      final Response res = await _api.dio.post(
        '/lifestyle/mealplans/assign',
        data: body,
      );

      return res.statusCode == 201 && res.data['ok'] == true;
    } catch (e) {
      return false;
    }
  }

  /// NEW: recommend a template based on target calories
  /// Calls GET /lifestyle/mealplans/recommend?target_calories=XXXX
  Future<MealPlanRecommendation?> recommendMealPlanForCalories(
    double targetCalories,
  ) async {
    final int target = targetCalories.round();

    try {
      final Response res = await _api.dio.get(
        '/lifestyle/mealplans/recommend',
        queryParameters: {
          'target_calories': target,
        },
      );

      if (res.statusCode != 200) return null;

      final data = res.data;
      if (data is! Map<String, dynamic>) return null;
      if (data['ok'] != true) return null;

      // Full payload parsed via model:
      return MealPlanRecommendation.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
