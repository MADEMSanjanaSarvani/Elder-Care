import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/app_build.dart';
import '../../../core/illustrations.dart';
import '../../../core/providers.dart';
import '../../legal/legal_content.dart';
import '../../legal/presentation/legal_screen.dart';
import '../data/auth_repository.dart';

enum _AuthMode { phone, email }

enum _LoginStep { enter, enterCode }

/// Matches the Stitch "login" / "create_account" / "forgot_password"
/// designs: a warm circular app-icon badge, the SETU wordmark, and a
/// rounded card holding the real auth form. Every control here is the
/// same real one from before — Email/Phone tabs, Log in/Create account
/// toggle, the phone-OTP step, Google sign-in, password reset — just
/// restyled to match.
///
/// The Stitch login mock leads with "Get Security Code" (implying a
/// passwordless phone-only flow) and offers Face ID / Touch ID; the
/// create_account mock offers "Continue with Apple". None of that exists
/// in SETU (email+password and phone-OTP are the only sign-in paths, and
/// there's no biometric or Apple sign-in wired up), so those aren't
/// reproduced — only Google sign-in, which is real.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  _AuthMode _mode = _AuthMode.email;
  _LoginStep _step = _LoginStep.enter;
  bool _signUp = false; // false = log in, true = create account
  bool _obscure = true;
  String? _error;
  String? _notice;
  bool _busy = false;

  AuthRepository get _repo => AuthRepository(ref.read(supabaseClientProvider));

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _setMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _step = _LoginStep.enter;
      _error = null;
      _notice = null;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (err) {
      setState(() => _error = _friendly(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Turns raw Supabase auth errors into plain, reassuring messages.
  String _friendly(Object err) {
    final s = err.toString();
    if (s.contains('anonymous')) {
      return 'Please enter your email and password.';
    }
    if (s.contains('phone_provider_disabled') ||
        s.contains('Unsupported phone provider')) {
      return "Phone sign-in isn't set up yet. Please use Email to continue.";
    }
    if (s.contains('Invalid login credentials')) {
      return 'Wrong email or password. Try again, or create an account.';
    }
    if (s.contains('already registered')) {
      return 'This email already has an account — use Log in instead.';
    }
    if (s.contains('Password should be')) {
      return 'Password must be at least 6 characters.';
    }
    if (s.contains('valid email')) {
      return 'Please enter a valid email address.';
    }
    final m = s
        .replaceFirst('AuthApiException(message: ', '')
        .replaceFirst('AuthException(message: ', '')
        .replaceFirst('Exception: ', '');
    return m.length > 160 ? '${m.substring(0, 160)}…' : m;
  }

  // --- phone ---
  Future<void> _sendCode() {
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your phone number.');
      return Future.value();
    }
    return _run(() async {
      await _repo.sendOtp(_phoneController.text.trim());
      setState(() => _step = _LoginStep.enterCode);
    });
  }

  Future<void> _verifyCode() {
    if (_codeController.text.trim().isEmpty) {
      setState(() => _error = 'Enter the code we sent you.');
      return Future.value();
    }
    return _run(() async {
      await _repo.verifyOtp(
          phone: _phoneController.text.trim(),
          token: _codeController.text.trim());
      await _afterAuth();
    });
  }

  // --- email ---
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Validates the visible email fields for the current intent (log in vs
  /// create account). Returns an error string, or null when everything's ok.
  String? _validateEmailForm() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_signUp && name.isEmpty) return 'Please enter your full name.';
    if (email.isEmpty) return 'Please enter your email address.';
    if (!_emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    if (password.isEmpty) return 'Please enter a password.';
    if (_signUp) {
      if (password.length < 6) {
        return 'Password must be at least 6 characters.';
      }
      if (password != _confirmController.text) {
        return 'Passwords do not match.';
      }
    }
    return null;
  }

  Future<void> _submitEmail() {
    final problem = _validateEmailForm();
    if (problem != null) {
      setState(() => _error = problem);
      return Future.value();
    }
    return _signUp ? _emailSignUp() : _emailSignIn();
  }

  Future<void> _emailSignIn() {
    return _run(() async {
      await _repo.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text);
      await _afterAuth();
    });
  }

  Future<void> _emailSignUp() {
    return _run(() async {
      final res = await _repo.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );
      if (res.session == null) {
        setState(() => _notice =
            'Almost there — check your email to confirm your account, then log in.');
        return;
      }
      await _afterAuth();
    });
  }

  Future<void> _sendPasswordReset(String email) {
    return _run(() async {
      await _repo.sendPasswordReset(email);
      setState(() => _notice =
          'If an account exists for $email, a reset link is on its way.');
    });
  }

  Future<void> _afterAuth() async {
    // Whether or not a profile exists yet, land on /home; the home router
    // gates brand-new accounts into role selection (ChooseRoleScreen).
    if (mounted) context.go('/home');
  }

  Future<void> _google() {
    return _run(() async {
      final res = await _repo.signInWithGoogle();
      if (res == null) return; // user cancelled the Google chooser
      await _afterAuth();
    });
  }

  Future<void> _showForgotPasswordSheet() async {
    final controller = TextEditingController(text: _emailController.text.trim());
    String? sheetError;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SetuColors.paperLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: SetuSpacing.lg,
              right: SetuSpacing.lg,
              top: SetuSpacing.lg,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + SetuSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: SetuSpacing.lg),
                    decoration: BoxDecoration(
                        color: SetuColors.borderLight,
                        borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                Text('Forgot Password?',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: SetuSpacing.xs),
                const Text(
                    'No worries — it happens to the best of us. We\'ll help '
                    'you get back into your care circle.',
                    style: TextStyle(color: SetuColors.mutedLight, height: 1.4)),
                const SizedBox(height: SetuSpacing.lg),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                ),
                if (sheetError != null) ...[
                  const SizedBox(height: SetuSpacing.sm),
                  Text(sheetError!,
                      style: const TextStyle(
                          color: SetuColors.sosLight, fontSize: 13)),
                ],
                const SizedBox(height: SetuSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final email = controller.text.trim();
                            if (email.isEmpty || !_emailRegex.hasMatch(email)) {
                              setSheetState(() => sheetError =
                                  'Please enter a valid email address.');
                              return;
                            }
                            Navigator.of(sheetContext).pop();
                            await _sendPasswordReset(email);
                          },
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Send Reset Link'),
                  ),
                ),
                const SizedBox(height: SetuSpacing.md),
                Container(
                  padding: const EdgeInsets.all(SetuSpacing.md),
                  decoration: BoxDecoration(
                    color: SetuColors.paperRaisedLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SetuColors.borderLight),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 18, color: SetuColors.mutedLight),
                      const SizedBox(width: SetuSpacing.sm),
                      const Expanded(
                        child: Text(
                            'Your security matters. If you don\'t receive an '
                            'email within a few minutes, check your spam folder.',
                            style: TextStyle(
                                color: SetuColors.mutedLight,
                                fontSize: 12.5,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          // A soft warm wash behind the top of the form, so the first screen
          // reads as light rather than an empty panel.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.42,
            child: SetuArt.loginBackdrop(),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: SetuColors.accentLight.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset('assets/icon/icon.png',
                              width: 64, height: 64),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: SetuSpacing.lg),
                  Text('SETU',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge?.copyWith(
                          color: SetuColors.accentLight,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(
                    "Your parents' safety net.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: SetuColors.inkLight,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'A trusted elder-care ecosystem for families.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: SetuColors.mutedLight),
                  ),
                  const SizedBox(height: 4),
                  Text(kAppBuildLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: SetuColors.mutedLight)),
                  const SizedBox(height: SetuSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(SetuSpacing.lg),
                    decoration: BoxDecoration(
                      color: SetuColors.paperRaisedLight,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: SetuColors.borderLight),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x0F944A18),
                            blurRadius: 24,
                            offset: Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            _mode == _AuthMode.email
                                ? (_signUp ? 'Create Account' : 'Welcome Back')
                                : 'Sign in with phone',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                            _mode == _AuthMode.email
                                ? (_signUp
                                    ? 'Begin your journey in the care circle today.'
                                    : 'Sign in to your care circle.')
                                : 'We\'ll text you a one-time code.',
                            style: const TextStyle(color: SetuColors.mutedLight)),
                        const SizedBox(height: SetuSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<_AuthMode>(
                            segments: const [
                              ButtonSegment(
                                  value: _AuthMode.email,
                                  label: Text('Email'),
                                  icon: Icon(Icons.mail_outline)),
                              ButtonSegment(
                                  value: _AuthMode.phone,
                                  label: Text('Phone'),
                                  icon: Icon(Icons.phone_outlined)),
                            ],
                            selected: {_mode},
                            onSelectionChanged:
                                _busy ? null : (s) => _setMode(s.first),
                          ),
                        ),
                        const SizedBox(height: SetuSpacing.md),
                        if (_error != null) _banner(_error!, isError: true),
                        if (_notice != null) _banner(_notice!),
                        ..._buildFields(),
                        const SizedBox(height: SetuSpacing.md),
                        Row(children: const [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: SetuSpacing.sm),
                            child: Text('OR CONTINUE WITH',
                                style: TextStyle(
                                    color: SetuColors.mutedLight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6)),
                          ),
                          Expanded(child: Divider()),
                        ]),
                        const SizedBox(height: SetuSpacing.md),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _google,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Continue with Google'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SetuSpacing.lg),
                  Center(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _mode = _AuthMode.email;
                                _signUp = !_signUp;
                                _error = null;
                                _notice = null;
                              }),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: _signUp
                                ? 'Already a member? '
                                : 'New to SETU? ',
                            style: const TextStyle(color: SetuColors.mutedLight)),
                        TextSpan(
                            text: _signUp ? 'Log in' : 'Create Account',
                            style: const TextStyle(
                                color: SetuColors.accentLight,
                                fontWeight: FontWeight.w700)),
                      ])),
                    ),
                  ),
                  const SizedBox(height: SetuSpacing.sm),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => LegalScreen(
                                  title: 'Privacy Policy',
                                  body: kPrivacyPolicy,
                                  updated: kPrivacyPolicyUpdated))),
                      child: const Text('Privacy Policy',
                          style: TextStyle(
                              color: SetuColors.mutedLight, fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(String text, {bool isError = false}) {
    final color = isError ? SetuColors.sosLight : SetuColors.verifiedLight;
    return Container(
      margin: const EdgeInsets.only(bottom: SetuSpacing.md),
      padding: const EdgeInsets.all(SetuSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.info_outline,
              size: 18, color: color),
          const SizedBox(width: SetuSpacing.sm),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }

  List<Widget> _buildFields() {
    return _mode == _AuthMode.email ? _emailFields() : _phoneFields();
  }

  List<Widget> _emailFields() {
    return [
      // Intent first: Log in vs Create account — one obvious primary button,
      // so a first-time user is never guessing which action is theirs.
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Log in')),
            ButtonSegment(value: true, label: Text('Create account')),
          ],
          selected: {_signUp},
          onSelectionChanged: _busy
              ? null
              : (s) => setState(() {
                    _signUp = s.first;
                    _error = null;
                    _notice = null;
                  }),
        ),
      ),
      const SizedBox(height: SetuSpacing.md),
      if (_signUp) ...[
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(
              labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
        ),
        const SizedBox(height: SetuSpacing.md),
      ],
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(
            labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
      ),
      const SizedBox(height: SetuSpacing.md),
      TextField(
        controller: _passwordController,
        obscureText: _obscure,
        autofillHints:
            _signUp ? const [AutofillHints.newPassword] : const [AutofillHints.password],
        decoration: InputDecoration(
          labelText: _signUp ? 'Strong password' : 'Password',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      if (_signUp) ...[
        const SizedBox(height: SetuSpacing.md),
        TextField(
          controller: _confirmController,
          obscureText: _obscure,
          decoration: const InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: Icon(Icons.lock_outline)),
        ),
        const SizedBox(height: SetuSpacing.xs),
        const Text('Password must be at least 6 characters.',
            style: TextStyle(fontSize: 12, color: SetuColors.mutedLight)),
        const SizedBox(height: SetuSpacing.sm),
        const Text.rich(TextSpan(
          style: TextStyle(fontSize: 12, color: SetuColors.mutedLight, height: 1.4),
          children: [
            TextSpan(text: 'By creating an account, you agree to SETU\'s '),
            TextSpan(
                text: 'Terms of Service',
                style: TextStyle(
                    color: SetuColors.accentLight, fontWeight: FontWeight.w600)),
            TextSpan(text: ' and '),
            TextSpan(
                text: 'Privacy Policy',
                style: TextStyle(
                    color: SetuColors.accentLight, fontWeight: FontWeight.w600)),
            TextSpan(text: '.'),
          ],
        )),
      ] else ...[
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : _showForgotPasswordSheet,
            child: const Text('Forgot password?'),
          ),
        ),
      ],
      const SizedBox(height: SetuSpacing.md),
      FilledButton(
        onPressed: _busy ? null : _submitEmail,
        child: Text(_busy
            ? 'Please wait…'
            : _signUp
                ? 'Join the Care Circle'
                : 'Log in'),
      ),
    ];
  }

  List<Widget> _phoneFields() {
    if (_step == _LoginStep.enterCode) {
      return [
        Text('Enter the code sent to ${_phoneController.text}',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: SetuSpacing.md),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Code', prefixIcon: Icon(Icons.pin_outlined)),
        ),
        const SizedBox(height: SetuSpacing.lg),
        FilledButton(
            onPressed: _busy ? null : _verifyCode,
            child: Text(_busy ? 'Please wait…' : 'Verify code')),
      ];
    }
    return [
      _banner('Phone sign-in needs SMS setup. If you don\'t receive a code, '
          'use the Email tab.'),
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+91XXXXXXXXXX',
            prefixIcon: Icon(Icons.phone_outlined)),
      ),
      const SizedBox(height: SetuSpacing.lg),
      FilledButton(
          onPressed: _busy ? null : _sendCode,
          child: Text(_busy ? 'Please wait…' : 'Send code')),
    ];
  }
}
