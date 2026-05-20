import 'package:dio/dio.dart';

import 'dpl_api_response.dart';

/// Centralised conversion of [DioException] / generic errors into
/// a user-friendly [DplApiResponse.error].
class DplErrorMapper {
  const DplErrorMapper._();

  static DplApiResponse<T> fromDio<T>(
    DioException error, {
    required String fallback,
  }) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return DplApiResponse.error(
        'Request timed out. Please check your connection and try again.',
        code: 'TIMEOUT',
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return DplApiResponse.error(
        'Network error, please check connection.',
        code: 'NETWORK',
      );
    }

    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    String? apiMessage;
    String? apiCode;

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final rawMessage = map['error'] ?? map['message'];
      if (rawMessage is String && rawMessage.trim().isNotEmpty) {
        apiMessage = rawMessage.trim();
      }
      final rawCode = map['code'];
      if (rawCode is String && rawCode.trim().isNotEmpty) {
        apiCode = rawCode.trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      apiMessage = data.trim();
    }

    String message;
    switch (statusCode) {
      case 400:
        message = apiMessage ?? 'Please check your input and try again.';
        break;
      case 401:
        message = apiMessage ?? 'Session expired. Please log in again.';
        apiCode ??= 'UNAUTHORIZED';
        break;
      case 403:
        message = apiMessage ??
            "You don't have permission for this action.";
        apiCode ??= 'FORBIDDEN';
        break;
      case 404:
        message = apiMessage ?? 'Record not found.';
        break;
      case 409:
        message = apiMessage ?? 'Conflict — record already exists.';
        apiCode ??= 'CONFLICT';
        break;
      case 422:
        message = apiMessage ?? 'Validation failed.';
        break;
      default:
        if (statusCode != null && statusCode >= 500) {
          message = 'Something went wrong, please try again.';
        } else {
          message = apiMessage ?? fallback;
        }
    }

    return DplApiResponse.error(
      message,
      code: apiCode,
      statusCode: statusCode,
    );
  }

  static DplApiResponse<T> fromObject<T>(
    Object error, {
    required String fallback,
  }) {
    if (error is DioException) {
      return fromDio<T>(error, fallback: fallback);
    }
    return DplApiResponse.error(error.toString().isEmpty
        ? fallback
        : error.toString());
  }
}
