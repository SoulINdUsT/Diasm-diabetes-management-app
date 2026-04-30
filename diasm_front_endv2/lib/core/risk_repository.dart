import 'package:dio/dio.dart';
import 'api_client.dart';
import 'risk_models.dart';
import 'risk_submission_model.dart';

class RiskRepository {
  RiskRepository._internal();
  static final RiskRepository _instance = RiskRepository._internal();
  factory RiskRepository() => _instance;

  final Dio _dio = ApiClient().dio;

  // ---------------------------------------------
  // GET /risk/assessments/latest
  // ---------------------------------------------
  Future<RiskAssessment?> getLatestAssessment() async {
    try {
      final res = await _dio.get('/risk/assessments/latest');

      final data = res.data;
      if (data == null) return null;

      if (data is Map<String, dynamic>) {
        return RiskAssessment.fromJson(data);
      } else if (data is Map) {
        return RiskAssessment.fromJson(
          Map<String, dynamic>.from(data),
        );
      } else {
        throw Exception('Unexpected response format for latest assessment');
      }
    } on DioException catch (e) {
      final raw = e.response?.data;
      String msg = 'Failed to fetch latest assessment';

      if (raw is Map && raw['message'] is String) {
        msg = raw['message'];
      } else if (e.message != null) {
        msg = e.message!;
      }

      throw Exception(msg);
    } catch (e) {
      throw Exception('Failed to fetch latest assessment: $e');
    }
  }

  // ---------------------------------------------
  // POST /risk/assessments
  // ---------------------------------------------
  Future<RiskAssessment> submitAssessment(
    int toolId,
    List<RiskAnswerPayload> answers,
  ) async {
    try {
      final body = <String, dynamic>{
        'toolId': toolId,
        'answers': answers.map((a) => a.toJson()).toList(),
      };

      final res = await _dio.post(
        '/risk/assessments',
        data: body,
      );

      final data = res.data;
      if (data is Map<String, dynamic>) {
        return RiskAssessment.fromJson(data);
      } else if (data is Map) {
        return RiskAssessment.fromJson(
          Map<String, dynamic>.from(data),
        );
      } else {
        throw Exception('Unexpected response format for submit assessment');
      }
    } on DioException catch (e) {
      String msg = 'Failed to submit assessment';

      final raw = e.response?.data;
      if (raw is Map && raw['message'] is String) {
        msg = raw['message'];
      } else if (e.message != null) {
        msg = e.message!;
      }

      throw Exception(msg);
    } catch (e) {
      throw Exception('Failed to submit assessment: $e');
    }
  }
}
