import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/auth_repository.dart';

enum _AuthMode { phone, email }

enum _LoginStep { enter, enterCode }

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

  Future<void> _forgotPassword() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      setState(() =>
          _error = 'Enter your email above first, then tap "Forgot password".');
      return Future.value();
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset('assets/icon/icon.png',
                          width: 84, height: 84),
                    ),
                  ),
                  const SizedBox(height: SetuSpacing.lg),
                  Text('CareHive',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 6),
                  Text(
                    'A home away from home for the ones who raised us.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: SetuColors.mutedLight),
                  ),
                  const SizedBox(height: SetuSpacing.md),
                  Text(
                    'Book trusted caregivers, track medicines, get daily '
                    'check-ins, and one-tap emergency help — everything to '
                    'care for your parents, together, from anywhere.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: SetuColors.mutedLight, height: 1.5),
                  ),
                  const SizedBox(height: SetuSpacing.md),
                  const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniFeature(Icons.volunteer_activism_outlined, 'Caregivers'),
                      _MiniFeature(Icons.medication_outlined, 'Medicines'),
                      _MiniFeature(Icons.favorite_outline, 'Check-ins'),
                      _MiniFeature(Icons.sos_outlined, 'SOS help'),
                    ],
                  ),
                  const SizedBox(height: SetuSpacing.xl),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(SetuSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                              child: Text('or',
                                  style:
                                      TextStyle(color: SetuColors.mutedLight)),
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
                  ),
                  const SizedBox(height: SetuSpacing.lg),
                ],
              ),
            ),
          ),
        ),
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
          labelText: 'Password',
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
      ] else ...[
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : _forgotPassword,
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
                ? 'Create account'
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

/// A small feature pill used on the welcome/login header to tell newcomers
/// what CareHive is at a glance.
class _MiniFeature extends StatelessWidget {
  const _MiniFeature(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: SetuColors.accentLight.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: SetuColors.accentLight.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: SetuColors.accentLight),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: SetuColors.accentLight)),
        ],
      ),
    );
  }
}
