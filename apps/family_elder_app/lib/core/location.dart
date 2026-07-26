import 'package:geolocator/geolocator.dart';

/// What a location attempt actually produced.
///
/// [position] is null when nothing usable came back, and [problem] then holds
/// a sentence a caregiver or a worried daughter can act on. Callers that can
/// work without a location ignore [problem]; callers that can't show it.
class LocationResult {
  const LocationResult._(this.position, this.problem, this.needsSettings);

  const LocationResult.found(Position position) : this._(position, null, false);
  const LocationResult.failed(String problem, {bool needsSettings = false})
      : this._(null, problem, needsSettings);

  final Position? position;

  /// Null on success. Never a raw exception — see [captureLocation].
  final String? problem;

  /// True when the only way forward is the phone's own settings screen
  /// (services switched off, or permission permanently denied), so a caller
  /// can offer a button that opens it instead of just saying "no".
  final bool needsSettings;

  bool get ok => position != null;
}

/// Gets the device's location, or explains why it couldn't, in words.
///
/// Written after a caregiver hit "Use my current location" and got
/// `TimeoutException after 0:00:08.000000: Future not completed`. Three things
/// were wrong and all three are fixed here:
///
/// 1. **Eight seconds is not enough.** A cold GPS fix indoors regularly takes
///    thirty seconds or more; the old timeout was shorter than the normal case,
///    so the feature failed for anyone not already standing outside.
/// 2. **Nothing checked whether location services were switched on at all.**
///    With GPS off system-wide, the request can only ever time out, and the
///    message said nothing about the actual cause.
/// 3. **The raw exception was shown to the user.** "Future not completed" is
///    not a sentence anybody can act on.
///
/// The last-known position is used as a fallback rather than a first resort:
/// it can be hours stale and miles away, which is wrong for "where do I work
/// from", but far better than nothing when the alternative is failure. Callers
/// that must have a live fix pass [allowStale] false.
Future<LocationResult> captureLocation({
  Duration timeout = const Duration(seconds: 30),
  LocationAccuracy accuracy = LocationAccuracy.medium,
  bool allowStale = true,
}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult.failed(
        'Location is switched off on this phone. Turn it on in Settings, then '
        'try again.',
        needsSettings: true,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.failed(
        'Location permission was turned off for SETU. You can switch it back '
        'on in the app settings.',
        needsSettings: true,
      );
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return const LocationResult.failed(
          'SETU needs permission to use your location.');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy),
      ).timeout(timeout);
      return LocationResult.found(position);
    } catch (_) {
      // Timed out or the fix failed. Fall back to whatever the phone last
      // knew, if the caller can live with it.
      if (allowStale) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return LocationResult.found(last);
      }
      return const LocationResult.failed(
        "Couldn't get a location fix. Moving near a window or stepping "
        'outside usually helps, then try again.',
      );
    }
  } catch (_) {
    // Anything unexpected from the platform channel.
    return const LocationResult.failed(
        "Couldn't read this phone's location just now. Please try again.");
  }
}
