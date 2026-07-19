import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/doctors_repository.dart';

/// The live video-consult room, powered by Agora. Fetches a per-join RTC
/// token from the server (agora-rtc-token), joins the consultation's channel,
/// and shows the doctor's stream with a self-preview and mute/camera/end
/// controls. Fails soft: if the SDK, permissions or token aren't available it
/// shows a clear message instead of a blank call.
class VideoConsultScreen extends ConsumerStatefulWidget {
  const VideoConsultScreen({
    required this.consultationId,
    this.channel,
    super.key,
  });

  final String consultationId;
  final String? channel;

  @override
  ConsumerState<VideoConsultScreen> createState() =>
      _VideoConsultScreenState();
}

class _VideoConsultScreenState extends ConsumerState<VideoConsultScreen> {
  RtcEngine? _engine;
  String? _channel;
  int? _remoteUid;
  bool _joined = false;
  bool _muted = false;
  bool _camOff = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      // Camera + mic are required to join.
      final statuses =
          await [Permission.camera, Permission.microphone].request();
      final granted = statuses.values.every((s) => s.isGranted);
      if (!granted) {
        setState(() => _error =
            'Camera and microphone permission are needed for a video consult.');
        return;
      }

      final t = await DoctorsRepository(ref.read(supabaseClientProvider))
          .videoToken(widget.consultationId);
      final appId = t['app_id'] as String? ?? '';
      final channel = t['channel'] as String? ?? widget.channel ?? '';
      final token = t['token'] as String?; // null in Agora testing mode
      final uid = (t['uid'] as num?)?.toInt() ?? 0;
      if (appId.isEmpty || channel.isEmpty) {
        setState(() => _error = 'Video is not configured yet.');
        return;
      }
      _channel = channel;

      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: appId));
      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (conn, elapsed) {
          if (mounted) setState(() => _joined = true);
        },
        onUserJoined: (conn, remoteUid, elapsed) {
          if (mounted) setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (conn, remoteUid, reason) {
          if (mounted) setState(() => _remoteUid = null);
        },
        onError: (err, msg) {
          if (mounted && !_joined) setState(() => _error = 'Call error: $msg');
        },
      ));
      await engine.enableVideo();
      await engine.startPreview();
      await engine.joinChannel(
        token: token ?? '',
        channelId: channel,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      if (mounted) setState(() => _engine = engine);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start the call: $e');
    }
  }

  Future<void> _leave() async {
    final engine = _engine;
    _engine = null;
    try {
      await engine?.leaveChannel();
      await engine?.release();
    } catch (_) {}
  }

  @override
  void dispose() {
    _leave();
    super.dispose();
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _engine?.muteLocalAudioStream(next);
    setState(() => _muted = next);
  }

  Future<void> _toggleCam() async {
    final next = !_camOff;
    await _engine?.muteLocalVideoStream(next);
    setState(() => _camOff = next);
  }

  Future<void> _switchCam() async {
    await _engine?.switchCamera();
  }

  Future<void> _hangUp() async {
    await _leave();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _error != null
            ? _errorView()
            : Stack(
                children: [
                  Positioned.fill(child: _remoteView()),
                  // Self preview (picture-in-picture).
                  Positioned(
                    right: 16,
                    top: 16,
                    width: 108,
                    height: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ColoredBox(
                        color: Colors.black54,
                        child: _engine != null && !_camOff
                            ? AgoraVideoView(
                                controller: VideoViewController(
                                  rtcEngine: _engine!,
                                  canvas: const VideoCanvas(uid: 0),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.videocam_off,
                                    color: Colors.white54)),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _controls(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _remoteView() {
    if (_engine == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_remoteUid == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, color: Colors.white54, size: 56),
            SizedBox(height: 12),
            Text('Waiting for the doctor to join…',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: _remoteUid),
        connection: RtcConnection(channelId: _channel),
      ),
    );
  }

  Widget _controls() {
    Widget btn(IconData icon, VoidCallback onTap, {Color? bg, Color? fg}) =>
        Material(
          color: bg ?? Colors.white24,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: fg ?? Colors.white, size: 26),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          btn(_muted ? Icons.mic_off : Icons.mic, _toggleMute),
          const SizedBox(width: 16),
          btn(_camOff ? Icons.videocam_off : Icons.videocam, _toggleCam),
          const SizedBox(width: 16),
          btn(Icons.call_end, _hangUp,
              bg: SetuColors.sosLight, fg: Colors.white),
          const SizedBox(width: 16),
          btn(Icons.cameraswitch, _switchCam),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined,
                color: Colors.white70, size: 56),
            const SizedBox(height: SetuSpacing.md),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4)),
            const SizedBox(height: SetuSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}
