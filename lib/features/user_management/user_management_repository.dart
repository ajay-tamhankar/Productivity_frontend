import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_services/api_client.dart';
import 'user_management_model.dart';

class UserManagementRepository {
  final ApiClient _apiClient;

  UserManagementRepository(this._apiClient);

  Future<List<ManagedUser>> listUsers() async {
    try {
      final response = await _apiClient.get('/users');
      final rawList = _extractList(response.data);
      return rawList
          .whereType<Map>()
          .map((e) => ManagedUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to load users.'));
    } catch (_) {
      throw Exception('Failed to load users.');
    }
  }

  Future<ManagedUser> getUserById(String id) async {
    try {
      final response = await _apiClient.get('/users/$id');
      final raw = _extractObject(response.data);
      return ManagedUser.fromJson(raw);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to fetch user details.'));
    } catch (_) {
      throw Exception('Failed to fetch user details.');
    }
  }

  Future<void> createUser({
    required String username,
    required String name,
    required String password,
    required String role,
  }) async {
    try {
      await _apiClient.post(
        '/users',
        data: {
          'username': username,
          'name': name,
          'password': password,
          'role': role,
        },
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to create user.'));
    } catch (_) {
      throw Exception('Failed to create user.');
    }
  }

  Future<void> updateUser({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _apiClient.patch('/users/$id', data: payload);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to update user.'));
    } catch (_) {
      throw Exception('Failed to update user.');
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await _apiClient.delete('/users/$id');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to delete user.'));
    } catch (_) {
      throw Exception('Failed to delete user.');
    }
  }

  List<dynamic> _extractList(dynamic responseData) {
    if (responseData is List) return responseData;
    if (responseData is Map) {
      final map = Map<String, dynamic>.from(responseData);
      if (map['data'] is List) return map['data'] as List<dynamic>;
      if (map['users'] is List) return map['users'] as List<dynamic>;
      if (map['items'] is List) return map['items'] as List<dynamic>;
      if (map['results'] is List) return map['results'] as List<dynamic>;
    }
    return const [];
  }

  Map<String, dynamic> _extractObject(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData['data'] is Map<String, dynamic>) {
        return responseData['data'] as Map<String, dynamic>;
      }
      if (responseData['user'] is Map<String, dynamic>) {
        return responseData['user'] as Map<String, dynamic>;
      }
      return responseData;
    }
    throw const FormatException('Unexpected user detail response.');
  }

  String _mapDioError(
    DioException error, {
    required String fallback,
  }) {
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
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        apiMessage = message.trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      apiMessage = data.trim();
    }

    if (statusCode == 400) return apiMessage ?? 'Please check input values.';
    if (statusCode == 401) return apiMessage ?? 'Session expired. Please login again.';
    if (statusCode == 403) return apiMessage ?? 'You do not have permission for this action.';
    if (statusCode == 404) return apiMessage ?? 'User not found.';
    if (statusCode == 409) return apiMessage ?? 'Username already exists.';
    if (statusCode != null && statusCode >= 500) {
      return 'Server is temporarily unavailable. Please try again shortly.';
    }

    return apiMessage ?? fallback;
  }
}

final userManagementRepositoryProvider = Provider<UserManagementRepository>((ref) {
  return UserManagementRepository(ref.watch(apiClientProvider));
});
