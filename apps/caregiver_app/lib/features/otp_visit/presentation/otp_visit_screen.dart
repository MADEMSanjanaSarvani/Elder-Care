import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/otp_visit_repository.dart';

/// One-handed use standing in a doorway (PRD Part 3 §17): a single OTP
/// field and a single action button, nothing else competing for attention.
class OtpVisitScreen extends ConsumerStatefulWidget {
  const OtpVisitScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  ConsumerState<OtpVisitScreen> createState() => _OtpVisitScreenState();
}

class _OtpVisitScreenState extends ConsumerState<OtpVisitScreen> {
  final _otpController = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _message;

  OtpVisitRepository get _repo => OtpVisitRepository(ref.read(supabaseClientProvider));

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.startVisit(bookingId: widget.bookingId, otp: _otpController.text.trim());
      setState(() => _message = 'Visit started.');
      ref.invalidate(myBookingsProvider);
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _end() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.endVisit(bookingId: widget.bookingId, otp: _otpController.text.trim());
      setState(() => _message = 'Visit completed. Payout has been scheduled.');
      ref.invalidate(myBookingsProvider);
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visit')),
      body: Padding(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ask the family for the visit code to start or end.'),
            const SizedBox(height: SetuSpacing.md),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Visit code'),
            ),
            const SizedBox(height: SetuSpacing.md),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: SetuSpacing.sm),
            ],
            if (_message != null) ...[
              Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
              const SizedBox(height: SetuSpacing.sm),
            ],
            FilledButton(onPressed: _busy ? null : _start, child: const Text('Start visit')),
            const SizedBox(height: SetuSpacing.sm),
            OutlinedButton(onPressed: _busy ? null : _end, child: const Text('End visit')),
          ],
        ),
      ),
    );
  }
}
