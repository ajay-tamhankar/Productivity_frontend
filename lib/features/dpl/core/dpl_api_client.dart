import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/local_storage_repository.dart';
import '../../auth/auth_provider.dart';

/// A dedicated Dio instance for the DPL module.
///
/// The existing app Dio is hard-bound to the productivity base URL,
/// so DPL gets its own client. It still reads the **same JWT** written
/// by the existing login flow (via [LocalStorageRepository]), which is
/// the whole reason we don't need a separate DPL login screen.
final dplDioProvider = Provider<Dio>((ref) {
  final prefs = ref.watch(localStorageRepositoryProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.dplApiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      headers: const {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = prefs.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        // Auto-logout on:
        //   * Any 401 — including the multi-tenant `ORG_MISMATCH` 401
        //     fired when an admin reassigns the user's org server-side.
        //   * 500 with code `NO_ORGANIZATION` — the user record itself
        //     is misconfigured; no authenticated screen can be served
        //     until an admin attaches an org, so we kick the session.
        final status = error.response?.statusCode;
        final body = error.response?.data;
        String? apiCode;
        if (body is Map) {
          final raw = body['code'];
          if (raw is String && raw.trim().isNotEmpty) {
            apiCode = raw.trim();
          }
        }
        final shouldLogout = status == 401 ||
            (status != null && status >= 500 && apiCode == 'NO_ORGANIZATION');
        if (shouldLogout) {
          // Fire and forget; we don't want to block the error pipeline.
          Future.microtask(() {
            try {
              ref.read(authControllerProvider.notifier).logout();
            } catch (_) {
              // Provider may have been disposed — safe to ignore.
            }
          });
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
});
