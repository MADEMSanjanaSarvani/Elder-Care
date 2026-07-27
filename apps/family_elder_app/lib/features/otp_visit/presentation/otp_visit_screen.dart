import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../../visit_tools/presentation/visit_tools_section.dart';
import '../data/otp_visit_repository.dart';

/// One-handed use standing in a doorway (PRD Part 3 §17): a single OTP
/// field and a single action button, nothing else competing for attention.
/// Matches the Stitch "otp_verification" design: a shield/lock icon badge,
/// a bold headline, and the six-box code field — restyled visually, same
/// single `_otpController` feeding the same real startVisit/endVisit calls
/// as before. Six boxes is exactly right here because every code SETU issues
/// is six digits: `bookings-match` generates `100000 + random * 900000`,
/// which cannot produce any other length.
///
/// The Stitch mock's subtitle says "we've sent a code to your mobile" and
/// shows a resend countdown — SETU's real flow has no SMS-to-caregiver step;
/// the family member reads the code out at the door, and there's no resend
/// function to back a countdown, so neither is reproduced. The mock's
/// countdown is also broken on its own terms: it formats minutes as `'0$m'`,
/// so anything from ten minutes up renders as "010:00".
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

  OtpVisitRepository get _repo =>
      OtpVisitRepository(ref.read(supabaseClientProvider));

  @override
  void dispose() {
    // Neither of these was being released. A caregiver opens this screen once
    // per visit, several times a day, for as long as the app stays resident.
    _otpController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.startVisit(
          bookingId: widget.bookingId, otp: _otpController.text.trim());
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
      await _repo.endVisit(
          bookingId: widget.bookingId, otp: _otpController.text.trim());
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
      body: ListView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: SetuColors.peachLight.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined,
                  color: SetuColors.accentLight, size: 36),
            ),
          ),
          const SizedBox(height: SetuSpacing.lg),
          Text('Verify Your Identity',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: SetuSpacing.sm),
          const Text(
              'Ask the family for the visit code to keep their data secure. '
              'The same code both starts and ends the visit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: SetuColors.mutedLight, height: 1.4)),
          const SizedBox(height: SetuSpacing.xl),
          // Six boxes, one per digit, as the design has it. The code is read
          // aloud at the door — "four… seven… two…" — and a box per digit is
          // how somebody keeps their place in a spoken number with a bag in
          // the other hand. Still one controller behind the glass, so
          // startVisit/endVisit are untouched.
          SetuCodeField(controller: _otpController, enabled: !_busy),
          const SizedBox(height: SetuSpacing.lg),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(SetuSpacing.sm),
              decoration: BoxDecoration(
                color: SetuColors.sosLight.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SetuColors.sosLight.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 18, color: SetuColors.sosLight),
                  const SizedBox(width: SetuSpacing.sm),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: SetuColors.sosLight))),
                ],
              ),
            ),
            const SizedBox(height: SetuSpacing.md),
          ],
          if (_message != null) ...[
            Container(
              padding: const EdgeInsets.all(SetuSpacing.sm),
              decoration: BoxDecoration(
                color: SetuColors.verifiedLight.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: SetuColors.verifiedLight.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 18, color: SetuColors.verifiedLight),
                  const SizedBox(width: SetuSpacing.sm),
                  Expanded(
                      child: Text(_message!,
                          style: const TextStyle(color: SetuColors.verifiedLight))),
                ],
              ),
            ),
            const SizedBox(height: SetuSpacing.md),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : _start,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Start visit'),
          ),
          const SizedBox(height: SetuSpacing.sm),
          OutlinedButton(
              onPressed: _busy ? null : _end, child: const Text('End visit')),
          const SizedBox(height: SetuSpacing.lg),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 14, color: SetuColors.mutedLight),
              SizedBox(width: 6),
              Text('SECURED BY SETU AUTHENTICATION',
                  style: TextStyle(
                      color: SetuColors.mutedLight,
                      fontSize: 10.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          if (_visitEnded && !_summarySubmitted) ...[
            const SizedBox(height: SetuSpacing.lg),
            const Divider(),
            const SizedBox(height: SetuSpacing.md),
            const Text(
                'What happened during the visit? (a few lines is enough)'),
            const SizedBox(height: SetuSpacing.sm),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Helped with breakfast, went for a short walk, blood pressure checked...',
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
          VisitToolsSection(bookingId: widget.bookingId),
        ],
      ),
    );
  }
}
