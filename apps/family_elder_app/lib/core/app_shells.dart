import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import 'offline_banner.dart';
import 'providers.dart';
import '../features/assistant/presentation/assistant_screen.dart';
import '../features/booking/presentation/booking_screen.dart';
import '../features/caregiver_onboarding/presentation/caregiver_registration_screen.dart';
import '../features/earnings/presentation/earnings_screen.dart';
import '../features/elder_home/presentation/elder_home_screen.dart';
import '../features/family_home/presentation/family_home_screen.dart';
import '../features/job_queue/presentation/job_queue_screen.dart';
import '../features/job_queue/presentation/pending_verification_screen.dart';
import '../features/medications/presentation/medications_screen.dart';
import '../features/notifications/presentation/notification_inbox_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/auth/data/auth_repository.dart';

/// The SETU navigation backbone: one persistent bottom-navigation shell per
/// role, wiring the existing screens into the tabs from the approved flow.
/// Family: Home · Care · AI · Reports · Profile.
/// Elder:  Home · Medicines · Reports · Profile (SOS + Talk are on Home).
/// Caregiver: Home · Earnings · Profile.

/// A branded top bar for the two "home body" screens (which have no Scaffold
/// of their own), carrying the SETU wordmark, a notifications bell and
/// settings — matching the finalized home design.
class _HomeTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _HomeTopBar();
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: SetuSpacing.lg,
      title: Row(children: [
        const Icon(Icons.holiday_village_outlined,
            color: SetuColors.accentLight),
        const SizedBox(width: 8),
        Text('SETU',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: SetuColors.accentLight, fontWeight: FontWeight.w800)),
      ]),
      actions: [
        _NotificationBell(),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).asData?.value ?? 0;
    return IconButton(
      tooltip: 'Notifications',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
      onPressed: () => context.push('/notifications'),
    );
  }
}

Widget _homeTab(Widget body) =>
    Scaffold(appBar: const _HomeTopBar(), body: SafeArea(child: body));

/// Shown in an elder-scoped tab when a family member hasn't added anyone yet.
class _NeedElder extends StatelessWidget {
  const _NeedElder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SetuEmptyState(
        icon: Icons.person_add_alt_1_outlined,
        title: 'Add someone first',
        message: 'Add the parent or elder you care for from the Home tab.',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Family shell
// ---------------------------------------------------------------------------
class FamilyShell extends ConsumerStatefulWidget {
  const FamilyShell({super.key});
  @override
  ConsumerState<FamilyShell> createState() => _FamilyShellState();
}

class _FamilyShellState extends ConsumerState<FamilyShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final elders = ref.watch(myElderProfilesProvider).asData?.value ?? [];
    final elderId = elders.isNotEmpty ? elders.first.id : null;
    const needElder = _NeedElder();

    final tabs = <Widget>[
      _homeTab(const FamilyHomeScreen()),
      elderId == null ? needElder : BookingScreen(elderId: elderId),
      elderId == null ? needElder : AssistantScreen(elderId: elderId),
      elderId == null ? needElder : ReportsScreen(elderId: elderId),
      const ProfileMenuScreen(),
    ];

    return Scaffold(
      // Soft colour blobs bleeding off the corners, from the SETU designs.
      // Behind everything, so every tab in the shell gets them without each
      // screen having to opt in.
      body: Stack(
        children: [
          const SetuAtmosphere(),
          Column(children: [
            const OfflineBanner(),
            Expanded(child: IndexedStack(index: _index, children: tabs)),
          ]),
        ],
      ),
      bottomNavigationBar: SetuNavSurface(child: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.favorite_outline),
              selectedIcon: Icon(Icons.favorite_rounded),
              label: 'Care'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'AI'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Reports'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      )),
    );
  }
}

// ---------------------------------------------------------------------------
// Elder shell
// ---------------------------------------------------------------------------
class ElderShell extends ConsumerStatefulWidget {
  const ElderShell({super.key});
  @override
  ConsumerState<ElderShell> createState() => _ElderShellState();
}

