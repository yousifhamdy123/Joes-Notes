import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'store.dart';

const _kBackupNotifId = 7001;

const _labels = {
  'ar': ['تمّت', 'أجّل 10 دقائق'],
  'en': ['Done', 'Snooze 10 min'],
};

Future<void> _initTz() async {
  tzdata.initializeTimeZones();
  try {
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
  } catch (_) {}
}

NotificationDetails _details(String lang) {
  final l = _labels[lang] ?? _labels['ar']!;
  return NotificationDetails(
    android: AndroidNotificationDetails(
      'task_reminders',
      'Task reminders',
      channelDescription: 'Reminders for your tasks',
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('done', l[0], cancelNotification: true),
        AndroidNotificationAction('snooze', l[1], cancelNotification: true),
      ],
    ),
  );
}

/// Runs when the user taps "Done" / "Snooze" on a reminder, even if the app
/// is closed (separate isolate, so it works on the saved data directly).
@pragma('vm:entry-point')
void notificationActionBackground(NotificationResponse r) {
  _handleAction(r);
}

Future<void> _handleAction(NotificationResponse r) async {
  final action = r.actionId;
  final taskId = r.payload;
  if (action == null || action.isEmpty || taskId == null) return;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString('tasks');
    if (raw == null) return;
    final list = (jsonDecode(raw) as List)
        .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final idx = list.indexWhere((e) => e.id == taskId);
    if (idx < 0) return;
    final t = list[idx];
    final plugin = FlutterLocalNotificationsPlugin();

    if (action == 'done') {
      if (t.repeats) {
        t.remind = t.nextAfter(DateTime.now());
        for (final s in t.subtasks) {
          s.done = false;
        }
      } else {
        t.done = true;
      }
      await prefs.setString(
          'tasks', jsonEncode(list.map((e) => e.toJson()).toList()));
      await plugin.cancel(t.notifId + 1);
    } else if (action == 'snooze') {
      await _initTz();
      await plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
      final lang = prefs.getString('lang') ?? 'ar';
      await plugin.zonedSchedule(
        t.notifId + 1,
        t.title,
        t.note.isEmpty ? "Joe's Notes" : t.note,
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10)),
        _details(lang),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: t.id,
      );
    }
  } catch (_) {}
}

class Notifier {
  static final FlutterLocalNotificationsPlugin _p =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    await _initTz();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _p.initialize(
      settings,
      onDidReceiveNotificationResponse: (r) async {
        await _handleAction(r);
        await Store.i.reloadTasks();
      },
      onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
    );

    final android = _p.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    await setBackupReminder(Store.i.backupReminder,
        lang: Store.i.lang.value);
  }

  static DateTimeComponents? _match(String repeat) {
    switch (repeat) {
      case 'daily':
        return DateTimeComponents.time;
      case 'weekly':
        return DateTimeComponents.dayOfWeekAndTime;
      case 'monthly':
        return DateTimeComponents.dayOfMonthAndTime;
      default:
        return null;
    }
  }

  /// Cancels any existing alarm for the task, then schedules a new one
  /// if the task is open and has a reminder.
  static Future<void> sync(TaskItem t) async {
    await _p.cancel(t.notifId);
    await _p.cancel(t.notifId + 1);
    final when = t.remind;
    if (t.done || when == null) return;
    final now = DateTime.now();
    var start = when;
    if (!when.isAfter(now)) {
      if (!t.repeats) return;
      start = t.nextAfter(now) ?? when;
    }

    final lang = Store.i.lang.value;
    final date = tz.TZDateTime.from(start, tz.local);
    final body = t.note.isEmpty ? "Joe's Notes" : t.note;
    Future<void> schedule(AndroidScheduleMode mode) => _p.zonedSchedule(
          t.notifId,
          t.title,
          body,
          date,
          _details(lang),
          androidScheduleMode: mode,
          payload: t.id,
          matchDateTimeComponents: _match(t.repeat),
        );
    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      // Exact alarms not permitted: fall back to an inexact one.
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  static Future<void> cancel(int id) async {
    await _p.cancel(id);
    await _p.cancel(id + 1);
  }

  /// Weekly reminder (Friday, 10:00) to save a backup.
  static Future<void> setBackupReminder(bool on,
      {String lang = 'ar'}) async {
    await _p.cancel(_kBackupNotifId);
    if (!on) return;
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);
    while (d.weekday != DateTime.friday || !d.isAfter(now)) {
      d = d.add(const Duration(days: 1));
    }
    const title = "Joe's Notes";
    final body = lang == 'ar'
        ? 'وقت النسخ الاحتياطي! افتح التطبيق واحفظ نسخة في Google Drive.'
        : 'Backup time! Open the app and save a copy to Google Drive.';
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'backup_reminder',
        'Backup reminder',
        channelDescription: 'Weekly reminder to back up your data',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    try {
      await _p.zonedSchedule(
        _kBackupNotifId,
        title,
        body,
        d,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {}
  }
}
