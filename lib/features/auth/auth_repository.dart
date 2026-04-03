import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/api_services/api_client.dart';
import '../../data/models/user_model.dart';

part 'auth_repository.g.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthRepository {
  final ApiClient _apiClient;
  
  AuthRepository(this._apiClient);

  Future<UserModel> login(String username, String password) async {
    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
        },
      );

      final data = response.data;
      final token = data['token'] as String;
      final userJson = data['user'] as Map<String, dynamic>;

      return UserModel(
        id: userJson['id'],
        username: userJson['username'],
        name: userJson['name'],
        role: userJson['role'],
        token: token,
      );
    } on DioException catch (e) {
      throw AuthException(_mapDioErrorToMessage(e));
    } catch (_) {
      throw const AuthException('Something went wrong. Please try again.');
    }
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (oldPassword.trim().isEmpty) {
      throw const AuthException('Old password is required.');
    }
    if (newPassword.trim().length < 6) {
      throw const AuthException('New password must be at least 6 characters.');
    }

    try {
      await _apiClient.patch(
        '/auth/change-password',
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw AuthException(_mapChangePasswordError(e));
    } catch (_) {
      throw const AuthException('Unable to change password. Please try again.');
    }
  }

  String _mapDioErrorToMessage(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Request timed out. Please check your internet and try again.';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Unable to connect to server. Please check your network.';
    }

    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    String? apiMessage;

    if (data is Map<String, dynamic>) {
      final rawMessage = data['message'];
      if (rawMessage is String && rawMessage.trim().isNotEmpty) {
        apiMessage = rawMessage.trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      apiMessage = data.trim();
    }

    if (statusCode == 401) {
      return apiMessage ?? 'Invalid username or password.';
    }
    if (statusCode == 400) {
      return apiMessage ?? 'Please check your login details and try again.';
    }
    if (statusCode == 403) {
      return apiMessage ?? 'Your account does not have access.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Server is temporarily unavailable. Please try again shortly.';
    }

    return apiMessage ?? 'Login failed. Please try again.';
  }

  String _mapChangePasswordError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Request timed out. Please check your internet and try again.';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Unable to connect to server. Please check your network.';
    }

    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    String? apiMessage;

    if (data is Map<String, dynamic>) {
      final rawMessage = data['message'];
      if (rawMessage is String && rawMessage.trim().isNotEmpty) {
        apiMessage = rawMessage.trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      apiMessage = data.trim();
    }

    if (statusCode == 401) {
      return apiMessage ?? 'Old password is incorrect.';
    }
    if (statusCode == 400) {
      return apiMessage ?? 'Please check your passwords and try again.';
    }
    if (statusCode == 403) {
      return apiMessage ?? 'You are not allowed to change this password.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Server is temporarily unavailable. Please try again shortly.';
    }

    return apiMessage ?? 'Failed to change password. Please try again.';
  }
}

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository(ref.watch(apiClientProvider));
}
