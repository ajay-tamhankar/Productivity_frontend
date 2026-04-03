import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_management_model.dart';
import 'user_management_repository.dart';

class UserManagementState {
  final List<ManagedUser> users;
  final bool isLoading;
  final bool isSubmitting;
  final String query;
  final String roleFilter;
  final String? errorMessage;

  const UserManagementState({
    this.users = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.query = '',
    this.roleFilter = 'ALL',
    this.errorMessage,
  });

  UserManagementState copyWith({
    List<ManagedUser>? users,
    bool? isLoading,
    bool? isSubmitting,
    String? query,
    String? roleFilter,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UserManagementState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      query: query ?? this.query,
      roleFilter: roleFilter ?? this.roleFilter,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class UserManagementController extends Notifier<UserManagementState> {
  @override
  UserManagementState build() => const UserManagementState();

  UserManagementRepository get _repo => ref.read(userManagementRepositoryProvider);

  Future<void> loadUsers({bool showLoading = true}) async {
    state = state.copyWith(
      isLoading: showLoading,
      clearError: true,
    );

    try {
      final users = await _repo.listUsers();
      state = state.copyWith(
        users: users,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void setQuery(String value) {
    state = state.copyWith(query: value);
  }

  void setRoleFilter(String role) {
    state = state.copyWith(roleFilter: role);
  }

  Future<void> createUser({
    required String username,
    required String name,
    required String password,
    required String role,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.createUser(
        username: username,
        name: name,
        password: password,
        role: role,
      );
      await loadUsers(showLoading: false);
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<void> updateUser({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.updateUser(id: id, payload: payload);
      await loadUsers(showLoading: false);
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<void> deleteUser(String id) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.deleteUser(id);
      await loadUsers(showLoading: false);
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<ManagedUser> getUserById(String id) {
    return _repo.getUserById(id);
  }
}

final userManagementControllerProvider =
    NotifierProvider<UserManagementController, UserManagementState>(
  UserManagementController.new,
);
