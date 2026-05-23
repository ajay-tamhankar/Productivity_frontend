import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import '../dpl/core/widgets/vistar_logo.dart';
import 'auth_repository.dart';
import 'auth_provider.dart';

// Vistar brand palette — mirrors DplColors.
const _kBrandPurple = Color(0xFF6B1F8C);
const _kBrandPurpleDark = Color(0xFF4A1163);
const _kBrandOrange = Color(0xFFE54B2A);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _submittedOnce = false;
  String? _inlineError;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _onLogin() {
    FocusScope.of(context).unfocus();
    setState(() => _submittedOnce = true);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _inlineError = null);
    ref.read(authControllerProvider.notifier).login(
          _usernameController.text.trim(),
          _passwordController.text,
        );
  }

  void _onDplLogin() {
    FocusScope.of(context).unfocus();
    setState(() {
      _submittedOnce = false;
      _inlineError = null;
    });
    ref.read(authControllerProvider.notifier).loginDpl(
          'dpl.manager@vistarlogitek.com',
          'ChangeMe@123',
        );
  }

  void _onDplSupervisorLogin() {
    FocusScope.of(context).unfocus();
    setState(() {
      _submittedOnce = false;
      _inlineError = null;
    });
    ref.read(authControllerProvider.notifier).loginDpl(
          'dpl.supervisor1@vistarlogitek.com',
          'ChangeMe@123',
        );
  }

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';
    if (username.isEmpty) return 'Username is required.';
    if (username.length < 3) return 'Username must be at least 3 characters.';
    if (username.length > 40) return 'Username must be under 40 characters.';
    if (username.contains(' ')) return 'Username cannot contain spaces.';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required.';
    if (password.length < 4) return 'Password must be at least 4 characters.';
    if (password.length > 128) return 'Password is too long.';
    return null;
  }

  String _toDisplayError(Object error) {
    if (error is AuthException) {
      return error.message;
    }

    final raw = error.toString();
    const exceptionPrefix = 'Exception: ';
    if (raw.startsWith(exceptionPrefix)) {
      return raw.substring(exceptionPrefix.length).trim();
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen(authControllerProvider, (previous, next) {
      if (!mounted) return;

      final justFailed = previous?.isLoading == true && next.hasError;
      if (justFailed) {
        final message = _toDisplayError(next.error!);
        setState(() => _inlineError = message);

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }

      final justSucceeded = previous?.isLoading == true && next.hasValue && next.value != null;
      if (justSucceeded) {
        final username = next.value!.username;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, $username.'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFBF5FF), Color(0xFFFFF6EC), Color(0xFFF6E6FA)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 860;
              final horizontalPadding = isWide ? 48.0 : 20.0;
              final cardWidth = isWide ? 430.0 : 480.0;

              return Stack(
                children: [
                  Positioned(
                    top: -80,
                    right: -40,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: _kBrandPurple.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -100,
                    left: -20,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        color: _kBrandOrange.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        24,
                        horizontalPadding,
                        24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: cardWidth),
                        child: Card(
                          elevation: 0,
                          color: Colors.white.withOpacity(0.93),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isWide ? 36 : 24),
                            child: AutofillGroup(
                              child: Form(
                                key: _formKey,
                                autovalidateMode: _submittedOnce
                                    ? AutovalidateMode.onUserInteraction
                                    : AutovalidateMode.disabled,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Center(
                                      child: VistarLogo(
                                        height: 96,
                                        showWordmark: true,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      'Vistar Pulse',
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.2,
                                            color: _kBrandPurpleDark,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Sign in to continue tracking production, quality, and shop-floor activity.',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: const Color(0xFF5F6B7A),
                                            height: 1.4,
                                          ),
                                    ),
                                    const SizedBox(height: 24),
                                    if (_inlineError != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFE9E8),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFFFFB1AC),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline, color: Color(0xFFB3261E)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _inlineError!,
                                                style: const TextStyle(
                                                  color: Color(0xFF8F1D18),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    TextFormField(
                                      controller: _usernameController,
                                      focusNode: _usernameFocusNode,
                                      autofillHints: const [AutofillHints.username],
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                                      enabled: !isLoading,
                                      onChanged: (_) {
                                        if (_inlineError != null) {
                                          setState(() => _inlineError = null);
                                        }
                                      },
                                      decoration: const InputDecoration(
                                        labelText: 'Username',
                                        hintText: 'Enter your username',
                                        prefixIcon: Icon(Icons.person_outline),
                                      ),
                                      validator: _validateUsername,
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocusNode,
                                      autofillHints: const [AutofillHints.password],
                                      textInputAction: TextInputAction.done,
                                      enabled: !isLoading,
                                      obscureText: _obscurePassword,
                                      onChanged: (_) {
                                        if (_inlineError != null) {
                                          setState(() => _inlineError = null);
                                        }
                                      },
                                      onFieldSubmitted: (_) => _onLogin(),
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        hintText: 'Enter your password',
                                        prefixIcon: const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                            () => _obscurePassword = !_obscurePassword,
                                          ),
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: _validatePassword,
                                    ),
                                    const SizedBox(height: 22),
                                    SizedBox(
                                      height: 52,
                                      child: FilledButton(
                                        onPressed: isLoading ? null : _onLogin,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: _kBrandPurple,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: isLoading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: Center(
                                                  child: ShimmerButtonDots(
                                                    size: 7,
                                                    spacing: 3.5,
                                                  ),
                                                ),
                                              )
                                            : const Text(
                                                'Sign In',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 48,
                                            child: OutlinedButton.icon(
                                              onPressed: isLoading
                                                  ? null
                                                  : _onDplLogin,
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: _kBrandPurple,
                                                side: const BorderSide(
                                                  color: _kBrandPurple,
                                                  width: 1.4,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                              ),
                                              icon: const Icon(
                                                  Icons.factory_outlined),
                                              label: const Text(
                                                'DPL Manager',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: SizedBox(
                                            height: 48,
                                            child: OutlinedButton.icon(
                                              onPressed: isLoading
                                                  ? null
                                                  : _onDplSupervisorLogin,
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: _kBrandOrange,
                                                side: const BorderSide(
                                                  color: _kBrandOrange,
                                                  width: 1.4,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                              ),
                                              icon: const Icon(
                                                  Icons.engineering_outlined),
                                              label: const Text(
                                                'DPL Supervisor',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Need access help? Contact your supervisor or admin.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF5F6B7A),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
