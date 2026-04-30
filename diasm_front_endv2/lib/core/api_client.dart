
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'auth_storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: _resolveBaseUrl(),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        responseType: ResponseType.json,
        headers: const {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await AuthStorage().getAccessToken();

            // Always set/remove Authorization explicitly
            if (token != null && token.trim().isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            } else {
              options.headers.remove('Authorization');
            }

            // Debug (keep for now)
            debugPrint('➡️ ${options.method} ${options.uri}');
            debugPrint('➡️ Authorization present? ${options.headers.containsKey("Authorization")}');
          } catch (_) {
            options.headers.remove('Authorization');
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('✅ [${response.statusCode}] ${response.requestOptions.uri}');
          handler.next(response);
        },
        onError: (DioException e, handler) {
          debugPrint('❌ DIO ERROR ${e.requestOptions.uri}');
          debugPrint('❌ STATUS: ${e.response?.statusCode}');
          debugPrint('❌ RESPONSE: ${e.response?.data}');
          handler.next(e);
        },
      ),
    );
  }

  String _resolveBaseUrl() {
    const port = 3000;

    // Flutter Web (Chrome): backend is on same machine
    if (kIsWeb) {
      return 'http://localhost:$port/api/v1';
    }

    // Android emulator:
     return 'http://10.0.2.2:$port/api/v1';

    // Real device (replace with your PC IP):
   // const localIp = '192.168.0.104';
   // return 'http://$localIp:$port/api/v1';

    // Render (when used):
    // return 'https://diabetes-backend-hdup.onrender.com/api/v1';
  }
}
