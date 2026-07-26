import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Sends the user back to the role picker.
///
/// Role is a column, not a route: the home router swaps entire shells based on
/// it, so the screen a caregiver lands on is the root of the widget tree with
/// nothing beneath it to pop. Someone who chose "caregiver" and wanted to
/// change their mind therefore had no back button anywhere, Android back
/// dropped them out of the app, and the only visible escape was Sign out —
/// which is a drastic answer to "wrong button."
void backToRolePicker(WidgetRef ref) {
  ref.read(roleReselectProvider.notifier).state = true;
}

/// A back arrow for a screen that is the root of a role's shell.
///
/// [PopScope] is the important half: without it, the arrow works but the
/// hardware back gesture — which is how most people on Android actually go
/// back — still exits the app.
class RolePickerBackButton extends ConsumerWidget {
  const RolePickerBackButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BackButton(
      onPressed: () => backToRolePicker(ref),
    );
  }
}

/// Wraps a role-root screen so the system back gesture returns to the role
/// picker instead of closing the app.
class RoleRootPopScope extends ConsumerWidget {
  const RoleRootPopScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      // Never let the pop through — there is nothing below this screen, so
      // allowing it just closes the app.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) backToRolePicker(ref);
      },
      child: child,
    );
  }
}
