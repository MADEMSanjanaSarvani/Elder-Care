import 'dart:math';

import 'package:flutter/material.dart';
import 'package:setu_core/setu_core.dart';

/// A card-matching memory game, built for the elder persona rather than
/// borrowed from a generic puzzle app.
///
/// Deliberate choices, all of them accessibility ones:
///  * 3x4 grid — twelve cards is enough to be a real exercise and few enough
///    to hold in view without scrolling on a small phone.
///  * Big tap targets and large glyphs. Everything is an icon, never a
///    number or letter, so it works regardless of literacy or language.
///  * Each pair has its own colour as well as its own shape, so a match is
///    findable without relying on colour vision.
///  * No timer, no score, no losing. Pressure is the opposite of what this
///    is for. The only feedback is encouragement.
///  * Entirely offline — no network, no account, nothing logged. An elder
///    can play it on a train with no signal.
class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({super.key});

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

/// One face of the deck: an icon plus the colour that always accompanies it.
class _Face {
  const _Face(this.icon, this.color, this.label);
  final IconData icon;
  final Color color;
  final String label;
}

const _faces = <_Face>[
  _Face(Icons.local_florist, Color(0xFFC8792F), 'flower'),
  _Face(Icons.wb_sunny_rounded, Color(0xFFF08A3C), 'sun'),
  _Face(Icons.favorite_rounded, Color(0xFFD1566B), 'heart'),
  _Face(Icons.emoji_nature, Color(0xFF4E8F70), 'leaf'),
  _Face(Icons.music_note_rounded, Color(0xFF62549B), 'music'),
  _Face(Icons.local_cafe_rounded, Color(0xFF8A6A4F), 'tea'),
];

class _Card {
  _Card(this.face);
  final _Face face;
  bool revealed = false;
  bool matched = false;
}

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  late List<_Card> _cards;
  int? _firstUp;
  bool _busy = false;
  int _pairsFound = 0;
  int _turns = 0;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    _cards = [for (final f in _faces) ...[_Card(f), _Card(f)]]..shuffle(Random());
    _firstUp = null;
    _busy = false;
    _pairsFound = 0;
    _turns = 0;
  }

  Future<void> _tap(int i) async {
    final card = _cards[i];
    if (_busy || card.revealed || card.matched) return;

    setState(() => card.revealed = true);

    if (_firstUp == null) {
      _firstUp = i;
      return;
    }

    final first = _cards[_firstUp!];
    setState(() {
      _busy = true;
      _turns++;
    });

    if (first.face.icon == card.face.icon) {
      // Matched — leave both face up and celebrate.
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;
      setState(() {
        first.matched = true;
        card.matched = true;
        _pairsFound++;
        _firstUp = null;
        _busy = false;
      });
      if (_pairsFound == _faces.length && mounted) _celebrate();
    } else {
      // Not a match — hold them up long enough to actually be memorised.
      // Elders need longer than the 500ms a younger player would.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      setState(() {
        first.revealed = false;
        card.revealed = false;
        _firstUp = null;
        _busy = false;
      });
    }
  }

  void _celebrate() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: const Text('Wonderful!'),
        content: Text(
          'You found all six pairs in $_turns turns.\n\n'
          'That is a good workout for the memory. Come back tomorrow?',
          style: const TextStyle(fontSize: 17, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(_deal);
            },
            child: const Text('Play again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory game'),
        actions: [
          IconButton(
            tooltip: 'Start again',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_deal),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          child: Column(
            children: [
              Text(
                'Find the two cards that match.',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: SetuSpacing.xs),
              const Text(
                'Take as long as you like — there is no timer.',
                style: TextStyle(
                    color: SetuColors.mutedLight, fontSize: 15),
              ),
              const SizedBox(height: SetuSpacing.md),
              _progress(),
              const SizedBox(height: SetuSpacing.lg),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: SetuSpacing.md,
                    crossAxisSpacing: SetuSpacing.md,
                    childAspectRatio: 0.86,
                  ),
                  itemCount: _cards.length,
                  itemBuilder: (context, i) => _tile(_cards[i], i),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _faces.length; i++) ...[
          Icon(
            i < _pairsFound
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            size: 22,
            color: i < _pairsFound
                ? SetuColors.verifiedLight
                : SetuColors.borderLight,
          ),
          if (i < _faces.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _tile(_Card card, int i) {
    final showFace = card.revealed || card.matched;
    return Semantics(
      button: true,
      label: showFace ? card.face.label : 'hidden card',
      child: GestureDetector(
        onTap: () => _tap(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: showFace
                ? card.face.color.withValues(alpha: card.matched ? 0.22 : 0.14)
                : SetuColors.paperRaisedLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: card.matched
                  ? card.face.color
                  : showFace
                      ? card.face.color.withValues(alpha: 0.55)
                      : SetuColors.borderLight,
              width: card.matched ? 2.5 : 1.5,
            ),
          ),
          child: Center(
            child: showFace
                ? Icon(card.face.icon, size: 46, color: card.face.color)
                : const Icon(Icons.help_outline_rounded,
                    size: 34, color: SetuColors.borderLight),
          ),
        ),
      ),
    );
  }
}
