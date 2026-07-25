import 'package:flutter/material.dart';

/// SETU's own illustrations — warm, flat artwork drawn for this app rather
/// than stock photography. A photo of a stranger sitting under "Priya is
/// safe" would read as a picture of the user's actual parent; an
/// illustration carries the warmth without making that claim.
///
/// Regenerate the PNGs with `python3 tools/build_illustrations.py
/// apps/family_elder_app/assets/illustrations`.
abstract final class SetuArt {
  static const _base = 'assets/illustrations';

  /// Two generations side by side — onboarding and the auth screens.
  static Widget family({double height = 200}) =>
      Image.asset('$_base/hero_family.png', height: height);

  /// A soft, blurred wash for the top of the login / sign-up screens.
  static Widget loginBackdrop({double? height}) => Image.asset(
        '$_base/login_backdrop.png',
        height: height,
        fit: BoxFit.cover,
      );

  static Widget emptyNotifications({double height = 150}) =>
      Image.asset('$_base/empty_notifications.png', height: height);

  static Widget emptyTimeline({double height = 150}) =>
      Image.asset('$_base/empty_timeline.png', height: height);

  static Widget emptyMemories({double height = 150}) =>
      Image.asset('$_base/empty_memories.png', height: height);

  /// A heart cradled in hands — bookings, caregivers, care plans.
  static Widget emptyCare({double height = 150}) =>
      Image.asset('$_base/empty_care.png', height: height);
}
