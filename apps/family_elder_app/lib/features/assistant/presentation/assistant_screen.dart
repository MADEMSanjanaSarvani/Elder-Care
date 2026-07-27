import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../../family_home/presentation/family_home_screen.dart' show homeSummaryProvider;
import '../data/assistant_repository.dart';

class _ChatMessage {
  const _ChatMessage({required this.text, required this.fromUser, this.bookingDraft});
  final String text;
  final bool fromUser;
  final Map<String, dynamic>? bookingDraft;
}

/// AI Care Assistant chat, matching the Stitch "ai_companion" design: a big
/// glowing orb with a real mood pill, suggested question chips on first
/// open, and a Memory Lane prompt that deep-links into the real memories
/// feature. A booking the assistant proposes shows as an explicit confirm
/// card — the assistant never books anything directly.
///
/// The Stitch mock also shows a "Hydration Reminder" card ("You've had 4
/// glasses today") — SETU tracks no water-intake data, so it's omitted
/// rather than shown with an invented count.
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
      appBar: AppBar(title: const Text('SETU companion')),
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
          const SizedBox(height: SetuSpacing.lg),
          _BreathingOrb(elderId: widget.elderId),
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
          const SizedBox(height: SetuSpacing.lg),
          _MemoryLaneCard(elderId: widget.elderId),
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

/// A soft, slowly-breathing lavender orb — the companion's calm presence,
/// with a real mood pill (from the elder's own logged mood) floating on
/// top, matching the Stitch design's "Calm Mood" chip. Honours
/// reduced-motion (renders a static orb).
class _BreathingOrb extends ConsumerStatefulWidget {
  const _BreathingOrb({required this.elderId});

  final String elderId;

  @override
  ConsumerState<_BreathingOrb> createState() => _BreathingOrbState();
}

class _BreathingOrbState extends ConsumerState<_BreathingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setuSyncBreathing(context, _c);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood =
        ref.watch(homeSummaryProvider(widget.elderId)).asData?.value.mood;

    final reduce = MediaQuery.of(context).disableAnimations;
    Widget orb(double scale) => Container(
          width: 148 * scale,
          height: 148 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              SetuColors.lavenderLight.withValues(alpha: 0.35),
              SetuColors.lavenderLight.withValues(alpha: 0.08),
            ]),
          ),
          child: const Icon(Icons.auto_awesome,
              size: 56, color: SetuColors.lavenderLight),
        );

    return SizedBox(
      width: 176,
      height: 176,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (reduce) orb(1) else AnimatedBuilder(
            animation: _c,
            builder: (_, __) => orb(0.94 + _c.value * 0.12),
          ),
          if (mood != null && mood.isNotEmpty)
            Positioned(
              top: 4,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: SetuSpacing.sm, vertical: 6),
                decoration: BoxDecoration(
                  color: SetuColors.paperRaisedLight,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: SetuColors.borderLight),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite,
                        size: 14, color: SetuColors.accentLight),
                    const SizedBox(width: 4),
                    Text('${mood[0].toUpperCase()}${mood.substring(1)} mood',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Prompts to look back at the elder's real memories feed — matches the
/// Stitch "Memory Lane" mindfulness card, without inventing a specific
/// memory (no real memory content is fetched here; the tap opens the real
/// memories screen where actual entries live).
class _MemoryLaneCard extends StatelessWidget {
  const _MemoryLaneCard({required this.elderId});
  final String elderId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined,
                  size: 16, color: SetuColors.lavenderLight),
              const SizedBox(width: 6),
              const Text('MINDFULNESS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: SetuColors.lavenderLight)),
            ],
          ),
          const SizedBox(height: SetuSpacing.sm),
          Text('Memory Lane',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Would you like to look back at some warm moments together?',
              style: TextStyle(color: SetuColors.mutedLight, height: 1.3)),
          const SizedBox(height: SetuSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/elder/$elderId/memories'),
              child: const Text('Yes, show me'),
            ),
          ),
        ],
      ),
    );
  }
}
