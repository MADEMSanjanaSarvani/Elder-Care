import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import 'offline_banner.dart';
import 'providers.dart';
import '../features/elder_home/presentation/elder_home_screen.dart';
import '../features/family_home/presentation/family_home_screen.dart';
import '../features/medications/presentation/medications_screen.dart';
import '../features/notifications/presentation/notification_inbox_screen.dart';
import '../features/medications/presentation/today_screen.dart';
import '../features/auth/data/auth_repository.dart';

/// The CareHive navigation backbone: one persistent bottom-navigation shell
/// per role.
///
/// Family: Home · Today · Medicines · Profile.
/// Elder:  Home · Medicines · Profile — Home already *is* today's doses, with
///         SOS pinned over the bottom of it.
///
/// There is no third shell. The caregiver role, its tabs and its gate are gone
/// with the marketplace they served.

/// A branded top bar for the two "home body" screens (which have no Scaffold
/// of their own), carrying the CareHive wordmark, a notifications bell and
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
        Text('CareHive',
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

/// Shown in a tab that needs a person before it can show anything.
///
/// Worded per role. Telling somebody using CareHive for themselves to "add the
/// parent or elder you care for" is the same confusion that made the old
/// first-run screen a dead end — they are the person, and the thing they
/// actually need is one tap away on the Home tab.
class _NeedElder extends StatelessWidget {
  const _NeedElder({required this.forSelf});

  final bool forSelf;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SetuEmptyState(
        icon: Icons.person_add_alt_1_outlined,
        title: forSelf ? 'Finish setting up' : 'Add someone first',
        message: forSelf
            ? 'Open the Home tab and tap Get started — it takes one tap.'
            : 'Add the parent or elder you care for from the Home tab.',
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
    const needElder = _NeedElder(forSelf: false);

    final tabs = <Widget>[
      _homeTab(const FamilyHomeScreen()),
      // Family get the same Today list the elder sees, and can mark from it.
      // A daughter who watched her father take his tablet should not have to
      // wait for him to find the phone before the record says so — the mark is
      // stamped `family_proxy` so the difference stays visible afterwards.
      elderId == null ? needElder : TodayScreen(elderId: elderId),
      elderId == null ? needElder : MedicationsScreen(elderId: elderId),
      const ProfileMenuScreen(),
    ];

    return Scaffold(
      // Soft colour blobs bleeding off the corners, from the CareHive designs.
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
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today_rounded),
              label: 'Today'),
          NavigationDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication_rounded),
              label: 'Medicines'),
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
    const needElder = _NeedElder(forSelf: true);

    final tabs = <Widget>[
      _homeTab(const ElderHomeScreen()),
      elderId == null ? needElder : MedicationsScreen(elderId: elderId),
      const ProfileMenuScreen(),
    ];

    return Scaffold(
      // Soft colour blobs bleeding off the corners, from the CareHive designs.
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
          if (elderId != null) ...[
            item(Icons.badge_outlined, 'Medical ID',
                () => context.push('/elder/$elderId/medical-id')),
            item(Icons.timeline_outlined, 'Timeline',
                () => context.push('/elder/$elderId/timeline'),
                color: SetuColors.lavenderLight),
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
