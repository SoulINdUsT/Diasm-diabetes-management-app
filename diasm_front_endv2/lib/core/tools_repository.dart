
// lib/core/tools_repository.dart

import 'package:dio/dio.dart';
import 'api_client.dart';

class ToolsRepository {
  ToolsRepository._internal();
  static final ToolsRepository instance = ToolsRepository._internal();
  factory ToolsRepository() => instance;

  final Dio _dio = ApiClient().dio;

  // GET /calc/bmi?kg=...&cm=...
  Future<Map<String, dynamic>?> calculateBMI({
    required double weightKg,
    required double heightCm,
  }) async {
    try {
      final res = await _dio.get(
        '/calc/bmi',
        queryParameters: {'kg': weightKg, 'cm': heightCm},
      );
      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // GET /calc/bmr?sex=male|female&age=..&kg=..&cm=..&activity_level=..
  Future<Map<String, dynamic>?> calculateBMR({
    required String sex, // "male" or "female"
    required int age,
    required double weightKg,
    required double heightCm,
    String activityLevel = 'sedentary',
  }) async {
    try {
      final res = await _dio.get(
        '/calc/bmr',
        queryParameters: {
          'sex': sex,
          'age': age,
          'kg': weightKg,
          'cm': heightCm,
          'activity_level': activityLevel,
        },
      );

      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
