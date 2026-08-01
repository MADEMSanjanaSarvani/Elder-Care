import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The elder's photo. Migration 0028 added `elder_profiles.photo_url` and a
/// private `elder-photos` bucket for it; nothing wrote to either until now, so
/// every dashboard showed a coloured circle with two initials in it.
///
/// A face is not decoration here. The families using CareHive are handing their
/// parent to someone they have not met, and a screen that shows a photo of the
/// person reads like their mother rather than like a case file.
///
/// The bucket is private and its RLS keys off the first path segment, so
/// objects MUST be stored as `<elder_id>/...` — the elder themselves or an
/// actively linked family member, nobody else. Reads therefore go through a
/// signed URL rather than a public one.
class ElderPhotoRepository {
  ElderPhotoRepository(this._client);

  final SupabaseClient _client;
  static const _bucket = 'elder-photos';

  /// Uploads and points the profile at the new file. Returns the storage path.
  ///
  /// Each upload gets a fresh timestamped name rather than overwriting a fixed
  /// one, because a signed URL for the old name stays valid for its lifetime
  /// and an in-place replacement leaves the previous photo showing until it
  /// expires. The old object is deleted afterwards, and a failure to delete is
  /// swallowed: an orphaned file is untidy, while an error thrown here would
  /// tell the family the photo didn't save when it did.
  Future<String> upload({
    required String elderId,
    required Uint8List bytes,
    required String extension,
    String? mimeType,
  }) async {
    final previous = await currentPath(elderId);
    final safeExt = extension.replaceAll('.', '').toLowerCase();
    final path = '$elderId/${DateTime.now().millisecondsSinceEpoch}.$safeExt';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    await _client
        .from('elder_profiles')
        .update({'photo_url': path}).eq('id', elderId);

    if (previous != null && previous != path) {
      try {
        await _client.storage.from(_bucket).remove([previous]);
      } catch (_) {
        // Orphaned object; the photo itself saved fine.
      }
    }
    return path;
  }

  Future<String?> currentPath(String elderId) async {
    final row = await _client
        .from('elder_profiles')
        .select('photo_url')
        .eq('id', elderId)
        .maybeSingle();
    return row?['photo_url'] as String?;
  }

  /// A time-limited URL for a private object. One hour is long enough for a
  /// session and short enough that a leaked link stops working.
  Future<String?> signedUrl(String elderId) async {
    final path = await currentPath(elderId);
    if (path == null || path.isEmpty) return null;
    try {
      return await _client.storage.from(_bucket).createSignedUrl(path, 60 * 60);
    } catch (_) {
      // A row pointing at a deleted object shouldn't break the screen — the
      // avatar just falls back to initials.
      return null;
    }
  }

  Future<void> clear(String elderId) async {
    final path = await currentPath(elderId);
    await _client
        .from('elder_profiles')
        .update({'photo_url': null}).eq('id', elderId);
    if (path != null && path.isNotEmpty) {
      try {
        await _client.storage.from(_bucket).remove([path]);
      } catch (_) {
        // Same reasoning as upload(): the profile no longer points at it.
      }
    }
  }
}
