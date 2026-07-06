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
  final _notesController = TextEditingController();
  bool _busy = false;
  bool _visitEnded = false;
  bool _summarySubmitted = false;
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
      setState(() {
        _message = 'Visit completed. Payout has been scheduled.';
        _visitEnded = true;
      });
      ref.invalidate(myBookingsProvider);
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _submitSummary() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final summary = await _repo.submitVisitSummary(
        bookingId: widget.bookingId,
        rawNotes: _notesController.text.trim(),
      );
      setState(() {
        _summarySubmitted = true;
        _message = summary != null
            ? 'Summary sent to the family.'
            : "Summary is being reviewed before it's shared with the family.";
      });
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
            if (_visitEnded && !_summarySubmitted) ...[
              const SizedBox(height: SetuSpacing.lg),
              const Divider(),
              const SizedBox(height: SetuSpacing.md),
              const Text('What happened during the visit? (a few lines is enough)'),
              const SizedBox(height: SetuSpacing.sm),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'e.g. Helped with breakfast, went for a short walk, blood pressure checked...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: SetuSpacing.sm),
              FilledButton.icon(
                onPressed: _busy ? null : _submitSummary,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Send visit summary to family'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
