import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/constants/app_constants.dart';
import '../repositories/local_storage_repository.dart';
import 'auth_session_events.dart';

part 'api_client.g.dart';

class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path, {dynamic data}) async {
    return _dio.delete(path, data: data);
  }
}

@riverpod
Dio dio(Ref ref) {
  final prefs = ref.watch(localStorageRepositoryProvider);
  final sessionEvents = ref.watch(authSessionEventsProvider);

  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 45),
    sendTimeout: const Duration(seconds: 30),
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = prefs.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      options.headers.putIfAbsent('Accept', () => 'application/json');
      return handler.next(options);
    },
    onError: (DioException e, handler) async {
      final status = e.response?.statusCode;
      final isLoginCall = e.requestOptions.path.contains('/auth/login');
      if (status == 401 && !isLoginCall) {
        // Token rejected by server — drop session so the router
        // redirects the user back to the login screen.
        await prefs.clearAll();
        sessionEvents.notifyUnauthorized();
      }
      return handler.next(e);
    },
  ));

  return dio;
}

@riverpod
ApiClient apiClient(Ref ref) {
  return ApiClient(ref.watch(dioProvider));
}
