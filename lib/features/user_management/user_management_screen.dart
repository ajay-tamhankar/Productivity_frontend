import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import 'user_management_model.dart';
import 'user_management_provider.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(userManagementControllerProvider.notifier).loadUsers(),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _cleanError(Object error) {
    final raw = error.toString();
    const prefix = 'Exception:';
    if (raw.startsWith(prefix)) {
      return raw.substring(prefix.length).trim();
    }
    return raw;
  }

  List<ManagedUser> _applyFilters(UserManagementState state) {
    final query = state.query.trim().toLowerCase();
    return state.users.where((user) {
      final role = user.role.toUpperCase();
      if (state.roleFilter != 'ALL' && state.roleFilter != role) {
        return false;
      }
      if (query.isEmpty) return true;

      return user.name.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query) ||
          role.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openCreateUserDialog() async {
    final result = await showDialog<_UserFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UserFormDialog(mode: _UserFormMode.create),
    );
    if (result == null) return;

    try {
      await ref.read(userManagementControllerProvider.notifier).createUser(
            username: result.username!,
            name: result.name,
            password: result.password!,
            role: result.role,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User created successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(e))),
      );
    }
  }

  Future<void> _openEditUserDialog(ManagedUser user) async {
    final result = await showDialog<_UserFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UserFormDialog(
        mode: _UserFormMode.edit,
        initialUser: user,
      ),
    );
    if (result == null) return;

    final payload = <String, dynamic>{};
    if (result.name.trim() != user.name.trim()) {
      payload['name'] = result.name.trim();
    }
    if (result.role.trim().toUpperCase() != user.role.trim().toUpperCase()) {
      payload['role'] = result.role.trim().toUpperCase();
    }
    final updatedPassword = (result.password ?? '').trim();
    if (updatedPassword.isNotEmpty) {
      payload['password'] = updatedPassword;
    }

    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes detected.')),
      );
      return;
    }

    try {
      await ref.read(userManagementControllerProvider.notifier).updateUser(
            id: user.id,
            payload: payload,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(e))),
      );
    }
  }

  Future<void> _viewUserDetails(ManagedUser user) async {
    try {
      final details = await ref
          .read(userManagementControllerProvider.notifier)
          .getUserById(user.id);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('User Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailLine('Name', details.name),
              const SizedBox(height: 8),
              _detailLine('Username', details.username),
              const SizedBox(height: 8),
              _detailLine('Role', details.role),
              const SizedBox(height: 8),
              _detailLine('ID', details.id),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(e))),
      );
    }
  }

  Future<void> _deleteUser(ManagedUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Delete "${user.name}" (${user.username})? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB32929),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(userManagementControllerProvider.notifier).deleteUser(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(e))),
      );
    }
  }

  Widget _detailLine(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Color(0xFF2E3641), fontSize: 14),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value.trim().isEmpty ? '-' : value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userManagementControllerProvider);
    final users = _applyFilters(state);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(userManagementControllerProvider.notifier).loadUsers(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Create User',
            onPressed: _openCreateUserDialog,
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFF2FFF9), Color(0xFFF7F2FF)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () => ref.read(userManagementControllerProvider.notifier).loadUsers(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2EAF6)),
                ),
                child: const Text(
                  'Create and manage operators, supervisors, and admins.',
                  style: TextStyle(color: Color(0xFF5D6A7A)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2EAF6)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged:
                          ref.read(userManagementControllerProvider.notifier).setQuery,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search by name, username, role',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: state.roleFilter,
                      decoration: const InputDecoration(
                        labelText: 'Role Filter',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Roles')),
                        DropdownMenuItem(
                          value: AppConstants.roleAdmin,
                          child: Text('Admin'),
                        ),
                        DropdownMenuItem(
                          value: AppConstants.roleSupervisor,
                          child: Text('Supervisor'),
                        ),
                        DropdownMenuItem(
                          value: AppConstants.roleOperator,
                          child: Text('Operator'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        ref.read(userManagementControllerProvider.notifier).setRoleFilter(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (state.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2F1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFD2CF)),
                  ),
                  child: Text(
                    _cleanError(state.errorMessage!),
                    style: const TextStyle(
                      color: Color(0xFF8A2A24),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (state.isLoading && state.users.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2EAF6)),
                  ),
                  child: const ShimmerCenteredPlaceholder(
                    verticalPadding: 10,
                    titleWidth: 200,
                    subtitleWidth: 130,
                  ),
                )
              else if (users.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2EAF6)),
                  ),
                  child: Text(
                    state.users.isEmpty
                        ? 'No users available. Create your first user.'
                        : 'No users found for current filters.',
                    style: const TextStyle(color: Color(0xFF5D6A7A)),
                  ),
                )
              else
                ...users.map(
                  (user) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _UserCard(
                      user: user,
                      onView: () => _viewUserDetails(user),
                      onEdit: () => _openEditUserDialog(user),
                      onDelete: () => _deleteUser(user),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateUserDialog,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Create User'),
      ),
      bottomNavigationBar:
          state.isSubmitting ? const ShimmerLinearBar(height: 2) : null,
    );
  }
}

