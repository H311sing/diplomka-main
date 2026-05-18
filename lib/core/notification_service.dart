import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules local water & workout reminders. Reminders repeat daily at
/// fixed times; toggling happens from the Profile screen.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Reminders repeat every day at these local hours.
  static const List<int> waterHours = [10, 13, 16, 19];
  static const int workoutHour = 18;
  static const int _workoutId = 100;

  Future<void> init() async {
    // Local notifications have no web implementation — skip on web so the
    // app still starts in a browser.
    if (_initialized || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );
    _initialized = true;
  }

  /// Asks the OS for permission. Returns true if granted (or not required).
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final androidGranted =
        await android?.requestNotificationsPermission() ?? true;
    final iosGranted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;
    return androidGranted && iosGranted;
  }

  NotificationDetails _details(String channelId, String channelName) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  tz.TZDateTime _nextInstance(int hour, [int minute = 0]) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> scheduleWaterReminders() async {
    if (kIsWeb) return;
    await init();
    await cancelWaterReminders();
    for (var i = 0; i < waterHours.length; i++) {
      await _plugin.zonedSchedule(
        i,
        '💧 Hydration check',
        'Take a sip — keep your daily water goal on track.',
        _nextInstance(waterHours[i]),
        _details('water_reminders', 'Water Reminders'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelWaterReminders() async {
    if (kIsWeb) return;
    for (var i = 0; i < waterHours.length; i++) {
      await _plugin.cancel(i);
    }
  }

  Future<void> scheduleWorkoutReminder() async {
    if (kIsWeb) return;
    await init();
    await _plugin.zonedSchedule(
      _workoutId,
      '🔥 Time to train',
      "Don't break the streak — your workout is waiting.",
      _nextInstance(workoutHour),
      _details('workout_reminders', 'Workout Reminders'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelWorkoutReminder() async {
    if (kIsWeb) return;
    await _plugin.cancel(_workoutId);
  }
}
