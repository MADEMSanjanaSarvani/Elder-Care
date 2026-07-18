import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Medical document storage (lab reports, prescriptions, scans). Files go to
/// the private `medical-documents` bucket; the row in `medical_documents`
/// indexes them. Both are consent-gated by RLS (health_notes), so a family
/// member without that consent simply can't read or add.
class MedicalDocumentsRepository {
  MedicalDocumentsRepository(this._client);

  final SupabaseClient _client;
  static const _bucket = 'medical-documents';

  Future<List<Map<String, dynamic>>> list(String elderId) async {
    return _client
        .from('medical_documents')
        .select()
        .eq('elder_id', elderId)
        .order('uploaded_at', ascending: false);
  }

  Future<void> upload({
    required String elderId,
    required String title,
    required String category,
    required Uint8List bytes,
    required String extension,
    String? mimeType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');
    final safeExt = extension.replaceAll('.', '').toLowerCase();
    final path =
        '$elderId/${DateTime.now().millisecondsSinceEpoch}_${userId.substring(0, 6)}.$safeExt';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    await _client.from('medical_documents').insert({
      'elder_id': elderId,
      'uploaded_by': userId,
      'category': category,
      'title': title,
      'storage_path': path,
      'mime_type': mimeType,
    });
  }

  Future<String> signedUrl(String storagePath) {
    return _client.storage.from(_bucket).createSignedUrl(storagePath, 60 * 60);
  }

  Future<void> delete({required String id, required String storagePath}) async {
    await _client.storage.from(_bucket).remove([storagePath]);
    await _client.from('medical_documents').delete().eq('id', id);
  }
}
