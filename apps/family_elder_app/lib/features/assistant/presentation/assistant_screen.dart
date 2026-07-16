import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/assistant_repository.dart';

class _ChatMessage {
  const _ChatMessage({required this.text, required this.fromUser, this.bookingDraft});
  final String text;
  final bool fromUser;
  final Map<String, dynamic>? bookingDraft;
}

/// AI Care Assistant chat (PRD Part 7, Batch 4, Module 13). Suggested
/// question chips on first open so a first-time user isn't staring at a
/// blank box wondering what's allowed. A booking the assistant proposes
/// shows as an explicit confirm card — the assistant never books anything
/// directly.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({required this.elderId, super.key});

  final String elderId;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[];
  bool _busy = false;

  static const _suggestions = [
    'When is the next visit?',
    'What medications are due today?',
    'Show me recent activity',
    'What can I see for this person?',
  ];

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _busy) return;
    setState(() {
      _messages.add(_ChatMessage(text: text.trim(), fromUser: true));
      _busy = true;
      _controller.clear();
    });
    try {
      final reply = await AssistantRepository(ref.read(supabaseClientProvider))
          .ask(elderId: widget.elderId, message: text.trim());
      setState(() => _messages.add(_ChatMessage(
            text: reply.reply,
            fromUser: false,
            bookingDraft: reply.bookingDraft,
          )));
    } catch (err) {
      setState(() => _messages.add(_ChatMessage(
            text: 'Sorry, something went wrong: $err',
            fromUser: false,
          )));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Care assistant')),
      body: Column(
        children: [
          if (_messages.isEmpty)
            Padding(
              padding: const EdgeInsets.all(SetuSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ask me about visits, medications, appointments, or your care team.'),
                  const SizedBox(height: SetuSpacing.md),
                  Wrap(
                    spacing: SetuSpacing.sm,
                    runSpacing: SetuSpacing.xs,
                    children: [
                      for (final s in _suggestions)
                        ActionChip(label: Text(s), onPressed: () => _send(s)),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(SetuSpacing.lg),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                return Align(
                  alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: SetuSpacing.sm),
                    padding: const EdgeInsets.all(SetuSpacing.md),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: m.fromUser
                          ? SetuColors.accentLight.withValues(alpha: 0.14)
                          : SetuColors.verifiedLight.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.text),
                        if (m.bookingDraft != null) ...[
                          const SizedBox(height: SetuSpacing.sm),
                          FilledButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('Review & confirm booking'),
                            onPressed: () =>
                                context.push('/elder/${widget.elderId}/booking'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(SetuSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask a question…',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: SetuSpacing.sm),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: _busy ? null : () => _send(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
