/// Tells somebody when the reminders they are relying on will not arrive.
///
/// CareHive's entire promise is "the phone will ring at every dose time". Two
/// Android permissions gate that, both are asked for once on first run, and
/// both can be refused — or revoked months later in Settings — with no signal
/// to the app whatsoever. Before this, that failure was invisible: alarms went
/// on being scheduled, Android went on dropping them, and the person went on
/// trusting a reminder that was never coming. The adherence history would fill
/// with "no record" days and the reason would be nowhere on screen.
///
/// So it is a banner, not a toast, and it does not go away when dismissed —
/// it goes away when the permission is granted. Being naggy about this is the
/// correct behaviour: the alternative is somebody quietly missing medicine.
///
/// It says which of the two is missing, because the fixes are different
/// screens in Android settings and "notifications are off" sends you somewhere
/// that does not contain the "Alarms & reminders" switch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import 'local_reminders.dart';
import 'providers.dart';

/// Re-checked whenever it is invalidated — notably after the app returns from
/// the Android settings screen, so granting the permission clears the banner
/// without needing a restart.
final reminderPermissionsProvider =
    FutureProvider<ReminderPermissions>((ref) async {
  return LocalReminders(ref.watch(supabaseClientProvider)).checkPermissions();
});

class ReminderPermissionBanner extends ConsumerStatefulWidget {
  const ReminderPermissionBanner({super.key});

  @override
  ConsumerState<ReminderPermissionBanner> createState() =>
      _ReminderPermissionBannerState();
}

class _ReminderPermissionBannerState
    extends ConsumerState<ReminderPermissionBanner> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Granting the permission happens in Android's own settings app, so the
    // only way to learn it worked is to look again when we come back.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(reminderPermissionsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(reminderPermissionsProvider).asData?.value;
    // While it is still loading, say nothing. Flashing a scary warning for a
    // moment on every launch is its own kind of dishonesty.
    if (perms == null || perms.allGood) return const SizedBox.shrink();

    final t = Theme.of(context).textTheme.scaledForElderMode();
    final noNotifications = !perms.notificationsEnabled;

    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(SetuSpacing.md),
        decoration: BoxDecoration(
          color: SetuColors.sosLight.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SetuColors.sosLight.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications_off_rounded,
                    color: SetuColors.sosLight, size: 26),
                const SizedBox(width: SetuSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        noNotifications
                            ? 'Your reminders are switched off'
                            : 'Reminders may arrive late',
                        style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: SetuColors.sosLight),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        noNotifications
                            ? 'CareHive cannot show notifications, so no dose '
                                'reminder will appear. Your record still works, '
                                'but the phone will not tell you.'
                            : 'CareHive is not allowed to set exact alarms, so '
                                'Android may delay a reminder by up to an hour.',
                        style: t.bodyMedium?.copyWith(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: SetuSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: SetuColors.sosLight),
                onPressed: () async {
                  await LocalReminders(ref.read(supabaseClientProvider))
                      .requestMissing();
                  ref.invalidate(reminderPermissionsProvider);
                },
                child: const Text('Fix this'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
