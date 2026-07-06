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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.hourglass_top_outlined, size: 48),
              SizedBox(height: SetuSpacing.md),
              Text(
                "You're signed in, but your caregiver verification hasn't been completed yet. "
                "Our team will notify you once it's ready.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
