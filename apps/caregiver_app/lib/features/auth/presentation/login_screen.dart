import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../data/auth_repository.dart';

enum _AuthMode { phone, email }

enum _Step { enter, enterCode }

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
  _Step _step = _Step.enter;
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
      _step = _Step.enter;
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
      setState(() => _error =
          err.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
        await _repo.sendOtp(_phoneController.text.trim());
        setState(() => _step = _Step.enterCode);
      });

  Future<void> _verifyCode() => _run(() async {
        await _repo.verifyOtp(
            phone: _phoneController.text.trim(),
            token: _codeController.text.trim());
        await _repo.ensureProfile();
        if (mounted) context.go('/home');
      });

  Future<void> _emailSignIn() => _run(() async {
        await _repo.signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text);
        await _repo.ensureProfile();
        if (mounted) context.go('/home');
      });

  Future<void> _emailSignUp() => _run(() async {
        final res = await _repo.signUpWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text);
        if (res.session == null) {
          setState(() => _notice =
              'Check your email to confirm your account, then log in.');
          return;
        }
        await _repo.ensureProfile();
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
                    Text('Setu — Caregiver',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 24),
                    SegmentedButton<_AuthMode>(
                      segments: const [
                        ButtonSegment(
                            value: _AuthMode.phone, label: Text('Phone')),
                        ButtonSegment(
                            value: _AuthMode.email, label: Text('Email')),
                      ],
                      selected: {_mode},
                      onSelectionChanged:
                          _busy ? null : (s) => _setMode(s.first),
                    ),
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
                    ..._fields(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _fields() {
    if (_mode == _AuthMode.email) {
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
    if (_step == _Step.enterCode) {
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
          onPressed: _busy ? null : _sendCode, child: const Text('Send code')),
    ];
  }
}
