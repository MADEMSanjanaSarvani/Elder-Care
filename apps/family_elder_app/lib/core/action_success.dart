import 'package:flutter/material.dart';
import 'package:setu_core/setu_core.dart';

/// Full-screen success confirmation (Stitch `action_successful`): a soft
/// floating check in SETU's warm brand colour, a bold headline + reassurance
/// line, a primary continue action and an optional secondary action.
/// Reusable for any "you're all set" moment — adding an elder, completing
/// setup, finishing a booking.
///
/// The Stitch mock's checkmark badge overlays a real photo of the elder and
/// caregiver together; since this screen is shared across many unrelated
/// "done!" moments (not just adding an elder), there's no single photo that
/// would be honest to show generically, so the badge stays icon-only.
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
              // Soft haloed check, in SETU's warm brand colour (matches the
              // Stitch design's accent-toned badge).
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: SetuColors.accentLight.withValues(alpha: 0.18),
                      width: 6),
                  gradient: RadialGradient(colors: [
                    SetuColors.accentLight.withValues(alpha: 0.18),
                    SetuColors.accentLight.withValues(alpha: 0.05),
                  ]),
                ),
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                        color: SetuColors.accentLight,
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
                      ?.copyWith(fontWeight: FontWeight.w900)),
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
