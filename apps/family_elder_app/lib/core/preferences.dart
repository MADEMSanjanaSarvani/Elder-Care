import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Accessibility + language preferences (PRD Part 8, Batch 5, Modules 19
/// & 20), loaded from `accessibility_preferences` and `profiles.preferred_language`
/// and applied app-wide at the MaterialApp root (text scale, high
/// contrast, locale). The elder role defaults to simple mode + large text
/// on first run — a role-dependent default the client applies, not a DB
/// default (per the migration comment).
class UserPreferences {
  const UserPreferences({
    this.textScale = 'default',
    this.highContrast = false,
    this.simpleMode = false,
    this.languageCode = 'en',
  });

  final String textScale;
  final bool highContrast;
  final bool simpleMode;
  final String languageCode;

  double get textScaleFactor => switch (textScale) {
        'large' => 1.25,
        'extra_large' => 1.5,
        _ => 1.0,
      };

  UserPreferences copyWith({
    String? textScale,
    bool? highContrast,
    bool? simpleMode,
    String? languageCode,
  }) =>
      UserPreferences(
        textScale: textScale ?? this.textScale,
        highContrast: highContrast ?? this.highContrast,
        simpleMode: simpleMode ?? this.simpleMode,
        languageCode: languageCode ?? this.languageCode,
      );
}

final userPreferencesProvider =
    AsyncNotifierProvider<UserPreferencesNotifier, UserPreferences>(
        UserPreferencesNotifier.new);

class UserPreferencesNotifier extends AsyncNotifier<UserPreferences> {
  @override
  Future<UserPreferences> build() async {
    final client = ref.watch(supabaseClientProvider);
    final user = client.auth.currentUser;
    if (user == null) return const UserPreferences();

    final profile = await client
        .from('profiles')
        .select('role, preferred_language')
        .eq('id', user.id)
        .maybeSingle();
    final prefsRow = await client
        .from('accessibility_preferences')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    final isElder = profile?['role'] == 'elder';
    // Role default: an elder with no saved prefs starts accessible.
    return UserPreferences(
      textScale: prefsRow?['text_scale'] as String? ??
          (isElder ? 'large' : 'default'),
      highContrast: prefsRow?['high_contrast'] as bool? ?? false,
      simpleMode: prefsRow?['simple_mode'] as bool? ?? isElder,
      languageCode: profile?['preferred_language'] as String? ?? 'en',
    );
  }

  Future<void> save({
    String? textScale,
    bool? highContrast,
    bool? simpleMode,
    String? languageCode,
  }) async {
    final client = ref.read(supabaseClientProvider);
    final user = client.auth.currentUser;
    if (user == null) return;
    final current = state.valueOrNull ?? const UserPreferences();
    final next = current.copyWith(
      textScale: textScale,
      highContrast: highContrast,
      simpleMode: simpleMode,
      languageCode: languageCode,
    );
    state = AsyncData(next);

    if (textScale != null || highContrast != null || simpleMode != null) {
      await client.from('accessibility_preferences').upsert({
        'user_id': user.id,
        'text_scale': next.textScale,
        'high_contrast': next.highContrast,
        'simple_mode': next.simpleMode,
      }, onConflict: 'user_id');
    }
    if (languageCode != null) {
      await client.from('profiles').update({'preferred_language': languageCode}).eq('id', user.id);
    }
  }
}

/// A high-contrast override applied on top of the base theme when the
/// preference is on — deeper foreground/background separation, no reliance
/// on subtle greys.
ThemeData applyHighContrast(ThemeData base) {
  final scheme = base.colorScheme;
  final isDark = base.brightness == Brightness.dark;
  return base.copyWith(
    colorScheme: scheme.copyWith(
      onSurface: isDark ? Colors.white : Colors.black,
      onSurfaceVariant: isDark ? Colors.white : Colors.black,
      outline: isDark ? Colors.white70 : Colors.black87,
    ),
    dividerColor: isDark ? Colors.white70 : Colors.black,
  );
}
