import 'package:flutter/material.dart';
import 'package:setu_core/setu_core.dart';

/// Shown when the signed-in user has a `profiles` row but no matching
/// `caregivers` row yet — onboarding/verification (PRD Part 1 §04) is
/// handled by ops, not by a self-serve flow in this app.
class PendingVerificationScreen extends StatelessWidget {
  const PendingVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SETU Care')),
      body: const SetuEmptyState(
        icon: Icons.verified_user_outlined,
        title: 'Verification in progress',
        message:
            "You're signed in. Our team is completing your caregiver "
            "verification — we'll notify you the moment your jobs are ready.",
      ),
    );
  }
}
