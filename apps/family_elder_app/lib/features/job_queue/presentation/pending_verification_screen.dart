import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/role_exit.dart';

/// Shown when the signed-in user has a `profiles` row but no matching
/// `caregivers` row yet — onboarding/verification (PRD Part 1 §04) is
/// handled by ops, not by a self-serve flow in this app.
///
/// Like the registration form, this is the root of the caregiver shell, so
/// back has to mean "role picker" rather than "close the app". Waiting on a
/// verification that takes days is exactly when someone realises they meant to
/// sign up as a family member instead.
class PendingVerificationScreen extends ConsumerWidget {
  const PendingVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoleRootPopScope(
      child: Scaffold(
        appBar: AppBar(
          leading: const RolePickerBackButton(),
          title: const Text('SETU Care'),
        ),
        body: const SetuEmptyState(
          icon: Icons.verified_user_outlined,
          title: 'Verification in progress',
          message:
              "You're signed in. Our team is completing your caregiver "
              "verification — we'll notify you the moment your jobs are ready.",
        ),
      ),
    );
  }
}
