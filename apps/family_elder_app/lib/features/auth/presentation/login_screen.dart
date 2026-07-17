import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/auth_repository.dart';

enum _AuthMode { phone, email }

enum _LoginStep { enter, enterCode, chooseRole }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  _AuthMode _mode = _AuthMode.email;
  _LoginStep _step = _LoginStep.enter;
  String? _error;
  String? _notice;
  bool _busy = false;

  AuthRepository get _repo => AuthRepository(ref.read(supabaseClientProvider));

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
  bool _emailFieldsValid() {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return false;
    }
    return true;
  }

  Future<void> _emailSignIn() {
    if (!_emailFieldsValid()) return Future.value();
    return _run(() async {
      await _repo.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text);
      await _afterAuth();
    });
  }

  Future<void> _emailSignUp() {
    if (!_emailFieldsValid()) return Future.value();
    return _run(() async {
      final res = await _repo.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text);
      if (res.session == null) {
        setState(() => _notice =
            'Check your email to confirm your account, then log in.');
        return;
      }
      await _afterAuth();
    });
  }

  Future<void> _afterAuth() async {
    final hasProfile = await _repo.hasProfile();
    if (hasProfile) {
      if (mounted) context.go('/home');
    } else {
      setState(() => _step = _LoginStep.chooseRole);
    }
  }

  Future<void> _chooseRole(String role) => _run(() async {
        await _repo.ensureProfile(role: role, preferredLanguage: 'en');
        if (mounted) context.go('/home');
      });

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
                          if (_step != _LoginStep.chooseRole) ...[
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
                          ],
                          if (_error != null) _banner(_error!, isError: true),
                          if (_notice != null) _banner(_notice!),
                          ..._buildFields(),
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
    if (_step == _LoginStep.chooseRole) {
      return [
        Text('Who is signing in?',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: SetuSpacing.md),
        FilledButton.icon(
            onPressed: _busy ? null : () => _chooseRole('family_member'),
            icon: const Icon(Icons.family_restroom),
            label: const Text("I'm a family member")),
        const SizedBox(height: SetuSpacing.sm),
        OutlinedButton.icon(
            onPressed: _busy ? null : () => _chooseRole('elder'),
            icon: const Icon(Icons.elderly),
            label: const Text("I'm the senior citizen")),
        const SizedBox(height: SetuSpacing.sm),
        OutlinedButton.icon(
            onPressed: _busy ? null : () => _chooseRole('caregiver'),
            icon: const Icon(Icons.medical_services_outlined),
            label: const Text("I'm a caregiver")),
      ];
    }
    return _mode == _AuthMode.email ? _emailFields() : _phoneFields();
  }

  List<Widget> _emailFields() {
    return [
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
        obscureText: true,
        decoration: const InputDecoration(
            labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
      ),
      const SizedBox(height: SetuSpacing.xs),
      const Text('New here? Tap "Create account". Password must be 6+ characters.',
          style: TextStyle(fontSize: 12, color: SetuColors.mutedLight)),
      const SizedBox(height: SetuSpacing.md),
      FilledButton(
          onPressed: _busy ? null : _emailSignIn,
          child: Text(_busy ? 'Please wait…' : 'Log in')),
      const SizedBox(height: SetuSpacing.sm),
      OutlinedButton(
          onPressed: _busy ? null : _emailSignUp,
          child: const Text('Create account')),
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