class _UserCard extends StatelessWidget {
  final ManagedUser user;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final role = user.role.toUpperCase();
    final roleColor =
        role == AppConstants.roleAdmin
            ? const Color(0xFF1E63D3)
            : role == AppConstants.roleSupervisor
                ? const Color(0xFF7A4DCC)
                : const Color(0xFF0E9F6E);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  user.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: roleColor.withOpacity(0.24)),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '@${user.username}',
            style: const TextStyle(
              color: Color(0xFF5D6A7A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(
                icon: Icons.visibility_outlined,
                label: 'View',
                color: const Color(0xFF1E63D3),
                onTap: onView,
              ),
              _ActionChip(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: const Color(0xFF127944),
                onTap: onEdit,
              ),
              _ActionChip(
                icon: Icons.delete_outline,
                label: 'Delete',
                color: const Color(0xFFB32929),
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _UserFormMode { create, edit }

class _UserFormResult {
  final String? username;
  final String name;
  final String? password;
  final String role;

  const _UserFormResult({
    this.username,
    required this.name,
    this.password,
    required this.role,
  });
}

class _UserFormDialog extends StatefulWidget {
  final _UserFormMode mode;
  final ManagedUser? initialUser;

  const _UserFormDialog({
    required this.mode,
    this.initialUser,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _passwordCtrl;
  late String _role;

  bool get _isCreate => widget.mode == _UserFormMode.create;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.initialUser?.username ?? '');
    _nameCtrl = TextEditingController(text: widget.initialUser?.name ?? '');
    _passwordCtrl = TextEditingController();
    _role = widget.initialUser?.role.toUpperCase() ?? AppConstants.roleOperator;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    if (!_isCreate) return null;
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Username is required.';
    if (text.length < 3) return 'Username must be at least 3 characters.';
    return null;
  }

  String? _validateName(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Name is required.';
    if (text.length < 2) return 'Name must be at least 2 characters.';
    return null;
  }

  String? _validatePassword(String? value) {
    final text = (value ?? '').trim();
    if (_isCreate && text.isEmpty) return 'Password is required.';
    if (text.isNotEmpty && text.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Navigator.of(context).pop(
      _UserFormResult(
        username: _isCreate ? _usernameCtrl.text.trim() : null,
        name: _nameCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(_isCreate ? 'Create User' : 'Edit User'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _usernameCtrl,
                  enabled: _isCreate,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: _validateUsername,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: _validateName,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _isCreate ? 'Password' : 'New Password (Optional)',
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: AppConstants.roleAdmin, child: Text('ADMIN')),
                    DropdownMenuItem(
                      value: AppConstants.roleSupervisor,
                      child: Text('SUPERVISOR'),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.roleOperator,
                      child: Text('OPERATOR'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _role = value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isCreate ? 'Create' : 'Apply Changes'),
        ),
      ],
    );
  }
}
