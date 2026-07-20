import 'package:flutter/material.dart';
import 'package:setu_core/setu_core.dart';

/// Full-screen success confirmation (Stitch `action_successful`): a soft
/// floating check, a headline + reassurance line, a primary continue action
/// and an optional secondary action. Reusable for any "you're all set" moment
/// — adding an elder, completing setup, finishing a booking.
class ActionSuccessScreen extends StatelessWidget {
  const ActionSuccessScreen({
    required this.title,
    required this.message,
    this.primaryLabel = 'Continue',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.tagline = 'All done',
    super.key,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: SetuColors.paperLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SetuSpacing.xl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Soft haloed check.
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    SetuColors.verifiedLight.withValues(alpha: 0.22),
                    SetuColors.verifiedLight.withValues(alpha: 0.06),
                  ]),
                ),
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                        color: SetuColors.verifiedLight,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 44),
                  ),
                ),
              ),
              const SizedBox(height: SetuSpacing.xl),
              Text(title,
                  textAlign: TextAlign.center,
                  style: t.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: SetuSpacing.sm),
              Text(message,
                  textAlign: TextAlign.center,
                  style: t.bodyLarge?.copyWith(
                      color: SetuColors.mutedLight, height: 1.45)),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      onPrimary ?? () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(primaryLabel),
                ),
              ),
              if (secondaryLabel != null) ...[
                const SizedBox(height: SetuSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onSecondary,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(secondaryLabel!),
                  ),
                ),
              ],
              const SizedBox(height: SetuSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_outlined,
                      size: 16, color: SetuColors.verifiedLight),
                  const SizedBox(width: 6),
                  Text(tagline.toUpperCase(),
                      style: const TextStyle(
                          color: SetuColors.mutedLight,
                          fontSize: 11.5,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
