import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/constants/app_constants.dart';

part 'local_storage_repository.g.dart';

class LocalStorageRepository {
  final SharedPreferences _prefs;

  LocalStorageRepository(this._prefs);

  Future<void> saveToken(String token) async {
    await _prefs.setString(AppConstants.tokenKey, token);
  }

  String? getToken() {
    return _prefs.getString(AppConstants.tokenKey);
  }

  Future<void> removeToken() async {
    await _prefs.remove(AppConstants.tokenKey);
  }
  
  Future<void> saveUserRole(String role) async {
    await _prefs.setString(AppConstants.userRoleKey, role);
  }
  
  String? getUserRole() {
    return _prefs.getString(AppConstants.userRoleKey);
  }

  Future<void> saveUserId(String userId) async {
    await _prefs.setString(AppConstants.userIdKey, userId);
  }

  String? getUserId() {
    return _prefs.getString(AppConstants.userIdKey);
  }

  Future<void> saveUsername(String username) async {
    await _prefs.setString(AppConstants.usernameKey, username);
  }

  String? getUsername() {
    return _prefs.getString(AppConstants.usernameKey);
  }

  Future<void> saveUserName(String name) async {
    await _prefs.setString(AppConstants.userNameKey, name);
  }

  String? getUserName() {
    return _prefs.getString(AppConstants.userNameKey);
  }

  Future<void> saveUserSession({
    required String userId,
    required String username,
    required String name,
    required String role,
  }) async {
    await Future.wait([
      saveUserId(userId),
      saveUsername(username),
      saveUserName(name),
      saveUserRole(role),
    ]);
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}

@riverpod
Future<SharedPreferences> sharedPreferences(Ref ref) async {
  return await SharedPreferences.getInstance();
}

@riverpod
LocalStorageRepository localStorageRepository(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider).requireValue;
  return LocalStorageRepository(prefs);
}
