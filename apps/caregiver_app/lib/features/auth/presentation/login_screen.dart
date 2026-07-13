import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../data/auth_repository.dart';

enum _Step { enterPhone, enterCode }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  _Step _step = _Step.enterPhone;
  String? _error;
  bool _busy = false;

  AuthRepository get _repo => AuthRepository(ref.read(supabaseClientProvider));

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.sendOtp(_phoneController.text.trim());
      setState(() => _step = _Step.enterCode);
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.verifyOtp(
          phone: _phoneController.text.trim(),
          token: _codeController.text.trim());
      await _repo.ensureProfile();
      if (mounted) context.go('/home');
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Setu — Caregiver',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 12),
                  ],
                  if (_step == _Step.enterPhone) ...[
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
                  ] else ...[
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
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
