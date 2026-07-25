import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/auth_repository.dart';

/// Where a password-reset link lands. Supabase re-opens the app with a
/// short-lived recovery session; the router forces us here so the user can
/// actually choose a new password before reaching anything else.
class SetNewPasswordScreen extends ConsumerStatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  ConsumerState<SetNewPasswordScreen> createState() =>
      _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends ConsumerState<SetNewPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pw = _password.text;
    if (pw.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    if (pw != _confirm.text) {
      setState(() => _error = 'The two passwords don\'t match.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthRepository(ref.read(supabaseClientProvider)).updatePassword(pw);
      if (!mounted) return;
      // Recovery is over — let the router send them on to the app.
      ref.read(passwordRecoveryProvider.notifier).state = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. You\'re all set.')),
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not update the password. The link may have expired — '
            'request a new one from the login screen.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a new password')),
      body: ListView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        children: [
          const SetuIconChip(
              icon: Icons.lock_reset, color: SetuColors.accentLight, size: 28),
          const SizedBox(height: SetuSpacing.lg),
          Text('Set a new password',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: SetuSpacing.sm),
          const Text(
            'Pick something you\'ll remember. At least 8 characters.',
            style: TextStyle(color: SetuColors.mutedLight, height: 1.4),
          ),
          const SizedBox(height: SetuSpacing.xl),
          TextField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: SetuSpacing.md),
          TextField(
            controller: _confirm,
            obscureText: _obscure,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: SetuSpacing.md),
            Container(
              padding: const EdgeInsets.all(SetuSpacing.md),
              decoration: BoxDecoration(
                color: SetuColors.peachLight.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(_error!,
                  style: const TextStyle(
                      color: SetuColors.peachLight, height: 1.35)),
            ),
          ],
          const SizedBox(height: SetuSpacing.xl),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save new password'),
            ),
          ),
        ],
      ),
    );
  }
}
