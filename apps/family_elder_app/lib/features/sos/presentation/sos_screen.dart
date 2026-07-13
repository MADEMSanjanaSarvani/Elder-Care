import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:setu_core/setu_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../data/sos_repository.dart';

/// PRD Part 1 §04 / Part 2 §12: "Call 108" is the mandatory primary
/// action. Platform escalation (notifying family + on-call ops) is a
/// secondary action that runs in parallel — never instead of — calling
/// emergency services. This screen's mere existence is itself the
/// "108-first screen was shown" evidence the sos-trigger function requires.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({required this.elderId, super.key});

  final String elderId;

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  bool _notifying = false;
  bool _notified = false;
  String? _error;

  Future<void> _call108() async {
    await launchUrl(Uri.parse('tel:108'));
  }

  Future<void> _notifyPlatform() async {
    setState(() {
      _notifying = true;
      _error = null;
    });
    try {
      final position = await Geolocator.getCurrentPosition();
      final repo = SosRepository(ref.read(supabaseClientProvider));
      await repo.trigger(
        elderId: widget.elderId,
        lat: position.latitude,
        lng: position.longitude,
        ack108Shown: true, // this screen is the 108-first screen
      );
      setState(() => _notified = true);
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      setState(() => _notifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Emergency'),
          backgroundColor: SetuColors.sosLight,
          foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: SetuColors.sosLight,
                padding: const EdgeInsets.symmetric(vertical: SetuSpacing.lg),
              ),
              onPressed: _call108,
              icon: const Icon(Icons.call, size: 28),
              label: const Text('Call 108 (Emergency)',
                  style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: SetuSpacing.lg),
            Text(
              'Calling 108 is the fastest way to get emergency medical help. '
              'Notifying Setu alerts your family and our on-call team at the same time — '
              'it does not replace calling 108.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SetuSpacing.lg),
            if (_error != null) ...[
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: SetuSpacing.md),
            ],
            if (_notified)
              const Text('Your family and our on-call team have been notified.')
            else
              OutlinedButton.icon(
                onPressed: _notifying ? null : _notifyPlatform,
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(
                    _notifying ? 'Notifying…' : 'Also notify family & Setu'),
              ),
          ],
        ),
      ),
    );
  }
}
