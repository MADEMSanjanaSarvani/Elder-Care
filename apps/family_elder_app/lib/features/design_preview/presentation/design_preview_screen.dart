import 'package:flutter/material.dart';
import 'package:setu_core/setu_core.dart';

/// Design Preview — the exact Stitch screen renders, bundled as images and
/// shown pixel-for-pixel inside the app. This is a reference/demo gallery (the
/// real, working screens live in the rest of the app); here you see the
/// original designs exactly as Stitch produced them.
class DesignPreviewScreen extends StatelessWidget {
  const DesignPreviewScreen({super.key});

  // asset base name (under assets/stitch/) -> friendly title, in journey order.
  static const _screens = <MapEntry<String, String>>[
    MapEntry('splash_onboarding', 'Splash & Onboarding'),
    MapEntry('login', 'Login'),
    MapEntry('create_account', 'Create Account'),
    MapEntry('forgot_password', 'Forgot Password'),
    MapEntry('otp_verification', 'OTP Verification'),
    MapEntry('role_selection', 'Role Selection'),
    MapEntry('family_dashboard', 'Family Dashboard'),
    MapEntry('elder_home_screen', 'Elder Home'),
    MapEntry('daily_timeline_peace_of_mind_1', 'Daily Timeline'),
    MapEntry('daily_timeline_peace_of_mind_2', 'Daily Timeline (2)'),
    MapEntry('wellness_summary_1', 'Wellness Summary'),
    MapEntry('wellness_summary_2', 'Wellness Summary (2)'),
    MapEntry('elder_wellness_activities', 'Wellness Activities'),
    MapEntry('add_medication_1', 'Add Medication'),
    MapEntry('add_medication_2', 'Add Medication (2)'),
    MapEntry('emergency_medical_profile_1', 'Medical Profile'),
    MapEntry('emergency_medical_profile_2', 'Medical Profile (2)'),
    MapEntry('emergency_sos_active', 'SOS Active'),
    MapEntry('notification_center', 'Notification Center'),
    MapEntry('no_notifications', 'No Notifications'),
    MapEntry('ai_companion', 'AI Companion'),
    MapEntry('premium_plans', 'Premium Plans'),
    MapEntry('secure_payment', 'Secure Payment'),
    MapEntry('settings_dashboard', 'Settings'),
    MapEntry('family_circle_permissions', 'Family Circle'),
    MapEntry('add_elder_profile', 'Add Elder Profile'),
    MapEntry('caregiver_dashboard', 'Caregiver Dashboard'),
    MapEntry('caregiver_details', 'Caregiver Details'),
    MapEntry('caregiver_marketplace', 'Caregiver Marketplace'),
    MapEntry('doctor_consultations', 'Doctor Consultations'),
    MapEntry('visit_task_checklist', 'Visit Checklist'),
    MapEntry('action_successful', 'Action Successful'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design Preview')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(SetuSpacing.lg),
            padding: const EdgeInsets.all(SetuSpacing.md),
            decoration: BoxDecoration(
              color: SetuColors.lavenderLight.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: SetuColors.lavenderLight.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.palette_outlined,
                    color: SetuColors.lavenderLight, size: 20),
                SizedBox(width: SetuSpacing.sm),
                Expanded(
                  child: Text(
                    'The original Stitch designs, exactly as drawn. Tap any '
                    'screen to view it full-size. The live app screens are in '
                    'the rest of SETU.',
                    style:
                        TextStyle(color: SetuColors.mutedLight, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                  SetuSpacing.lg, 0, SetuSpacing.lg, SetuSpacing.lg),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: SetuSpacing.md,
                crossAxisSpacing: SetuSpacing.md,
                childAspectRatio: 0.62,
              ),
              itemCount: _screens.length,
              itemBuilder: (context, i) {
                final s = _screens[i];
                return _ScreenCard(asset: s.key, title: s.value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenCard extends StatelessWidget {
  const _ScreenCard({required this.asset, required this.title});
  final String asset;
  final String title;

  @override
  Widget build(BuildContext context) {
    final path = 'assets/stitch/$asset.png';
    return Material(
      color: SetuColors.paperRaisedLight,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => _FullScreen(path: path, title: title),
        )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: SetuColors.borderLight),
                ),
                child: Image.asset(path,
                    fit: BoxFit.cover, alignment: Alignment.topCenter),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: SetuSpacing.sm, vertical: SetuSpacing.sm),
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreen extends StatelessWidget {
  const _FullScreen({required this.path, required this.title});
  final String path;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.asset(path, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
