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
class ActionSuccessScreen extends StatefulWidget {
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
  State<ActionSuccessScreen> createState() => _ActionSuccessScreenState();
}

class _ActionSuccessScreenState extends State<ActionSuccessScreen>
    with SingleTickerProviderStateMixin {
  // Six seconds, deliberately slow. This screen appears the moment somebody
  // has finished adding their parent to the app — the motion should read as
  // breathing, not as a loading state.
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

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
              // Concentric rings rising on a slow float, from the Stitch
              // success design. The rings drift at slightly different phases,
              // which is what stops it reading as a single rigid object.
              SizedBox(
                width: 250,
                height: 250,
                child: AnimatedBuilder(
                  animation: _float,
                  builder: (context, child) {
                    final eased = Curves.easeInOut.transform(_float.value);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        _ring(230, 0.10, -10 * eased),
                        _ring(186, 0.16, -13 * eased),
                        Transform.translate(
                          offset: Offset(0, -15 * eased),
                          child: child,
                        ),
                      ],
                    );
                  },
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color:
                              SetuColors.accentLight.withValues(alpha: 0.18),
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
                ),
              ),
              const SizedBox(height: SetuSpacing.xl),
              Text(widget.title,
                  textAlign: TextAlign.center,
                  style: t.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: SetuSpacing.sm),
              Text(widget.message,
                  textAlign: TextAlign.center,
                  style: t.bodyLarge?.copyWith(
                      color: SetuColors.mutedLight, height: 1.45)),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      widget.onPrimary ?? () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(widget.primaryLabel),
                ),
              ),
              if (widget.secondaryLabel != null) ...[
                const SizedBox(height: SetuSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onSecondary,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(widget.secondaryLabel!),
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
                  Text(widget.tagline.toUpperCase(),
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

/// One of the drifting outline rings behind the check badge.
Widget _ring(double size, double alpha, double dy) {
  return Transform.translate(
    offset: Offset(0, dy),
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: SetuColors.accentLight.withValues(alpha: alpha), width: 2),
      ),
    ),
  );
}
