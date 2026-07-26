import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/stories_repository.dart';

final storiesProvider = FutureProvider<List<Story>>((ref) async {
  ref.watch(authStateProvider);
  final language =
      ref.watch(currentProfileProvider).asData?.value?['preferred_language']
              as String? ??
          'en';
  return StoriesRepository(ref.watch(supabaseClientProvider))
      .list(preferredLanguage: language);
});

/// The story catalogue.
///
/// Replaces a card that read "The Golden River · 15 min" next to a play
/// triangle and did nothing at all when tapped. These are real, and they
/// are read rather than heard: there is no narrator recorded yet, and a
/// large-type story an elder can read tonight is worth more than a play
/// button that starts working after somebody books a studio.
class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = ref.watch(storiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Stories')),
      body: stories.when(
        loading: () => const SetuLoading(),
        error: (err, _) => const SetuErrorState(),
        data: (list) {
          if (list.isEmpty) {
            return const SetuEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No stories yet',
              message: 'New tales are added from time to time.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: list.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: SetuSpacing.md),
            itemBuilder: (context, i) => _StoryTile(story: list[i]),
          );
        },
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => StoryReaderScreen(story: story),
      )),
      child: Container(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        decoration: BoxDecoration(
          color: SetuColors.paperRaisedLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SetuColors.borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SetuIconChip(
                icon: Icons.menu_book_outlined, color: SetuColors.accentLight),
            const SizedBox(width: SetuSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(story.title,
                      style: t.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  if (story.summary != null) ...[
                    const SizedBox(height: 3),
                    Text(story.summary!,
                        style: const TextStyle(
                            color: SetuColors.mutedLight, height: 1.4)),
                  ],
                  const SizedBox(height: SetuSpacing.sm),
                  Row(
                    children: [
                      if (story.minutes != null)
                        Text('${story.minutes} min read',
                            style: const TextStyle(
                                color: SetuColors.mutedLight, fontSize: 12.5)),
                      if (story.minutes != null && story.tradition != null)
                        const Text(' · ',
                            style: TextStyle(color: SetuColors.mutedLight)),
                      if (story.tradition != null)
                        Text(_traditionLabel(story.tradition!),
                            style: const TextStyle(
                                color: SetuColors.mutedLight, fontSize: 12.5)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: SetuColors.mutedLight),
          ],
        ),
      ),
    );
  }
}

String _traditionLabel(String tradition) {
  switch (tradition) {
    case 'panchatantra':
      return 'Panchatantra';
    case 'jataka':
      return 'Jataka tales';
    case 'aesop':
      return "Aesop's fables";
    default:
      return tradition;
  }
}

/// Reading a story, built for old eyes.
///
/// The text size control is the feature, not a setting: presbyopia is
/// effectively universal past sixty, and an elder who has to fetch their
/// glasses to start a story usually doesn't start it. The choice is per
/// session rather than saved, because it lives in one screen and a
/// preference nobody can find how to change is worse than one they set again.
class StoryReaderScreen extends StatefulWidget {
  const StoryReaderScreen({super.key, required this.story});

  final Story story;

  @override
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> {
  // Starts well above the app's body default. This screen is for reading, not
  // for scanning, and the usual 15sp is too small for the audience.
  double _fontSize = 21;

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final paragraphs = story.body
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(story.title),
        actions: [
          IconButton(
            tooltip: 'Smaller text',
            onPressed: _fontSize <= 16
                ? null
                : () => setState(() => _fontSize -= 2),
            icon: const Icon(Icons.text_decrease),
          ),
          IconButton(
            tooltip: 'Larger text',
            onPressed: _fontSize >= 32
                ? null
                : () => setState(() => _fontSize += 2),
            icon: const Icon(Icons.text_increase),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            SetuSpacing.lg, SetuSpacing.lg, SetuSpacing.lg, SetuSpacing.xl),
        children: [
          Text(story.title,
              style: TextStyle(
                fontSize: _fontSize + 7,
                fontWeight: FontWeight.w800,
                height: 1.25,
              )),
          const SizedBox(height: SetuSpacing.lg),
          for (final paragraph in paragraphs) ...[
            Text(
              paragraph,
              style: TextStyle(
                fontSize: _fontSize,
                // Generous leading: long lines at large sizes are hard to
                // track back to the start of the next one.
                height: 1.65,
                color: SetuColors.inkLight,
              ),
            ),
            const SizedBox(height: SetuSpacing.md),
          ],
          const SizedBox(height: SetuSpacing.md),
          const Divider(),
          const SizedBox(height: SetuSpacing.sm),
          // Shown, not buried. An elder-care app that quietly appropriated
          // folk tales would not be the kind of thing SETU should be.
          Text(
            story.attribution ??
                'Original retelling of a traditional public-domain tale.',
            style: const TextStyle(
                color: SetuColors.mutedLight, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}
