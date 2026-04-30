import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'education_models.dart';

/// Repository wrapper for Education API
/// Now supports dynamic categories from backend.
class EducationRepository {
  final Dio _dio = ApiClient().dio;

  /* ===============================================
     GET /education/categories?lang=en|bn
     Returns list of EducationCategory
     =============================================== */
  Future<List<EducationCategory>> getCategories({
    required String lang,
  }) async {
    try {
      final response = await _dio.get(
        '/education/categories',
        queryParameters: {'lang': lang},
      );

      final data = response.data;

      if (data == null || data['categories'] == null) {
        throw Exception('Invalid category response');
      }

      return EducationCategory.listFromJson(data['categories']);
    } catch (e, st) {
      debugPrint('Error fetching education categories: $e');
      debugPrint('Stack trace: $st');
      throw Exception('Failed to fetch education categories.');
    }
  }

  /* ===============================================
     GET /education/contents?category=CODE&lang=en|bn
     =============================================== */
  Future<List<EducationContent>> getContentsByCategory({
    required String categoryCode,
    required String lang,
  }) async {
    try {
      final response = await _dio.get(
        '/education/contents',
        queryParameters: {
          'category': categoryCode,
          'lang': lang,
        },
      );

      final data = response.data;

      if (data == null || data['items'] == null) {
        throw Exception('Invalid response from server');
      }

      final List<dynamic> items = data['items'];
      return EducationContent.listFromJson(items);
    } catch (e, st) {
      debugPrint('Error fetching education contents: $e');
      debugPrint('Stack trace: $st');
      throw Exception('Failed to fetch education contents');
    }
  }

  /* ===============================================
     GET /education/contents/:id?lang=en|bn
     =============================================== */
  Future<EducationContent> getContentById({
    required int id,
    required String lang,
  }) async {
    try {
      final response = await _dio.get(
        '/education/contents/$id',
        queryParameters: {'lang': lang},
      );

      final data = response.data;
      return EducationContent.fromJson(data);
    } catch (e, st) {
      debugPrint('Error fetching content by ID: $e');
      debugPrint('Stack trace: $st');
      throw Exception('Failed to fetch content details');
    }
  }
}
