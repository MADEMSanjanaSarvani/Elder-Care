/// Dose reminders that fire on the phone, at the right minute, with no server
/// and no internet involved.
///
/// The server path exists and works — a sweep writes a notification row and
/// sends an FCM push — but it cannot be *the* reminder, for two reasons found
/// the hard way. The GitHub Actions cron driving that sweep is best-effort and
/// was observed drifting past ninety minutes between runs, and FCM needs a data
/// connection the phone may not have. "Take your tablet" arriving an hour and a
/// half late, or not at all in a patchy signal area, is worse than no reminder,
/// because the person stops trusting it and stops looking.
///
/// So the reminder is an alarm scheduled on the device itself. It fires exactly
/// on time, works in flight mode, survives a reboot, and carries the Taken
/// button. The server push stays as the thing only a server can do: telling
/// *family*, and SOS.
///
/// ## Why Taken doesn't write straight to Supabase
///
/// Android runs a notification action in a separate background isolate with no
/// Supabase client and no session in it. Rebuilding auth there — refresh token
/// handling and all — to record one boolean would be a lot of moving parts in
/// the least debuggable place in the app.
///
/// Instead the tap is queued to disk with the moment it happened, and flushed
/// on the next app open. The recorded time is when they actually tapped, which
/// is the fact that matters; only its arrival at the server is delayed. When
/// the app is already running, [_onForegroundResponse] writes it immediately
/// and there is no queue at all.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const _channelReminders = 'carehive_reminders';
const _channelEmergency = 'carehive_emergency';
const _takenActionId = 'taken';

/// Queue of "Taken" taps that happened while the app was not running.
const _pendingKey = 'carehive_pending_dose_marks_v1';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

/// Runs in its own isolate when the app is not in the foreground, so it can
/// touch nothing but disk.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  if (response.actionId != _takenActionId) return;
  final doseId = response.payload;
  if (doseId == null || doseId.isEmpty) return;
  // Fire-and-forget: the isolate is torn down as soon as this returns, and an
  // await here would not be given time to finish.
  _queueDoseMark(doseId);
}

Future<void> _queueDoseMark(String doseId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pendingKey) ?? <String>[];
    raw.add(jsonEncode({
      'dose_id': doseId,
      // The moment of the tap, not the moment of the sync. This is the whole
      // point of the queue — a dose taken at 08:02 and synced at 19:00 must
      // read as 08:02 or the adherence history is fiction.
      'taken_at': DateTime.now().toUtc().toIso8601String(),
    }));
    await prefs.setStringList(_pendingKey, raw);
  } catch (err) {
    debugPrint('Could not queue dose mark: $err');
  }
}

class LocalReminders {
  LocalReminders(this._client);

  final SupabaseClient _client;

  static bool _ready = false;

