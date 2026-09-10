import 'package:dio/dio.dart';
import 'auth_storage.dart';
import 'session_controller.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient.configured();
  factory ApiClient() => _instance;
  static const defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL', defaultValue: 'http://168.144.125.6/api/v1',
  );
  late final Dio dio;
  late final SessionController session;

  ApiClient.configured({String baseUrl = defaultBaseUrl, AuthStorage? storage,
      Dio? client, Dio? transport}) {
    dio = client ?? Dio(_options(baseUrl));
    session = SessionController(storage: storage ?? AuthStorage(),
        transport: transport ?? Dio(_options(baseUrl)));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (!_eligible(options)) {
          options.headers.remove('Authorization');
          handler.next(options);
          return;
        }
        final generation = options.extra['sessionGeneration'] ?? session.generation;
        if (generation != session.generation || session.record == null ||
            session.status != SessionStatus.authenticated) {
          handler.reject(DioException(requestOptions: options,
              type: DioExceptionType.cancel, error: const SessionChanged()));
          return;
        }
        options.extra['sessionGeneration'] = generation;
        options.headers['Authorization'] = 'Bearer ${session.record!.accessToken}';
        handler.next(options);
      },
      onResponse: (response, handler) {
        final generation = response.requestOptions.extra['sessionGeneration'];
        if (generation != null && generation != session.generation) {
          handler.reject(DioException(requestOptions: response.requestOptions,
              type: DioExceptionType.cancel, error: const SessionChanged()));
          return;
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        if (!_eligible(request) || error.response?.statusCode != 401 ||
            request.extra['sessionRetried'] == true || request.data is Stream ||
            request.cancelToken?.isCancelled == true) {
          handler.next(error);
          return;
        }
        final generation = request.extra['sessionGeneration'];
        final header = request.headers['Authorization'];
        if (generation is! int || header is! String || !header.startsWith('Bearer ')) {
          handler.next(error);
          return;
        }
        try {
          await session.refreshAccess(header.substring(7), generation);
          if (!session.isCurrent(generation)) throw const SessionChanged();
          final retry = request.copyWith(
            data: request.data is FormData ? (request.data as FormData).clone() : request.data,
            extra: {...request.extra, 'sessionRetried': true},
          );
          handler.resolve(await dio.fetch<dynamic>(retry));
        } on DioException catch (refreshError) {
          handler.next(DioException(requestOptions: request,
              response: refreshError.response, type: refreshError.type,
              error: refreshError.error));
        } catch (failure) {
          handler.next(DioException(requestOptions: request,
              type: failure is SessionChanged ? DioExceptionType.cancel : DioExceptionType.unknown,
              error: failure));
        }
      },
    ));
  }

  static BaseOptions _options(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
    responseType: ResponseType.json,
    headers: const {'Content-Type': 'application/json'},
  );

  bool _eligible(RequestOptions request) {
    final base = Uri.parse(dio.options.baseUrl);
    if (request.uri.origin != base.origin) return false;
    final path = request.uri.path.replaceFirst(RegExp(r'/$'), '');
    return !const ['/auth/login', '/auth/register', '/auth/refresh', '/auth/logout']
        .any(path.endsWith);
  }
}
