
import 'package:flutter/foundation.dart';

import 'notification_service.dart';
import 'reminder_models.dart';

class ReminderScheduler {
  // Reserve a block of IDs for each reminder
  static int _baseIdForReminder(int reminderId) => reminderId * 100;

  static Future<void> cancelForReminderId(int reminderId) async {
    if (kIsWeb) return;

    final base = _baseIdForReminder(reminderId);
    for (var i = 0; i < 20; i++) {
      await NotificationService.cancel(base + i);
    }
  }

  static Future<void> rescheduleForReminder(
    Reminder r, {
    required bool isEnglish,
  }) async {
    if (kIsWeb) return;

    print(
      'Reschedule reminder: id=${r.id}, title=${r.title}, '
      'active=${r.active}, timesJson=${r.timesJson}, '
      'interval=${r.intervalMinutes}',
    );

    await cancelForReminderId(r.id);

    if (!r.active) return;

    final now = DateTime.now();

    String body;
    if (isEnglish) {
      body = r.messageEn.isNotEmpty ? r.messageEn : r.messageBn;
    } else {
      body = r.messageBn.isNotEmpty ? r.messageBn : r.messageEn;
    }
    if (body.isEmpty) body = r.title;

    final title = r.title;

    // 1) Daily fixed times
    if (r.timesJson != null && r.timesJson!.isNotEmpty) {
      for (var i = 0; i < r.timesJson!.length && i < 20; i++) {
        final parts = r.timesJson![i].split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        var scheduled = DateTime(
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );

        if (scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }

        final notifId = _baseIdForReminder(r.id) + i;

        await NotificationService.scheduleAt(
          id: notifId,
          title: title,
          body: body,
          scheduledAt: scheduled,
          repeatDaily: true,
        );
      }
      return;
    }

    // 2) Interval reminder (one-shot)
    if (r.intervalMinutes != null && r.intervalMinutes! > 0) {
      final scheduled = now.add(Duration(minutes: r.intervalMinutes!));
      final notifId = _baseIdForReminder(r.id);

      await NotificationService.scheduleAt(
        id: notifId,
        title: title,
        body: body,
        scheduledAt: scheduled,
        repeatDaily: false,
      );
    }
  }
}
