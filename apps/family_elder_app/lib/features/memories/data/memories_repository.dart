import 'package:supabase_flutter/supabase_flutter.dart';

/// One SETU Memory — a warm, human summary of an elder's day, generated
/// server-side from the day's real data (medicines, check-in, visits).
class SetuMemory {
  const SetuMemory({
    required this.id,
    required this.elderId,
    required this.date,
    required this.summary,
    required this.highlights,
    this.mood,
    required this.generatedAt,
  });

  final String id;
  final String elderId;
  final DateTime date;
  final String summary;
  final List<MemoryHighlight> highlights;
  final String? mood;
  final DateTime generatedAt;

  factory SetuMemory.fromMap(Map<String, dynamic> m) {
    final raw = (m['highlights'] as List?) ?? const [];
    return SetuMemory(
      id: m['id'] as String,
      elderId: m['elder_id'] as String,
      date: DateTime.parse(m['memory_date'] as String),
      summary: m['summary'] as String,
      highlights: raw
          .whereType<Map>()
          .map((h) => MemoryHighlight(
                icon: h['icon'] as String? ?? 'auto_awesome',
                text: h['text'] as String? ?? '',
              ))
          .toList(),
      mood: m['mood'] as String?,
      generatedAt: DateTime.parse(m['generated_at'] as String).toLocal(),
    );
  }
}

class MemoryHighlight {
  const MemoryHighlight({required this.icon, required this.text});
  final String icon;
  final String text;
}

class MemoriesRepository {
  MemoriesRepository(this._client);
  final SupabaseClient _client;

  /// The stored memories for an elder, newest first.
  Future<List<SetuMemory>> list(String elderId) async {
    final rows = await _client
        .from('setu_memories')
        .select()
        .eq('elder_id', elderId)
        .order('memory_date', ascending: false)
        .limit(30);
    return (rows as List)
        .map((r) => SetuMemory.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Ask the server to (re)generate today's memory from the day's data.
  /// Deterministic and safe to call repeatedly — it upserts one row per day.
  Future<SetuMemory?> generateToday(String elderId) async {
    final res = await _client.functions.invoke(
      'setu-memories-generate',
      body: {'elder_id': elderId},
    );
    final data = res.data;
    if (data is Map && data['memory'] is Map) {
      return SetuMemory.fromMap(
          Map<String, dynamic>.from(data['memory'] as Map));
    }
    return null;
  }
}