class _ElderShellState extends ConsumerState<ElderShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final elders = ref.watch(myElderProfilesProvider).asData?.value ?? [];
    final elderId = elders.isNotEmpty ? elders.first.id : null;
    const needElder = _NeedElder();

    final tabs = <Widget>[
      _homeTab(const ElderHomeScreen()),
      elderId == null ? needElder : MedicationsScreen(elderId: elderId),
      elderId == null ? needElder : ReportsScreen(elderId: elderId),
      const ProfileMenuScreen(),
    ];

    return Scaffold(
      // Soft colour blobs bleeding off the corners, from the SETU designs.
      // Behind everything, so every tab in the shell gets them without each
      // screen having to opt in.
      body: Stack(
        children: [
          const SetuAtmosphere(),
          Column(children: [
            const OfflineBanner(),
            Expanded(child: IndexedStack(index: _index, children: tabs)),
          ]),
        ],
      ),
      bottomNavigationBar: SetuNavSurface(child: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication_rounded),
              label: 'Medicines'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Reports'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      )),
    );
  }
}

/// Caregivers who haven't applied see the registration form; applied-but-not-
/// activated see "pending"; active caregivers get the bottom-nav shell. Keeps
/// those full-screen states free of tab chrome.
class CaregiverGate extends ConsumerWidget {
  const CaregiverGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(myCaregiverProvider).when(
          data: (caregiver) {
            if (caregiver == null) return const CaregiverRegistrationScreen();
            if (!caregiver.active) return const PendingVerificationScreen();
            return const CaregiverShell();
          },
          loading: () => const Scaffold(body: SetuLoading()),
          error: (e, s) => const Scaffold(body: SetuErrorState()),
        );
  }
}

// ---------------------------------------------------------------------------
// Caregiver shell (only reached when the caregiver is active)
// ---------------------------------------------------------------------------
class CaregiverShell extends StatefulWidget {
  const CaregiverShell({super.key});
  @override
  State<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends State<CaregiverShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      const JobQueueScreen(),
      const EarningsScreen(),
      const ProfileMenuScreen(),
    ];
    return Scaffold(
      // Soft colour blobs bleeding off the corners, from the SETU designs.
      // Behind everything, so every tab in the shell gets them without each
      // screen having to opt in.
      body: Stack(
        children: [
          const SetuAtmosphere(),
          Column(children: [
            const OfflineBanner(),
            Expanded(child: IndexedStack(index: _index, children: tabs)),
          ]),
        ],
      ),
      bottomNavigationBar: SetuNavSurface(child: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work),
              label: 'Visits'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Earnings'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      )),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile menu (Profile tab)
// ---------------------------------------------------------------------------
class ProfileMenuScreen extends ConsumerWidget {
  const ProfileMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elders = ref.watch(myElderProfilesProvider).asData?.value ?? [];
    final elderId = elders.isNotEmpty ? elders.first.id : null;
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final name = profile?['display_name'] as String? ?? 'Your account';

    Widget item(IconData icon, String label, VoidCallback onTap,
        {Color color = SetuColors.accentLight}) {
      return ListTile(
        leading: SetuIconChip(icon: icon, color: color, size: 18),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right, color: SetuColors.mutedLight),
        onTap: onTap,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        children: [
          Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: SetuColors.accentLight.withValues(alpha: 0.15),
              child: const Icon(Icons.person, color: SetuColors.accentLight),
            ),
            const SizedBox(width: SetuSpacing.md),
            Expanded(
                child: Text(name,
                    style: Theme.of(context).textTheme.titleLarge)),
          ]),
          const SizedBox(height: SetuSpacing.lg),
          item(Icons.card_membership_outlined, 'Subscription & plans', () {
            if (elderId != null) context.push('/elder/$elderId/care-plans');
          }),
          if (elderId != null) ...[
            item(Icons.favorite_outline, 'Health profile',
                () => context.push('/elder/$elderId/health-profile'),
                color: SetuColors.peachLight),
            item(Icons.folder_shared_outlined, 'Medical records',
                () => context.push('/elder/$elderId/documents'),
                color: SetuColors.lavenderLight),
            item(Icons.privacy_tip_outlined, 'What you can see (consent)',
                () => context.push('/elder/$elderId/consent'),
                color: SetuColors.lavenderLight),
            item(Icons.group_outlined, 'Family access',
                () => context.push('/elder/$elderId/family')),
          ],
          item(Icons.settings_outlined, 'Settings & privacy',
              () => context.push('/settings')),
          item(Icons.notifications_none_rounded, 'Notifications',
              () => context.push('/notifications'),
              color: SetuColors.peachLight),
          const SizedBox(height: SetuSpacing.lg),
          OutlinedButton.icon(
            onPressed: () =>
                AuthRepository(ref.read(supabaseClientProvider)).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
