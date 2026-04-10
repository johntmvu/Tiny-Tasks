import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'tinytasks_reminders';
  static const _channelName = 'Task Reminders';

  Future<void> initialize() async {
    tz.initializeTimeZones();
    final String localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request exact alarm permission (Android 12+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  /// Schedule a reminder for a task. Returns the notification id used.
  Future<int?> scheduleTaskReminder(Task task) async {
    if (task.time.isEmpty) return null;

    final scheduledDate = _parseScheduledDate(task.date, task.time);
    if (scheduledDate == null) return null;

    // Don't schedule for past times
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return null;

    final notifId = task.id ?? task.title.hashCode.abs() % 100000;

    await _plugin.zonedSchedule(
      notifId,
      'Upcoming Task',
      task.title,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    return notifId;
  }

  Future<void> cancelReminder(int notificationId) async {
    await _plugin.cancel(notificationId);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  tz.TZDateTime? _parseScheduledDate(String date, String time) {
    try {
      final dateParts = date.split('-');
      if (dateParts.length != 3) return null;
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      // time is stored as "2:30 PM" or "14:30"
      int hour;
      int minute;

      if (time.contains('AM') || time.contains('PM')) {
        final isPm = time.contains('PM');
        final timePart = time.replaceAll('AM', '').replaceAll('PM', '').trim();
        final parts = timePart.split(':');
        hour = int.parse(parts[0]);
        minute = int.parse(parts[1]);
        if (isPm && hour != 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
      } else {
        final parts = time.split(':');
        hour = int.parse(parts[0]);
        minute = int.parse(parts[1]);
      }

      return tz.TZDateTime(tz.local, year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }
}
