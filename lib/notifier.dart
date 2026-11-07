import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

class Notifier {
  static final FlutterLocalNotificationsPlugin _p =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {}

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _p.initialize(settings);

    final android = _p.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'task_reminders',
      'Task reminders',
      channelDescription: 'Reminders for your tasks',
      importance: Importance.max,
      priority: Priority.high,
    ),
  );

  /// Cancels any existing alarm for the task, then schedules a new one
  /// if the task is open and has a reminder in the future.
  static Future<void> sync(TaskItem t) async {
    await _p.cancel(t.notifId);
    final when = t.remind;
    if (t.done || when == null || !when.isAfter(DateTime.now())) return;

    final date = tz.TZDateTime.from(when, tz.local);
    final body = t.note.isEmpty ? "Joe's Notes" : t.note;
    try {
      await _p.zonedSchedule(
        t.notifId,
        t.title,
        body,
        date,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Exact alarms not permitted: fall back to an inexact one.
      await _p.zonedSchedule(
        t.notifId,
        t.title,
        body,
        date,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static Future<void> cancel(int id) => _p.cancel(id);
}
