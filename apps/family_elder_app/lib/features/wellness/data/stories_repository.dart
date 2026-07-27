import 'package:supabase_flutter/supabase_flutter.dart';

class Story {
  const Story({
    required this.id,
    required this.title,
    required this.body,
    this.summary,
    this.tradition,
    this.minutes,
    this.attribution,
    this.audioUrl,
  });

  final String id;
  final String title;
  final String body;
  final String? summary;
  final String? tradition;
  final int? minutes;
  final String? attribution;

  /// Null until a narrator has actually been recorded. The UI checks this
  /// rather than showing a play button that does nothing — the whole reason
  /// this feature was rebuilt.
  final String? audioUrl;

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

  factory Story.fromMap(Map<String, dynamic> m) => Story(
        id: m['id'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        summary: m['summary'] as String?,
        tradition: m['tradition'] as String?,
        minutes: (m['minutes'] as num?)?.toInt(),
        attribution: m['attribution'] as String?,
        audioUrl: m['audio_url'] as String?,
      );
}

class StoriesRepository {
  StoriesRepository(this._client);

  final SupabaseClient _client;

  /// The catalogue, with [preferredLanguage] first.
  ///
  /// Stories in other languages still appear rather than being filtered out:
  /// most elders here read more than one language, and an empty list because
  /// nobody has written a Telugu retelling yet is worse than a list that
  /// starts with the ones they'll find easiest.
  Future<List<Story>> list({String preferredLanguage = 'en'}) async {
    final rows = await _client
        .from('stories')
        .select()
        .eq('active', true)
        .order('sort_order');
    // Pair each story with its language in one pass, and with no cast at all:
    // select() already returns List<Map<String, dynamic>>. The previous version
    // walked the rows twice and cast on each pass, and the redundant second
    // cast was a *warning*, which flutter analyze treats as fatal.
    final indexed = [
      for (final row in rows) (Story.fromMap(row), row['language'] as String? ?? 'en'),
    ]..sort((a, b) {
        final aFirst = a.$2 == preferredLanguage ? 0 : 1;
        final bFirst = b.$2 == preferredLanguage ? 0 : 1;
        return aFirst - bFirst;
      });
    return [for (final entry in indexed) entry.$1];
  }
}
