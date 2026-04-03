import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart';

Future<void> showChangePasswordDialog(BuildContext context, WidgetRef ref) async {
  final changed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ChangePasswordDialog(),
  );

  if (changed == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed successfully.')),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _oldObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validateOld(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Old password is required.';
    return null;
  }

  String? _validateNew(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'New password is required.';
    if (text.length < 6) return 'New password must be at least 6 characters.';
    if (text == _oldCtrl.text.trim()) return 'New password must be different.';
    return null;
  }

  String? _validateConfirm(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Please confirm new password.';
    if (value!.trim() != _newCtrl.text.trim()) return 'Passwords do not match.';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref.read(authRepositoryProvider).changePassword(
            oldPassword: _oldCtrl.text.trim(),
            newPassword: _newCtrl.text.trim(),
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      final message = e is AuthException ? e.message : e.toString();
      if (!mounted) return;
      setState(() => _errorText = message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorText != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFB4AA)),
                    ),
                    child: Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFF8F1D18),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _oldCtrl,
                  obscureText: _oldObscure,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Old Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _oldObscure = !_oldObscure),
                      icon: Icon(
                        _oldObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: _validateOld,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _newCtrl,
                  obscureText: _newObscure,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    helperText: 'Minimum 6 characters',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _newObscure = !_newObscure),
                      icon: Icon(
                        _newObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: _validateNew,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _confirmObscure,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.verified_user_outlined),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _confirmObscure = !_confirmObscure),
                      icon: Icon(
                        _confirmObscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: _validateConfirm,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.3, color: Colors.white),
                )
              : const Text('Update Password'),
        ),
      ],
    );
  }
}
