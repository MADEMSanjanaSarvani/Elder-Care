import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

/// True when the device has a network connection. Emits immediately with the
/// current state, then on every change. Defaults to online if the platform
/// can't answer, so we never hide content on a false negative.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final conn = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);
  try {
    yield online(await conn.checkConnectivity());
  } catch (_) {
    yield true;
  }
  yield* conn.onConnectivityChanged.map(online);
});

/// A slim, calm banner that appears only when the device is offline. Safety
/// paths (SOS → dial 108, cached data) keep working; this simply explains why
/// fresh data may not load. Placed at the top of every app shell.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).asData?.value ?? true;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: online
          ? const SizedBox(width: double.infinity)
          : const Material(
              color: SetuColors.sosLight,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: SetuSpacing.md, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('No internet connection',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
