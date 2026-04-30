// lib/core/monitoring_repository.dart
// Repository for Monitoring/metrics backend integration.
// Same style as your RiskRepository/EducationRepository.

import 'package:dio/dio.dart';
import 'api_client.dart';
import 'monitoring_models.dart';

class MonitoringRepository {
  MonitoringRepository._internal();
  static final MonitoringRepository instance =
      MonitoringRepository._internal();
  factory MonitoringRepository() => instance;

  final Dio _dio = ApiClient().dio;

  // ----------------- Dashboard snapshot -----------------
  // GET /metrics/summary/dashboard
  Future<DashboardSnapshot> getDashboardSnapshot() async {
    final res = await _dio.get('/metrics/summary/dashboard');
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return DashboardSnapshot.fromJson(data);
    }
    return DashboardSnapshot();
  }

  // ----------------- Latest glucose (Home card) -----------------
  // GET /metrics/glucose/latest
  Future<LatestGlucoseReading?> getLatestGlucose() async {
    final res = await _dio.get('/metrics/glucose/latest');
    final data = res.data;

    if (data == null) return null;

    if (data is Map<String, dynamic>) {
      return LatestGlucoseReading.fromJson(data);
    }

    // sometimes dio gives Map<dynamic,dynamic>
    if (data is Map) {
      return LatestGlucoseReading.fromJson(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
    }

    return null;
  }

  // ----------------- Glucose daily series -----------------
  // GET /metrics/summary/glucose-daily?from=YYYY-MM-DD&to=YYYY-MM-DD
  Future<List<GlucoseDailyPoint>> getGlucoseDailySeries({
    required String from,
    required String to,
  }) async {
    final res = await _dio.get(
      '/metrics/summary/glucose-daily',
      queryParameters: {'from': from, 'to': to},
    );

    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => GlucoseDailyPoint.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ))
          .toList();
    }
    return [];
  }

  // ----------------- Weight daily series -----------------
  // GET /metrics/summary/weight-daily
  Future<List<WeightDailyPoint>> getWeightDailySeries() async {
    final res = await _dio.get('/metrics/summary/weight-daily');
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => WeightDailyPoint.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ))
          .toList();
    }
    return [];
  }

  // ----------------- Steps weekly series -----------------
  // GET /metrics/summary/steps-weekly?weeks=8
  Future<List<StepsWeeklyPoint>> getStepsWeekly({int weeks = 8}) async {
    final res = await _dio.get(
      '/metrics/summary/steps-weekly',
      queryParameters: {'weeks': weeks},
    );
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => StepsWeeklyPoint.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ))
          .toList();
    }
    return [];
  }

  // ----------------- Create logs (Log Data Form) -----------------
  // POST /metrics/weight
  Future<bool> addWeight(AddWeightPayload payload) async {
    final res = await _dio.post('/metrics/weight', data: payload.toJson());
    return res.statusCode == 200 || res.statusCode == 201;
  }

  // POST /metrics/glucose
  Future<bool> addGlucose(AddGlucosePayload payload) async {
    final res = await _dio.post('/metrics/glucose', data: payload.toJson());
    return res.statusCode == 200 || res.statusCode == 201;
  }

  // POST /metrics/hba1c
  Future<bool> addHbA1c(AddHbA1cPayload payload) async {
    final res = await _dio.post('/metrics/hba1c', data: payload.toJson());
    return res.statusCode == 200 || res.statusCode == 201;
  }

  // POST /metrics/bp
  Future<bool> addBP(AddBPPayload payload) async {
    final res = await _dio.post('/metrics/bp', data: payload.toJson());
    return res.statusCode == 200 || res.statusCode == 201;
  }

  // POST /metrics/lipids
  Future<bool> addLipids(AddLipidsPayload payload) async {
    final res = await _dio.post('/metrics/lipids', data: payload.toJson());
    return res.statusCode == 200 || res.statusCode == 201;
  }

  // POST /metrics/steps
  Future<bool> addSteps(AddStepsPayload payload) async {
    final res = await _dio.post('/metrics/steps', data: payload.toJson());
    return res.statusCode == 200 || res.statusCode == 201;
  }

  // ----------------- Optional list endpoints if needed later -----------------
  Future<Map<String, dynamic>> listWeight({
    int page = 1,
    int limit = 20,
    String? from,
    String? to,
  }) async {
    final res = await _dio.get('/metrics/weight', queryParameters: {
      'page': page,
      'limit': limit,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return (res.data is Map<String, dynamic>)
        ? res.data as Map<String, dynamic>
        : {};
  }

  Future<Map<String, dynamic>> listGlucose({
    int page = 1,
    int limit = 20,
    String? from,
    String? to,
  }) async {
    final res = await _dio.get('/metrics/glucose', queryParameters: {
      'page': page,
      'limit': limit,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return (res.data is Map<String, dynamic>)
        ? res.data as Map<String, dynamic>
        : {};
  }

  Future<Map<String, dynamic>> listHbA1c({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get(
      '/metrics/hba1c',
      queryParameters: {'page': page, 'limit': limit},
    );
    return (res.data is Map<String, dynamic>)
        ? res.data as Map<String, dynamic>
        : {};
  }

  Future<Map<String, dynamic>> listBP({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get(
      '/metrics/bp',
      queryParameters: {'page': page, 'limit': limit},
    );
    return (res.data is Map<String, dynamic>)
        ? res.data as Map<String, dynamic>
        : {};
  }

  Future<Map<String, dynamic>> listLipids({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get(
      '/metrics/lipids',
      queryParameters: {'page': page, 'limit': limit},
    );
    return (res.data is Map<String, dynamic>)
        ? res.data as Map<String, dynamic>
        : {};
  }

  Future<Map<String, dynamic>> listSteps({
    int page = 1,
    int limit = 20,
    String? from,
    String? to,
  }) async {
    final res = await _dio.get('/metrics/steps', queryParameters: {
      'page': page,
      'limit': limit,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return (res.data is Map<String, dynamic>)
        ? res.data as Map<String, dynamic>
        : {};
  }
}
