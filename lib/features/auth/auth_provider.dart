import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/local_storage_repository.dart';
import '../dpl/core/dpl_api_service.dart';
import 'auth_repository.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  FutureOr<UserModel?> build() async {
    // Init block: check persisted auth session.
    final prefs = ref.read(localStorageRepositoryProvider);
    final token = prefs.getToken();
    final role = prefs.getUserRole();

    if (token != null && role != null) {
      final id = prefs.getUserId() ?? '';
      final username = prefs.getUsername() ?? '';
      final name = prefs.getUserName() ?? '';

      return UserModel(
        id: id,
        username: username,
        name: name,
        role: role,
      );
    }
    return null;
  }

  Future<void> login(String username, String password) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.login(username, password);
      final token = user.token;
      if (token == null || token.isEmpty) {
        throw Exception('Login succeeded but token is missing in response.');
      }
      
      // Save auth data for subsequent authenticated requests.
      final prefs = ref.read(localStorageRepositoryProvider);
      await prefs.saveToken(token);
      await prefs.saveUserSession(
        userId: user.id,
        username: user.username,
        name: user.name,
        role: user.role,
      );

      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    final prefs = ref.read(localStorageRepositoryProvider);
    await prefs.clearAll();
    state = const AsyncValue.data(null);
  }

  /// Logs in against the DPL backend (`/api/v1/dpl/auth/login`) and stores
  /// the returned JWT + user under the same shared-preferences keys the rest
  /// of the app uses. The role is forced to `DPL_MANAGER` if the backend
  /// returns the dpl_manager role in any casing, so the existing router
  /// redirect lands the user on `/dpl/manager`.
  Future<void> loginDpl(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final svc = ref.read(dplApiServiceProvider);
      final res = await svc.login(email, password);
      if (res.isError) {
        throw AuthException(res.error ?? 'DPL login failed.');
      }
      final result = res.data;
      final token = result?.token ?? '';
      if (token.isEmpty) {
        throw const AuthException('DPL login succeeded but token is missing.');
      }

      final profile = result?.user;
      final role = (profile?.role.isNotEmpty ?? false)
          ? AppConstants.normalizeRole(profile!.role)
          : AppConstants.roleDplManager;
      final userId = (profile?.id ?? 0).toString();
      final username = profile?.email ?? email;
      final name = (profile?.name.isNotEmpty ?? false)
          ? profile!.name
          : (profile?.email ?? email);

      final prefs = ref.read(localStorageRepositoryProvider);
      await prefs.saveToken(token);
      await prefs.saveUserSession(
        userId: userId,
        username: username,
        name: name,
        role: role,
      );

      state = AsyncValue.data(UserModel(
        id: userId,
        username: username,
        name: name,
        role: role,
        token: token,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