  /// Sets up channels, permissions and the timezone database. Safe to call
  /// more than once; safe to fail — a phone that refuses notification
  /// permission still gets a working app, just a silent one.
  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      tzdata.initializeTimeZones();
      // The device's own zone, so 08:00 means 08:00 where the person is
      // standing rather than 08:00 UTC.
      tz.setLocalLocation(tz.getLocation(await _deviceTimeZone()));

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: _onForegroundResponse,
        onDidReceiveBackgroundNotificationResponse:
            notificationBackgroundHandler,
      );

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        // Two channels, never one. Somebody who turns off daily medicine
        // reminders because they find them naggy must not thereby turn off the
        // emergency alert for their parent.
        await android.createNotificationChannel(const AndroidNotificationChannel(
          _channelReminders,
          'Medicine reminders',
          description: 'When it is time to take a medicine.',
          importance: Importance.high,
        ));
        await android.createNotificationChannel(const AndroidNotificationChannel(
          _channelEmergency,
          'Emergency alerts',
          description: 'SOS alerts for someone in your care circle.',
          importance: Importance.max,
        ));
        await android.requestNotificationsPermission();
        // Android 12+ gates exact alarms. Without it the OS is free to batch
        // the alarm into a maintenance window, which for a dose time means
        // "sometime in the next hour" — precisely the drift we moved off the
        // server cron to avoid.
        await android.requestExactAlarmsPermission();
      }
    } catch (err) {
      debugPrint('Local reminders unavailable: $err');
    }
  }

  static Future<String> _deviceTimeZone() async {
    try {
      // Available since Dart 3.0 and enough for our purposes: an IANA name
      // like "Asia/Kolkata".
      final name = DateTime.now().timeZoneName;
      // timeZoneName can be an abbreviation ("IST"), which tz cannot resolve.
      // Fall back rather than throw — a wrong-but-consistent zone is far less
      // damaging than no reminders at all.
      tz.getLocation(name);
      return name;
    } catch (_) {
      return 'Asia/Kolkata';
    }
  }

  /// Rebuilds the phone's alarm list from the doses the server knows about.
  ///
  /// Cancels everything and re-schedules rather than diffing: the source of
  /// truth is the server, the list is at most a few dozen entries, and a diff
  /// that goes wrong leaves a phantom alarm for a medicine somebody stopped
  /// taking. Cheap and correct beats clever here.
  Future<void> syncDoses(List<Map<String, dynamic>> doses) async {
    await init();
    try {
      await _plugin.cancelAll();

      final now = tz.TZDateTime.now(tz.local);
      var scheduled = 0;
      for (final dose in doses) {
        // Android caps how many alarms one app may hold. Two days of doses is
        // well inside it and the app re-syncs on every open.
        if (scheduled >= 48) break;
        if (dose['status'] != 'pending') continue;

        final at = DateTime.tryParse(dose['scheduled_at'] as String? ?? '');
        if (at == null) continue;
        final when = tz.TZDateTime.from(at.toLocal(), tz.local);
        // A dose already in the past is a missed dose, not a reminder. Firing
        // an alarm for 8am at 3pm teaches people to ignore the alarm.
        if (!when.isAfter(now)) continue;

        final id = dose['id'] as String?;
        if (id == null) continue;

        final med = dose['elder_medications'];
        final name = med is Map ? med['name'] as String? : null;
        final dosage = med is Map ? med['dosage'] as String? : null;

        await _plugin.zonedSchedule(
          // A stable 31-bit id derived from the dose uuid, so re-syncing
          // replaces an alarm instead of stacking a second one.
          id: id.hashCode & 0x7fffffff,
          scheduledDate: when,
          title: name == null ? 'Time for your medicine' : 'Time for $name',
          body: dosage == null || dosage.isEmpty
              ? 'Tap Taken once you have had it.'
              : '$dosage — tap Taken once you have had it.',
          payload: id,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelReminders,
              'Medicine reminders',
              channelDescription: 'When it is time to take a medicine.',
              importance: Importance.high,
              priority: Priority.high,
              actions: <AndroidNotificationAction>[
                // The entire design rests on this button. Tapping it records
                // the dose without opening the app, at the moment the tablet
                // is in your hand — which is the only moment the record can
                // be honest.
                AndroidNotificationAction(
                  _takenActionId,
                  'Taken',
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
              ],
            ),
          ),
        );
        scheduled++;
      }
    } catch (err) {
      debugPrint('Could not schedule dose reminders: $err');
    }
  }

  /// Sends any "Taken" taps that happened while the app was closed.
  ///
  /// Call on startup. Each entry carries the time of the tap, so a late sync
  /// still records the right minute.
  Future<int> flushPendingMarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_pendingKey) ?? <String>[];
      if (raw.isEmpty) return 0;

      final unsent = <String>[];
      var sent = 0;
      for (final entry in raw) {
        try {
          final map = jsonDecode(entry) as Map<String, dynamic>;
          await _markTaken(
            map['dose_id'] as String,
            takenAt: map['taken_at'] as String?,
          );
          sent++;
        } catch (_) {
          // Keep anything that failed — a dropped connection must not silently
          // erase the fact that somebody took their tablet.
          unsent.add(entry);
        }
      }
      await prefs.setStringList(_pendingKey, unsent);
      return sent;
    } catch (err) {
      debugPrint('Could not flush dose marks: $err');
      return 0;
    }
  }

  Future<void> _markTaken(String doseId, {String? takenAt}) async {
    await _client.from('medication_doses').update({
      'status': 'taken',
      'taken_at': takenAt ?? DateTime.now().toUtc().toIso8601String(),
    }).eq('id', doseId);
  }

  /// Cancels every scheduled alarm — on sign-out, so a phone handed to somebody
  /// else does not keep announcing a stranger's medicines.
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}

/// Runs in the main isolate, so Supabase is available and the dose can be
/// recorded immediately rather than queued.
void _onForegroundResponse(NotificationResponse response) {
  if (response.actionId != _takenActionId) return;
  final doseId = response.payload;
  if (doseId == null || doseId.isEmpty) return;
  final client = Supabase.instance.client;
  client
      .from('medication_doses')
      .update({
        'status': 'taken',
        'taken_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', doseId)
      // If this fails the queue is the safety net: it is retried from disk on
      // the next open.
      .then((_) {}, onError: (Object err) {
        debugPrint('Immediate dose mark failed, queueing: $err');
        _queueDoseMark(doseId);
      });
}
