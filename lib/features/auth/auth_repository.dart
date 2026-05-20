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

      final raw = response.data;
      if (raw is! Map) {
        throw const AuthException('Unexpected login response from server.');
      }
      final data = Map<String, dynamic>.from(raw);

      final token = _extractToken(data);
      if (token == null || token.isEmpty) {
        throw const AuthException(
          'Login succeeded but no token was returned by the server.',
        );
      }

      final userJson = _extractUser(data);
      final user = UserModel.fromJson(userJson);

      return UserModel(
        id: user.id,
        username: user.username.isNotEmpty ? user.username : username,
        name: user.name,
        role: user.role,
        token: token,
      );
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      throw AuthException(_mapDioErrorToMessage(e));
    } catch (_) {
      throw const AuthException('Something went wrong. Please try again.');
    }
  }

  String? _extractToken(Map<String, dynamic> data) {
    final candidates = [
      data['token'],
      data['accessToken'],
      data['access_token'],
      data['jwt'],
    ];
    for (final c in candidates) {
      if (c is String && c.trim().isNotEmpty) return c.trim();
    }
    // Nested under 'data' (some backends wrap responses).
    final nested = data['data'];
    if (nested is Map) {
      return _extractToken(Map<String, dynamic>.from(nested));
    }
    return null;
  }

  Map<String, dynamic> _extractUser(Map<String, dynamic> data) {
    final user = data['user'] ?? data['profile'];
    if (user is Map) {
      return Map<String, dynamic>.from(user);
    }
    final nested = data['data'];
    if (nested is Map) {
      final m = Map<String, dynamic>.from(nested);
      final nestedUser = m['user'] ?? m['profile'];
      if (nestedUser is Map) {
        return Map<String, dynamic>.from(nestedUser);
      }
      // Flat shape under data.
      return m;
    }
    // Flat shape at top level (id/role/etc. alongside token).
    return data;
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
