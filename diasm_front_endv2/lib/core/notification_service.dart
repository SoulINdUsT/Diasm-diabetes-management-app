
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static Future<void> init() async {
    // Timezone init
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidInit,
    );

    await _plugin.initialize(initSettings);

    // DEBUG (safe to remove later)
    print('NotificationService initialized. tz.local=${tz.local.name}');
  }

  static Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test channel for notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.show(
      9999,
      'Test Notification',
      'This is working!',
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    bool repeatDaily = false,
  }) async {
    final now = DateTime.now();
    DateTime effective = scheduledAt;

    // Safety: ensure future time
    if (effective.isBefore(now)) {
      effective = effective.add(const Duration(days: 1));
    }

    // DEBUG
    print(
      'NOTI scheduleAt → id=$id repeatDaily=$repeatDaily '
      'time=$effective tz=${tz.local.name}',
    );

    const androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    final details = const NotificationDetails(android: androidDetails);

    final tzTime = tz.TZDateTime.from(effective, tz.local);

    if (repeatDaily) {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
