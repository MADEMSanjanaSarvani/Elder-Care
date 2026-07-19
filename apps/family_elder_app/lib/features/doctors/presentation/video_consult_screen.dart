import 'package:flutter/material.dart';
import 'package:setu_core/setu_core.dart';

/// The video-consult room. The real-time Agora engine is wired in the native
/// module pass (alongside push); until the App Certificate is configured this
/// screen shows the call context and a Join control, so the flow — book →
/// open room → join — is complete and testable end to end.
class VideoConsultScreen extends StatelessWidget {
  const VideoConsultScreen({
    required this.consultationId,
    this.channel,
    super.key,
  });

  final String consultationId;
  final String? channel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Video consult'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(SetuSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_rounded,
                    size: 44, color: Colors.white),
              ),
              const SizedBox(height: SetuSpacing.lg),
              const Text('Your secure consult room is ready',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: SetuSpacing.sm),
              Text(
                channel != null
                    ? 'Room: $channel'
                    : 'The doctor will start the call at your scheduled time.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: SetuSpacing.xl),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Video activates in the next app update — your booking is confirmed.')),
                  );
                },
                icon: const Icon(Icons.call),
                label: const Text('Join call'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
