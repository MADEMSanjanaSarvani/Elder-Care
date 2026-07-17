import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  _AuthMode _mode = _AuthMode.phone;
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

  String _friendly(Object err) {
    final s = err.toString().replaceFirst('Exception: ', '');
    return s.length > 200 ? '${s.substring(0, 200)}…' : s;
  }

  // --- phone ---
  Future<void> _sendCode() => _run(() async {
        await _repo.sendOtp(_phoneController.text.trim());
        setState(() => _step = _LoginStep.enterCode);
      });

  Future<void> _verifyCode() => _run(() async {
        await _repo.verifyOtp(
            phone: _phoneController.text.trim(),
            token: _codeController.text.trim());
        await _afterAuth();
      });

  // --- email ---
  Future<void> _emailSignIn() => _run(() async {
        await _repo.signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text);
        await _afterAuth();
      });

  Future<void> _emailSignUp() => _run(() async {
        final res = await _repo.signUpWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text);
        if (res.session == null) {
          // Email confirmation is ON — no session yet.
          setState(() => _notice =
              'Check your email to confirm your account, then sign in.');
          return;
        }
        await _afterAuth();
      });

  /// Shared post-authentication routing: existing profile → home, otherwise
  /// pick a role first.
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Setu',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 24),
                    if (_step != _LoginStep.chooseRole) _modeToggle(),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    if (_notice != null) ...[
                      const SizedBox(height: 12),
                      Text(_notice!),
                    ],
                    const SizedBox(height: 16),
                    ..._buildFields(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeToggle() {
    return SegmentedButton<_AuthMode>(
      segments: const [
        ButtonSegment(value: _AuthMode.phone, label: Text('Phone')),
        ButtonSegment(value: _AuthMode.email, label: Text('Email')),
      ],
      selected: {_mode},
      onSelectionChanged: _busy ? null : (s) => _setMode(s.first),
    );
  }

  List<Widget> _buildFields() {
    if (_step == _LoginStep.chooseRole) {
      return [
        const Text('Who is signing in?'),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _busy ? null : () => _chooseRole('elder'),
            child: const Text("I'm the senior citizen")),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : () => _chooseRole('family_member'),
          child: const Text("I'm a family member"),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : () => _chooseRole('caregiver'),
          child: const Text("I'm a caregiver"),
        ),
      ];
    }
    return _mode == _AuthMode.phone ? _phoneFields() : _emailFields();
  }

  List<Widget> _phoneFields() {
    if (_step == _LoginStep.enterCode) {
      return [
        Text('Enter the code sent to ${_phoneController.text}'),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Code'),
        ),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _busy ? null : _verifyCode,
            child: const Text('Verify code')),
      ];
    }
    return [
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
            labelText: 'Phone number', hintText: '+91XXXXXXXXXX'),
      ),
      const SizedBox(height: 16),
      FilledButton(
          onPressed: _busy ? null : _sendCode,
          child: const Text('Send code')),
    ];
  }

  List<Widget> _emailFields() {
    return [
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _passwordController,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Password'),
      ),
      const SizedBox(height: 16),
      FilledButton(
          onPressed: _busy ? null : _emailSignIn,
          child: const Text('Log in')),
      const SizedBox(height: 8),
      OutlinedButton(
          onPressed: _busy ? null : _emailSignUp,
          child: const Text('Create account')),
    ];
  }
}
