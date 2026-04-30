import 'dart:math';
import 'package:timezone/timezone.dart' as tz;
import 'notification_service.dart';

/// Schedules "coach-like" nudges (7/day by default) at semi-random times
/// within fixed windows. Notifications will appear in Android notification bar.
///
/// Strategy:
/// - Use one-shot schedules (repeatDaily = false)
/// - On every app start: cancel our reserved IDs and reschedule
/// - No extra storage/deps needed
class SmartNudgeScheduler {
  // Reserve a safe ID range that won't collide with your reminder IDs (reminderId*100).
  // Pick a high block.
  static const int _baseId = 900000;
  static const int _maxNudges = 8; // you can increase if needed

  /// Call this on app start (after NotificationService.init + permissions).
  static Future<void> rescheduleDailyNudges({
    bool includeExtra = false, // set true if you want 8th nudge
  }) async {
    // 1) Clear previous smart nudges
    for (int i = 0; i < _maxNudges; i++) {
      await NotificationService.cancel(_baseId + i);
    }

    final now = tz.TZDateTime.now(tz.local);

    // Seed randomness per-day so it "changes day to day" but is stable during the day
    final seed = (now.year * 10000) + (now.month * 100) + now.day;
    final rng = Random(seed);

    // 2) Build today's plan (7 nudges)
    final items = <_NudgeSpec>[
      _NudgeSpec(
        key: 'glucose_morning',
        title: 'Glucose check',
        bodies: const [
          'Before breakfast: check your glucose.',
          'Good morning—please check glucose before eating.',
          'Before meal (morning): time to check glucose.',
        ],
        windowStart: const _Hm(6, 30),
        windowEnd: const _Hm(8, 30),
      ),
      _NudgeSpec(
        key: 'hydration_1',
        title: 'Hydration',
        bodies: const [
          'Have you drunk enough water this morning?',
          'Water check: drink a glass of water.',
          'Hydration reminder: take some water now.',
        ],
        windowStart: const _Hm(10, 0),
        windowEnd: const _Hm(12, 0),
      ),
      _NudgeSpec(
        key: 'glucose_after_lunch',
        title: 'Glucose check',
        bodies: const [
          'After lunch: check your glucose.',
          'Post-lunch glucose check time.',
          'Did you check glucose after lunch?',
        ],
        windowStart: const _Hm(13, 30),
        windowEnd: const _Hm(15, 0),
      ),
      _NudgeSpec(
        key: 'hydration_2',
        title: 'Hydration',
        bodies: const [
          'Hydration check: drink water now.',
          'Have some water—keep hydrated.',
          'Water reminder: take a few sips.',
        ],
        windowStart: const _Hm(16, 0),
        windowEnd: const _Hm(18, 0),
      ),
      _NudgeSpec(
        key: 'walking',
        title: 'Walking',
        bodies: const [
          'How many minutes did you walk today?',
          'A short walk now can help—try 10–20 minutes.',
          'Walking check: did you move today?',
        ],
        windowStart: const _Hm(17, 0),
        windowEnd: const _Hm(20, 0),
      ),
      _NudgeSpec(
        key: 'meal_time',
        title: 'Meals',
        bodies: const [
          'Meal timing check: did you eat on time?',
          'Try to keep dinner on time today.',
          'Meal reminder: eat on schedule if possible.',
        ],
        windowStart: const _Hm(19, 0),
        windowEnd: const _Hm(21, 0),
      ),
      _NudgeSpec(
        key: 'glucose_bedtime',
        title: 'Glucose check',
        bodies: const [
          'Bedtime glucose check time.',
          'Before sleep: please check your glucose.',
          'Night check: record glucose before bed.',
        ],
        windowStart: const _Hm(21, 0),
        windowEnd: const _Hm(22, 30),
      ),
    ];

    // Optional 8th nudge (if you want)
    if (includeExtra) {
      items.add(
        _NudgeSpec(
          key: 'extra',
          title: 'Health check',
          bodies: const [
            'Quick check: how are you feeling today?',
            'Small check-in: review your day’s health habits.',
            'Reminder: stay consistent—small steps matter.',
          ],
          windowStart: const _Hm(11, 30),
          windowEnd: const _Hm(12, 30),
        ),
      );
    }

    // 3) Generate times with spacing rule
    const minGapMinutes = 60; // prevents clustering
    final scheduledTimes = <tz.TZDateTime>[];

    for (int i = 0; i < items.length && i < _maxNudges; i++) {
      final spec = items[i];

      // Pick time within window; if today's window is already past, schedule for tomorrow's window.
      var when = _pickTimeInWindow(now, spec.windowStart, spec.windowEnd, rng);

      // Enforce minimum gap from already scheduled
      int guard = 0;
      while (_tooClose(when, scheduledTimes, minGapMinutes) && guard < 20) {
        when = _pickTimeInWindow(now, spec.windowStart, spec.windowEnd, rng);
        guard++;
      }

      scheduledTimes.add(when);

      final body = spec.bodies[rng.nextInt(spec.bodies.length)];
      await NotificationService.scheduleAt(
        id: _baseId + i,
        title: spec.title,
        body: body,
        scheduledAt: DateTime(
          when.year,
          when.month,
          when.day,
          when.hour,
          when.minute,
        ),
        repeatDaily: false, // IMPORTANT: one-shot
      );
    }
  }

  static bool _tooClose(
    tz.TZDateTime candidate,
    List<tz.TZDateTime> existing,
    int minGapMinutes,
  ) {
    for (final t in existing) {
      final diff = candidate.difference(t).inMinutes.abs();
      if (diff < minGapMinutes) return true;
    }
    return false;
  }

  static tz.TZDateTime _pickTimeInWindow(
    tz.TZDateTime now,
    _Hm start,
    _Hm end,
    Random rng,
  ) {
    // Determine date: today if window end not passed; otherwise tomorrow
    final windowEndToday = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      end.h,
      end.m,
    );

    final targetDate = windowEndToday.isAfter(now) ? now : now.add(const Duration(days: 1));

    final startDt = tz.TZDateTime(
      tz.local,
      targetDate.year,
      targetDate.month,
      targetDate.day,
      start.h,
      start.m,
    );

    final endDt = tz.TZDateTime(
      tz.local,
      targetDate.year,
      targetDate.month,
      targetDate.day,
      end.h,
      end.m,
    );

    final totalMinutes = endDt.difference(startDt).inMinutes.clamp(1, 24 * 60);
    final offset = rng.nextInt(totalMinutes);
    final picked = startDt.add(Duration(minutes: offset));

    // If we are generating for today and picked time already passed, push forward a bit
    if (picked.isBefore(now) && targetDate.day == now.day) {
      return now.add(const Duration(minutes: 5));
    }
    return picked;
  }
}

class _NudgeSpec {
  final String key;
  final String title;
  final List<String> bodies;
  final _Hm windowStart;
  final _Hm windowEnd;

  _NudgeSpec({
    required this.key,
    required this.title,
    required this.bodies,
    required this.windowStart,
    required this.windowEnd,
  });
}

class _Hm {
  final int h;
  final int m;
  const _Hm(this.h, this.m);
}
