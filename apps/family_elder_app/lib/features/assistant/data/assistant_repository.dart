import 'package:supabase_flutter/supabase_flutter.dart';

/// AI Care Assistant (PRD Part 7, Batch 4, Module 13). Always goes through
/// the `ai-care-assistant` Edge Function — never a direct query — since
/// the function is what enforces the fixed toolset, the medical-question
/// pre-filter, the RLS-scoped tool execution, and the output guardrail.
class AssistantReply {
  const AssistantReply({required this.reply, this.bookingDraft});

  final String reply;

  /// Present only when the assistant prepared a booking draft (from
  /// initiate_booking) — the UI turns this into an explicit confirm card;
  /// nothing is booked until the user taps confirm.
  final Map<String, dynamic>? bookingDraft;
}

class AssistantRepository {
  AssistantRepository(this._client);

  final SupabaseClient _client;

  Future<AssistantReply> ask({required String elderId, required String message}) async {
    final response = await _client.functions.invoke(
      'ai-care-assistant',
      body: {'elder_id': elderId, 'message': message},
    );
    if (response.status != 200) {
      // Surface the function's own friendly message (e.g. the 503 "still
      // being set up" text) rather than a raw dump, so the chat never shows
      // an ugly error blob to the user.
      final data = response.data;
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : 'The assistant is unavailable right now. Please try again shortly.';
      throw StateError(message);
    }
    final data = response.data as Map<String, dynamic>;
    return AssistantReply(
      reply: data['reply'] as String,
      bookingDraft: data['booking_draft'] as Map<String, dynamic>?,
    );
  }
}
