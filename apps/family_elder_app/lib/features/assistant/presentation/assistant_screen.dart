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
    'Tell me a story',
    'Check my health',
    'Morning routine',
    'When is the next visit?',
    'What medications are due today?',
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
      final message = err is StateError ? err.message : err.toString();
      setState(() => _messages.add(_ChatMessage(
            text: message,
            fromUser: false,
          )));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CareHive companion')),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? _welcome() : _chatList(),
          ),
          if (_busy)
            const LinearProgressIndicator(
                color: SetuColors.lavenderLight, minHeight: 2),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _welcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SetuSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: SetuSpacing.xl),
          const _BreathingOrb(),
          const SizedBox(height: SetuSpacing.xl),
          Builder(builder: (context) {
            final elder =
                ref.watch(elderProfileByIdProvider(widget.elderId)).asData?.value;
            final name = (elder?['display_name'] as String?)?.trim().split(' ').first;
            return Text(
              name != null && name.isNotEmpty
                  ? 'How are you feeling today, $name?'
                  : 'How are you feeling today?',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            );
          }),
          const SizedBox(height: SetuSpacing.sm),
          const Text(
            "I'm here to listen, chat, or help with your daily wellness.",
            textAlign: TextAlign.center,
            style: TextStyle(color: SetuColors.mutedLight, height: 1.4),
          ),
          const SizedBox(height: SetuSpacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: SetuSpacing.sm,
            runSpacing: SetuSpacing.sm,
            children: [
              for (final s in _suggestions)
                ActionChip(
                  label: Text(s),
                  onPressed: () => _send(s),
                  backgroundColor:
                      SetuColors.lavenderLight.withValues(alpha: 0.10),
                  side: BorderSide(
                      color: SetuColors.lavenderLight.withValues(alpha: 0.30)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chatList() {
    return ListView.builder(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final m = _messages[index];
        final isUser = m.fromUser;
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: SetuSpacing.sm),
            padding: const EdgeInsets.all(SetuSpacing.md),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82),
            decoration: BoxDecoration(
              color: isUser
                  ? SetuColors.accentLight.withValues(alpha: 0.14)
                  : SetuColors.lavenderLight.withValues(alpha: 0.12),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.text, style: const TextStyle(height: 1.4)),
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
    );
  }

  Widget _inputBar() {
    return Padding(
      padding: const EdgeInsets.all(SetuSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: 'Type a message…'),
              onSubmitted: _send,
            ),
          ),
          const SizedBox(width: SetuSpacing.sm),
          IconButton.filled(
            style: IconButton.styleFrom(
                backgroundColor: SetuColors.lavenderLight,
                minimumSize: const Size(52, 52)),
            icon: const Icon(Icons.send),
            onPressed: _busy ? null : () => _send(_controller.text),
          ),
        ],
      ),
    );
  }
}

/// A soft, slowly-breathing lavender orb — the companion's calm presence.
/// Honours reduced-motion (renders a static orb).
class _BreathingOrb extends StatefulWidget {
  const _BreathingOrb();

  @override
  State<_BreathingOrb> createState() => _BreathingOrbState();
}

class _BreathingOrbState extends State<_BreathingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 4))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    Widget orb(double scale) => Container(
          width: 132 * scale,
          height: 132 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              SetuColors.lavenderLight.withValues(alpha: 0.35),
              SetuColors.lavenderLight.withValues(alpha: 0.08),
            ]),
          ),
          child: const Icon(Icons.auto_awesome,
              size: 52, color: SetuColors.lavenderLight),
        );
    if (reduce) return orb(1);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => orb(0.94 + _c.value * 0.12),
    );
  }
}
