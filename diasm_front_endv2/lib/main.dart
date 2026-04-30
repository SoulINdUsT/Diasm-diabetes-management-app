import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/app_router.dart';
import 'core/app_theme.dart';
import 'core/notification_service.dart';

import 'core/smart_nudge_scheduler.dart';

/// Request Android 13+ notification permission
Future<void> requestNotificationPermission() async {
  final androidPlugin =
      NotificationService.plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    await androidPlugin.requestNotificationsPermission();
  }
}

/// Request exact alarm permission (Android 12+)
Future<void> requestExactAlarmPermission() async {
  final androidPlugin =
      NotificationService.plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin == null) return;

  final canExact =
      await androidPlugin.canScheduleExactNotifications() ?? false;

  if (!canExact) {
    await androidPlugin.requestExactAlarmsPermission();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.init();
  await requestNotificationPermission();
  await requestExactAlarmPermission();

   await SmartNudgeScheduler.rescheduleDailyNudges(includeExtra: false); 

  runApp(const DIAsmApp());
}

class DIAsmApp extends StatelessWidget {
  const DIAsmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'DIAsm',
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
