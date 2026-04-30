import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/risk_models.dart';
import '../../core/risk_repository.dart';
import '../../core/widgets/app_drawer.dart';

import 'package:fl_chart/fl_chart.dart';

// Monitoring
import '../../core/monitoring_repository.dart';

import 'package:intl/intl.dart';

// Lifestyle / Meal plan
import 'package:diasm_front_endv2/core/lifestyle_repository.dart';
import 'package:diasm_front_endv2/core/lifestyle_models.dart';

// Reminders
import '../../core/reminder_models.dart';
import '../../core/reminder_repository.dart';

// Daily Wellness / Right Path
import '../../core/rightpath_models.dart';
import '../../core/rightpath_repository.dart';
import 'widgets/daily_wellness_card.dart';

import 'daily_wellness_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isBangla = false;
  bool _isLoadingRisk = true;
  String? _riskError;
  RiskAssessment? _latestAssessment;

  // ---------------- Glucose chart series colors ----------------
 // Series colors (ONE source of truth)
static const Color _cBefore  = Color(0xFFFDF902); // yellow
static const Color _cAfter   = Color(0xFF7C3AED); // 
static const Color _cBedtime = Color(0xFFFFB109); // orange

  // ---------------- Monitoring State ----------------
  final MonitoringRepository _monitoringRepo = MonitoringRepository();
  bool _isLoadingMonitoringSummary = false;
  double? _todayGlucoseMgdl;
  DateTime? _todayGlucoseTime;

  // Glucose chart: 7-day values (oldest → newest)
  // NEW: 3-series chart (oldest → newest)
  List<double?> _glucoseLast7Days = List.filled(7, null);

  List<double?> _glucoseBeforeLast7Days = List.filled(7, null);   // FBS + BeforeMeal
  List<double?> _glucoseAfterLast7Days = List.filled(7, null);    // PP2 + AfterMeal
  List<double?> _glucoseBedtimeLast7Days = List.filled(7, null);  // Bedtime

  // Other latest metrics (mini cards)
  double? _latestWeightKg;
  int? _latestSteps;
  String? _latestBpText; // "120/80" style
  String? _latestCholesterolText; // e.g. "LDL 120, HDL 45"

  // ---------------- Daily Wellness / Right Path State ----------------
  final RightPathRepository _rightPathRepo = RightPathRepository();
  RightPathTodayStatus? _rightPathToday;
  RightPathWeeklySummary? _rightPathWeekly;

  // ---------------- Meal Plan / Lifestyle State ----------------
  final LifestyleRepository _lifestyleRepo = LifestyleRepository();
  bool _isLoadingMealSummary = false;
  MealPlan? _homeMealPlan;

  // ---------------- Reminders State ----------------
  final ReminderRepository _reminderRepo = ReminderRepository.fromClient();
  bool _isLoadingReminders = false;
  List<Reminder> _homeReminders = [];

  @override
  void initState() {
    super.initState();
    _loadLatestAssessment();
    _loadRightPathSummary();
    _loadMonitoringSummary();
    _loadMetricsSnapshot();
    _loadMealPlanSummary();
    _loadReminderSummary();
  }

  // ---------------- Load Risk Assessment ----------------
  Future<void> _loadLatestAssessment() async {
    setState(() {
      _isLoadingRisk = true;
      _riskError = null;
    });

    try {
      final result = await RiskRepository().getLatestAssessment();

      if (!mounted) return;
      setState(() {
        _latestAssessment = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _riskError = _isBangla
            ? 'ঝুঁকি তথ্য লোড করতে সমস্যা হয়েছে। একটু পরে আবার চেষ্টা করুন।'
            : 'Failed to load risk information. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingRisk = false;
      });
    }
  }


// ---------------- Load Daily Wellness / Right Path Summary ----------------
Future<void> _loadRightPathSummary() async {
  try {
    final today = await _rightPathRepo.getTodayStatus();
    final weekly = await _rightPathRepo.getWeeklySummary();
    if (!mounted) return;
    setState(() {
      _rightPathToday = today;
      _rightPathWeekly = weekly;
    });
  } catch (_) {
    // ✅ IMPORTANT: don't silently do nothing; fallback to cache
    final cachedToday = await _rightPathRepo.getCachedTodayStatus();
    if (!mounted) return;
    setState(() {
      _rightPathToday = cachedToday; // show saved score even if API fails
      // keep weekly as-is (or null) to avoid wrong data
    });
  }
}

////////////monitoring summary
Future<void> _loadMonitoringSummary() async {
  if (!mounted) return;

  setState(() {
    _isLoadingMonitoringSummary = true;
    _todayGlucoseMgdl = null;
    _todayGlucoseTime = null;

    _glucoseLast7Days = List.filled(7, null);
    _glucoseBeforeLast7Days = List.filled(7, null);
    _glucoseAfterLast7Days = List.filled(7, null);
    _glucoseBedtimeLast7Days = List.filled(7, null);
  });

  try {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startRange = today.subtract(const Duration(days: 6));

    double? latestMgdl;
    DateTime? latestTime;

    // Oldest → newest
    List<double?> last7Any = List.filled(7, null);
    List<double?> last7Before = List.filled(7, null);
    List<double?> last7After = List.filled(7, null);
    List<double?> last7Bedtime = List.filled(7, null);

    // 1) Latest reading (dedicated endpoint)
    final latest = await _monitoringRepo.getLatestGlucose();
    if (latest != null) {
      latestMgdl = latest.valueMgdl;
      final t = latest.measuredAt;
      latestTime = (t == null) ? null : t.toLocal();
    }

    // 2) For chart: load last 7 days rows
    final res = await _monitoringRepo.listGlucose(
      page: 1,
      limit: 500,
      from: _fmtDate(startRange),
      to: _fmtDate(today),
    );

    final rowsRaw = _extractRows(res);

    // Normalize into a typed list of maps (prevents runtime surprises)
    final rows = <Map<String, dynamic>>[];
    for (final r in rowsRaw) {
      if (r is Map<String, dynamic>) rows.add(r);
    }

    if (rows.isNotEmpty) {
      // Ensure newest-first so "first seen wins" == latest per day
      rows.sort((a, b) {
        final aTime =
            DateTime.tryParse(a['measured_at']?.toString() ?? '')?.toLocal() ??
                startRange;
        final bTime =
            DateTime.tryParse(b['measured_at']?.toString() ?? '')?.toLocal() ??
                startRange;
        return bTime.compareTo(aTime);
      });

      bool isBeforeKind(String k) => k == 'FBS' || k == 'BeforeMeal';
      bool isAfterKind(String k) => k == 'PP2' || k == 'AfterMeal';
      bool isBedtimeKind(String k) => k == 'Bedtime';

      // latest per day for each series
      final Map<String, double> dayLastAny = {};
      final Map<String, double> dayLastBefore = {};
      final Map<String, double> dayLastAfter = {};
      final Map<String, double> dayLastBedtime = {};

      for (final row in rows) {
        final v = double.tryParse(row['value_mgdl']?.toString() ?? '');
        if (v == null) continue;

        final t =
            DateTime.tryParse(row['measured_at']?.toString() ?? '')?.toLocal();
        if (t == null) continue;

        final d = DateTime(t.year, t.month, t.day);
        if (d.isBefore(startRange) || d.isAfter(today)) continue;

        final key = _fmtDate(d);
        final kind = (row['kind'] ?? '').toString();

        // any series: keep latest per day
        dayLastAny.putIfAbsent(key, () => v);

        // split series: keep latest per day in each kind
        if (isBeforeKind(kind)) {
          dayLastBefore.putIfAbsent(key, () => v);
        } else if (isAfterKind(kind)) {
          dayLastAfter.putIfAbsent(key, () => v);
        } else if (isBedtimeKind(kind)) {
          dayLastBedtime.putIfAbsent(key, () => v);
        }
      }

      // materialize into 7-day arrays, oldest → newest
      last7Any = List.generate(7, (i) {
        final d = startRange.add(Duration(days: i));
        return dayLastAny[_fmtDate(d)];
      });

      last7Before = List.generate(7, (i) {
        final d = startRange.add(Duration(days: i));
        return dayLastBefore[_fmtDate(d)];
      });

      last7After = List.generate(7, (i) {
        final d = startRange.add(Duration(days: i));
        return dayLastAfter[_fmtDate(d)];
      });

      last7Bedtime = List.generate(7, (i) {
        final d = startRange.add(Duration(days: i));
        return dayLastBedtime[_fmtDate(d)];
      });
    }

    if (!mounted) return;
    setState(() {
      _todayGlucoseMgdl = latestMgdl;
      _todayGlucoseTime = latestTime;

      _glucoseLast7Days = last7Any;
      _glucoseBeforeLast7Days = last7Before;
      _glucoseAfterLast7Days = last7After;
      _glucoseBedtimeLast7Days = last7Bedtime;

      _isLoadingMonitoringSummary = false;
    });
  } catch (_) {
    if (!mounted) return;
    setState(() {
      _isLoadingMonitoringSummary = false;
    });
  }
}


  // ---------------- Load dashboard snapshot for other metrics ----------------
  Future<void> _loadMetricsSnapshot() async {
    try {
      final snap = await _monitoringRepo.getDashboardSnapshot();
      if (!mounted) return;

      setState(() {
        // From DashboardSnapshot:
        // lastWeightKg, lastSteps, lastBp (e.g. "120/80"),
        // lastCholHdl, lastCholLdl, lastCholTotal, lastHba1c, etc.
        _latestWeightKg = snap.lastWeightKg;
        _latestSteps = snap.lastSteps;

        // BP – backend already gives "120/80" in lastBp
        if (snap.lastBp != null && snap.lastBp!.trim().isNotEmpty) {
          _latestBpText = snap.lastBp;
        } else {
          _latestBpText = null;
        }

        // Cholesterol – prefer LDL/HDL; fall back to total
        if (snap.lastCholLdl != null && snap.lastCholHdl != null) {
          _latestCholesterolText =
              'LDL ${snap.lastCholLdl!.toStringAsFixed(0)}, '
              'HDL ${snap.lastCholHdl!.toStringAsFixed(0)}';
        } else if (snap.lastCholTotal != null) {
          _latestCholesterolText =
              'Total ${snap.lastCholTotal!.toStringAsFixed(0)}';
        } else {
          _latestCholesterolText = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      // Keep previous values; no crash on snapshot failure
    }
  }

  // ---------------- Load Meal Plan Summary ----------------
  Future<void> _loadMealPlanSummary() async {
    setState(() {
      _isLoadingMealSummary = true;
      _homeMealPlan = null;
    });

    try {
      final snapshot = await _lifestyleRepo.getSnapshot();

      MealPlan? plan;
      if (snapshot != null && snapshot.mealplan is Map<String, dynamic>) {
        plan = MealPlan.fromJson(
          snapshot.mealplan as Map<String, dynamic>,
        );
      }

      if (!mounted) return;
      setState(() {
        _homeMealPlan = plan;
        _isLoadingMealSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMealSummary = false;
      });
    }
  }

  // ---------------- Load Reminder Summary ----------------
  Future<void> _loadReminderSummary() async {
    setState(() {
      _isLoadingReminders = true;
      _homeReminders = [];
    });

    try {
      final list = await _reminderRepo.getReminders(active: true);
      if (!mounted) return;

      list.sort((a, b) => a.startDate.compareTo(b.startDate));

      setState(() {
        _homeReminders = list;
        _isLoadingReminders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingReminders = false;
      });
    }
  }

  // ---------------- Helper Functions ----------------
  String _fmtDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  List _extractRows(Map<String, dynamic> res) {
    if (res['rows'] is List) return res['rows'];
    if (res['items'] is List) return res['items'];
    if (res['data'] is List) return res['data'];
    return const [];
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return _isBangla ? 'এইমাত্র' : 'Just now';
    if (diff.inMinutes < 60) {
      return _isBangla
          ? '${diff.inMinutes} মিনিট আগে'
          : '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return _isBangla ? '${diff.inHours} ঘণ্টা আগে' : '${diff.inHours}h ago';
    }

    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');

    return _isBangla ? '$d-$m-$y, $hh:$mm' : '$d-$m-$y, $hh:$mm';
  }

  String _formatTimeOfDayDisplay(String raw) {
    final parts = raw.split(':');
    int h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    int m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    final isPm = h >= 12;
    int displayHour = h % 12;
    if (displayHour == 0) displayHour = 12;
    final mm = m.toString().padLeft(2, '0');
    final suffix = isPm ? 'PM' : 'AM';
    return '$displayHour:$mm $suffix';
  }

  String _formatReminderTimeLabel(Reminder r) {
    final times = r.timesJson;
    if (times != null && times.isNotEmpty) {
      final tStr = _formatTimeOfDayDisplay(times.first);
      return _isBangla ? 'সময়: $tStr' : 'Time: $tStr';
    }

    final d = r.startDate;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year.toString()}';
    return _isBangla ? 'শুরু: $dateStr' : 'Starts: $dateStr';
  }

  // ---------------- Monitoring summary body (used in Quick Actions tile) ----
  Widget _buildMonitoringSummaryBody() {
    if (_isLoadingMonitoringSummary) {
      return Row(
        children: const [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 10),
          Text(
            'Loading data...',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      );
    }

    if (_todayGlucoseMgdl == null || _todayGlucoseTime == null) {
      return Text(
        _isBangla ? 'আজ কোনো গ্লুকোজ রেকর্ড নেই' : 'No data logged today',
        style: const TextStyle(color: Colors.black54, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isBangla ? 'আজকের সর্বশেষ গ্লুকোজ' : 'Latest glucose today',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          '${_todayGlucoseMgdl!.toStringAsFixed(0)} mg/dL',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          (_isBangla ? 'আপডেট: ' : 'Updated: ') +
              _formatTimeAgo(_todayGlucoseTime!),
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }

  // ---------------- Meal Plan summary body ----------------
  // ---------------- Meal Plan summary body ----------------
Widget _buildMealPlanSummaryBody() {
  if (_isLoadingMealSummary) {
    return Row(
      children: const [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
        SizedBox(width: 10),
        Text(
          'Loading meal plan...',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ],
    );
  }

  final plan = _homeMealPlan;
  if (plan == null) {
    return Text(
      _isBangla
          ? 'কোনো মিল প্ল্যান সেট করা নেই। বিস্তারিত দেখতে ট্যাপ করুন।'
          : 'No meal plan set yet. Tap to view details.',
      style: const TextStyle(color: Colors.black54, fontSize: 13),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  final totalKcal = plan.calories.round();

  double sumMealKcal(String key) {
    final items = plan.itemsByMeal[key] ?? const <MealItem>[];
    double t = 0;
    for (final i in items) {
      t += i.calories ?? 0;
    }
    return t;
  }

  final breakfastKcal = sumMealKcal('breakfast').round();
  final lunchKcal = sumMealKcal('lunch').round();
  final dinnerKcal = sumMealKcal('dinner').round();

  final line1 = _isBangla
      ? 'আজকের প্ল্যান: $totalKcal ক্যালরি'
      : "Today's Plan: $totalKcal kcal";

  final line2 = _isBangla
      ? 'ব্রেকফাস্ট $breakfastKcal | লাঞ্চ $lunchKcal | ডিনার $dinnerKcal'
      : 'Breakfast $breakfastKcal | Lunch $lunchKcal | Dinner $dinnerKcal';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        line1,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 2),
      Text(
        line2,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 13,
          height: 1.2,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
      ),
    ],
  );
}

  // ---------------- Education tile body ----------------
  Widget _buildEducationTileBody() {
    final isEnglish = !_isBangla;

    final line1 =
        isEnglish ? 'Tap to view lessons' : 'পাঠসমূহ দেখতে ট্যাপ করুন';

    final line2 = isEnglish
        ? 'Topics: diet, exercise, complications, coping'
        : 'বিষয়: খাদ্য, ব্যায়াম, জটিলতা, মানসিক সহায়তা';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          line1,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          line2,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  // ---------------- Reminder tile body ----------------
 // ---------------- Reminder tile body ----------------
// ---------------- Reminder tile body ----------------
Widget _buildReminderSummaryBody() {
  if (_isLoadingReminders) {
    return Row(
      children: const [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
        SizedBox(width: 10),
        Text(
          'Loading reminders...',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 13,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  if (_homeReminders.isEmpty) {
    return Text(
      _isBangla ? 'কোনো রিমাইন্ডার সেট নেই।' : 'No reminders set.',
      style: const TextStyle(
        color: Colors.black54,
        fontSize: 13,
        height: 1.2,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  final r1 = _homeReminders.first;
  final Reminder? r2 = _homeReminders.length > 1 ? _homeReminders[1] : null;

  final nextTitle =
      _isBangla ? 'পরবর্তী: ${r1.title}' : 'Next: ${r1.title}';
  final nextTime = _formatReminderTimeLabel(r1);

  final thenLine = r2 == null
      ? null
      : (_isBangla ? 'তারপর: ${r2.title}' : 'Then: ${r2.title}');

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min, // ✅ prevents bottom overflow
    children: [
      Text(
        nextTitle,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          height: 1.15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 2), // ✅ reduced
      Text(
        nextTime,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 12,
          height: 1.1, // ✅ tightened line height
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      if (thenLine != null) ...[
        const SizedBox(height: 4), // ✅ reduced
        Text(
          thenLine,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 12,
            height: 1.1, // ✅ tightened
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ],
  );
}



  // ===================================================================
  // NEW DASHBOARD HELPERS
  // ===================================================================

  void _toggleLanguage(bool isBangla) {
    setState(() => _isBangla = isBangla);
  }

  RiskLevel _mapBandToLevel(String band) {
    final b = band.toLowerCase();
    if (b.contains('high')) return RiskLevel.high;
    if (b.contains('moderate')) return RiskLevel.moderate;
    return RiskLevel.low;
  }

  Color _riskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return const Color(0xFF06B6A9);
      case RiskLevel.moderate:
        return const Color(0xFFFFA726);
      case RiskLevel.high:
        return const Color(0xFFE53935);
    }
  }

  String _riskTitle(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return _isBangla ? 'কম ঝুঁকি' : 'Low Risk';
      case RiskLevel.moderate:
        return _isBangla ? 'মধ্যম ঝুঁকি' : 'Moderate Risk';
      case RiskLevel.high:
        return _isBangla ? 'উচ্চ ঝুঁকি' : 'High Risk';
    }
  }

  Color _glucosePointColor(double v) {
    if (v < 70) {
      return const Color(0xFFFFA726); // low = amber
    } else if (v > 180) {
      return const Color(0xFFE53935); // high = red
    } else {
      return const Color(0xFF43A047); // in target = green
    }
  }

  String _formatTodayHeaderDate() {
    final now = DateTime.now();

    const weekdays = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final w = weekdays[now.weekday - 1];
    final m = months[now.month - 1];
    final d = now.day.toString().padLeft(2, '0');
    final y = now.year.toString();

    return '$w, $d $m $y';
  }

  Widget _buildHeroHeader(ThemeData theme) {
    const Color heroTeal = Color(0xFF0C8578); // same as AppBar
    const Color heroTealLight = Color(0xFF16BFA0);

    // Simple date line like "Tuesday, 10 December 2025"
    final now = DateTime.now();
    final dayNames = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final dateLineEn =
        '${dayNames[now.weekday % 7]}, ${now.day} ${monthNames[now.month - 1]} ${now.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [heroTeal, heroTealLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: language toggle + Take the test
          Row(
            children: [
              Expanded(child: _buildLanguageToggle()),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => context.push('/risk-form'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child:
                    Text(_isBangla ? 'ঝুঁকি পরীক্ষা করুন' : 'Take the test'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            _isBangla
                ? 'ডায়াবেটিস সেলফ-ম্যানেজমেন্ট'
                : 'Diabetes Self-Management',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 4),

          // Subtitle + date
          Text(
            _isBangla ? 'আজকের স্বাস্থ্য সারাংশ' : "Today's health summary",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _isBangla ? dateLineEn : dateLineEn, // you can localize later
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayGlucoseCard(ThemeData theme) {
    String statusLabel = _isBangla ? 'কোনো তথ্য নেই' : 'No data';
    Color statusColor = Colors.grey;

    if (_todayGlucoseMgdl != null) {
      final v = _todayGlucoseMgdl!;
      if (v < 70) {
        statusLabel = _isBangla ? 'কম' : 'Low';
        statusColor = const Color(0xFFFB8C00);
      } else if (v > 180) {
        statusLabel = _isBangla ? 'উচ্চ' : 'High';
        statusColor = const Color(0xFFE53935);
      } else {
        statusLabel = _isBangla ? 'টার্গেটের ভিতরে' : 'In target';
        statusColor = const Color(0xFF43A047);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isLoadingMonitoringSummary
          ? Row(
              children: const [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                SizedBox(width: 10),
                Text(
                  'Loading glucose...',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bloodtype_outlined,
                          size: 20,
                          color: Color(0xFF1565C0),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isBangla ? 'আজকের গ্লুকোজ' : 'Today’s glucose',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _todayGlucoseMgdl == null
                      ? (_isBangla ? '-- mg/dL' : '-- mg/dL')
                      : '${_todayGlucoseMgdl!.toStringAsFixed(0)} mg/dL',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                if (_todayGlucoseTime != null)
                  Text(
                    (_isBangla ? 'আপডেট: ' : 'Updated: ') +
                        _formatTimeAgo(_todayGlucoseTime!),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  )
                else
                  Text(
                    _isBangla
                        ? 'আজ কোনো গ্লুকোজ রেকর্ড নেই'
                        : 'No glucose logged today',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
    );
  }

Widget _buildGlucoseMainChartCard(ThemeData theme) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------------- Header ----------------
        Row(
          children: [
            Text(
              _isBangla ? 'রক্তে গ্লুকোজ (শেষ ৭ দিন)' : 'Blood glucose (last 7 days)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              _isBangla ? 'চার্ট' : 'Chart',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black54,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ---------------- Chart ----------------
        SizedBox(
          height: 180,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FB),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: LineChart(
              _buildGlucoseChartData(),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ---------------- Series legend ----------------
        Row(
          children: [
            _buildLegendDot(_cBefore),
            Text(
              _isBangla ? 'খাবারের আগে' : 'Before meal',
              style: TextStyle(fontSize: 11, color: const Color(0xFF9A8F00)),
            ),
            const SizedBox(width: 12),

            _buildLegendDot(_cAfter),
            Text(
              _isBangla ? 'খাবারের পরে' : 'After meal',
              style: TextStyle(fontSize: 11, color: _cAfter),
            ),
            const SizedBox(width: 12),

            _buildLegendDot(_cBedtime),
            Text(
              _isBangla ? 'ঘুমের আগে' : 'Bedtime',
              style: TextStyle(fontSize: 11, color: _cBedtime),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // ---------------- Zone legend (dot meaning) ----------------
        Row(
          children: [
            _buildLegendDot(const Color(0xFF1E88E5)),
            Text(
              _isBangla ? 'কম' : 'Low',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(width: 12),

            _buildLegendDot(const Color(0xFF43A047)),
            Text(
              _isBangla ? 'টার্গেট' : 'In target',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(width: 12),

            _buildLegendDot(const Color(0xFFE53935)),
            Text(
              _isBangla ? 'উচ্চ' : 'High',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ],
    ),
  );
}




LineChartData _buildGlucoseChartData() {
  final before = _glucoseBeforeLast7Days;
  final after = _glucoseAfterLast7Days;
  final bedtime = _glucoseBedtimeLast7Days;

  final hasAnyData =
      before.any((v) => v != null) ||
      after.any((v) => v != null) ||
      bedtime.any((v) => v != null);

  // Placeholder if everything is empty
  final fallback = <double?>[120, 120, 120, 120, 120, 120, 120];

  // Collect all values for auto-scaling
  final allValues = <double>[];
  void collect(List<double?> xs) {
    for (final v in xs) {
      if (v != null) allValues.add(v);
    }
  }

  if (hasAnyData) {
    collect(before);
    collect(after);
    collect(bedtime);
  } else {
    collect(fallback);
  }

  double minY = 40;
  double maxY = 260;

  if (allValues.isNotEmpty) {
    final vMin = allValues.reduce((a, b) => a < b ? a : b);
    final vMax = allValues.reduce((a, b) => a > b ? a : b);
    minY = (vMin - 20).clamp(40, 400);
    maxY = (vMax + 20).clamp(80, 400);
    if (maxY <= minY) maxY = minY + 40;
  }

  int nonNullCount(List<double?> xs) => xs.whereType<double>().length;

  LineChartBarData series({
    required List<double?> values,
    required Color color,
  }) {
    final count = hasAnyData ? nonNullCount(values) : 7;

    // If there are <2 points, a line looks weird → show dots only.
    final showLine = count >= 2;

    return LineChartBarData(
      isCurved: showLine && count >= 3, // curve only when it makes sense
      barWidth: showLine ? 3 : 0, // hide line when too sparse
      color: color,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, barData) => spot != FlSpot.nullSpot,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3.2,
            color: color,
            strokeWidth: 1.5,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(show: false),
      spots: List.generate(7, (i) {
        final v = hasAnyData ? values[i] : fallback[i];
        return v == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), v);
      }),
    );
  }

  // --------- Target band shading (safe with autoscale) ----------
  // Low: <70, Target: 70-180, High: >180
  final List<HorizontalRangeAnnotation> bands = [];

  // Target band (only if it intersects visible range)
  final targetY1 = 70.0.clamp(minY, maxY);
  final targetY2 = 180.0.clamp(minY, maxY);
  if (targetY2 > targetY1) {
    bands.add(
      HorizontalRangeAnnotation(
        y1: targetY1,
        y2: targetY2,
        color: const Color(0xFF43A047).withOpacity(0.18), // ✅ increased
      ),
    );
  }

  // Low band (from minY up to 70) only if minY < 70
  if (minY < 70) {
    final lowY1 = minY;
    final lowY2 = 70.0.clamp(minY, maxY);
    if (lowY2 > lowY1) {
      bands.add(
        HorizontalRangeAnnotation(
          y1: lowY1,
          y2: lowY2,
          color: const Color(0xFF0084FF).withOpacity(0.14), // ✅ increased
        ),
      );
    }
  }

  // High band (from 180 to maxY) only if maxY > 180
  if (maxY > 180) {
    final highY1 = 180.0.clamp(minY, maxY);
    final highY2 = maxY;
    if (highY2 > highY1) {
      bands.add(
        HorizontalRangeAnnotation(
          y1: highY1,
          y2: highY2,
          color: const Color(0xFFE53935).withOpacity(0.12), // ✅ increased
        ),
      );
    }
  }

  return LineChartData(
    minX: 0,
    maxX: 6,
    minY: minY,
    maxY: maxY,

    // ✅ Band shading
    rangeAnnotations: RangeAnnotations(
      horizontalRangeAnnotations: bands,
    ),

    // ✅ Threshold lines at 70 and 180
    extraLinesData: ExtraLinesData(
      horizontalLines: [
        HorizontalLine(
          y: 70,
          color: const Color(0xFFFFA726).withOpacity(0.65),
          strokeWidth: 1.2,
          dashArray: [6, 6],
        ),
        HorizontalLine(
          y: 180,
          color: const Color(0xFFE53935).withOpacity(0.60),
          strokeWidth: 1.2,
          dashArray: [6, 6],
        ),
      ],
    ),

    gridData: FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: 40,
      getDrawingHorizontalLine: (value) => FlLine(
        color: const Color(0xFFE0E6F5),
        strokeWidth: 1,
      ),
    ),
    borderData: FlBorderData(show: false),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: 1, // ✅ force ticks at 0,1,2,3,4,5,6
          getTitlesWidget: (value, meta) {
            // ✅ show labels ONLY on integer ticks
            if (value % 1 != 0) return const SizedBox.shrink();

            final i = value.toInt();
            if (i < 0 || i > 6) return const SizedBox.shrink();

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final startRange = today.subtract(const Duration(days: 6));
            final d = startRange.add(Duration(days: i));

            const week3 = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            final label = week3[d.weekday - 1];

            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            );
          },
        ),
      ),
    ),

    // ✅ ONLY change here: use your class-level colors (so dots/lines match)
    lineBarsData: hasAnyData
        ? [
            series(values: before, color: _cBefore),   // Before
            series(values: after, color: _cAfter),     // After
            series(values: bedtime, color: _cBedtime), // Bedtime
          ]
        : [
            // fallback single line
            LineChartBarData(
              isCurved: true,
              barWidth: 3,
              color: const Color(0xFF1565C0),
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1565C0).withOpacity(0.20),
                    const Color(0xFF1565C0).withOpacity(0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              spots: List.generate(7, (i) => FlSpot(i.toDouble(), 120)),
            ),
          ],
  );
}

Widget _buildLegendDot(Color color) {
  return Container(
    width: 10,
    height: 10,
    margin: const EdgeInsets.only(right: 4),
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
    ),
  );
}

  Widget _buildMetricsHorizontalList(ThemeData theme) {
    final weightValue =
        _latestWeightKg != null ? '${_latestWeightKg!.toStringAsFixed(1)} kg' : '--';

    final stepsValue = _latestSteps != null ? _latestSteps!.toString() : '--';

    final bpValue = _latestBpText ?? '-- / --';

    final cholValue = _latestCholesterolText ?? '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isBangla ? 'অন্যান্য মেট্রিক' : 'Other metrics',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMiniMetricCard(
                  title: _isBangla ? 'ওজন' : 'Weight',
                  value: weightValue,
                  subtitle:
                      _isBangla ? 'শেষ ৭ দিনের ট্রেন্ড' : 'Last 7 days trend',
                ),
                _buildMiniMetricCard(
                  title: _isBangla ? 'পদক্ষেপ' : 'Steps',
                  value: stepsValue,
                  subtitle: _isBangla ? 'দৈনিক গড়' : 'Daily average',
                ),
                _buildMiniMetricCard(
                  title: _isBangla ? 'রক্তচাপ' : 'Blood pressure',
                  value: bpValue,
                  subtitle:
                      _isBangla ? 'শেষ রেকর্ড' : 'Last reading',
                ),
                _buildMiniMetricCard(
                  title: _isBangla ? 'কোলেস্টেরল' : 'Cholesterol',
                  value: cholValue,
                  subtitle: _isBangla ? 'এলডিএল / এইচডিএল' : 'LDL / HDL',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMetricCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
// ---------------- Other metrics section ----------------
Widget _buildOtherMetricsSection(ThemeData theme) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      Text(
        _isBangla ? 'অন্যান্য মেট্রিক্স' : 'Other metrics',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),

      // ✅ Option A: 2×2 responsive layout (no horizontal scroll)
      LayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          final cardWidth = (constraints.maxWidth - gap) / 2;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: cardWidth,
                child: _otherMetricCard(
                  icon: Icons.monitor_weight_outlined,
                  title: _isBangla ? 'ওজন' : 'Weight',
                  value: _latestWeightKg != null
                      ? _latestWeightKg!.toStringAsFixed(1)
                      : '--',
                  unit: 'kg',
                  helperText: _isBangla ? 'সর্বশেষ মাপ' : 'Last reading',
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _otherMetricCard(
                  icon: Icons.directions_walk_outlined,
                  title: _isBangla ? 'স্টেপস' : 'Steps',
                  value: _latestSteps != null ? _latestSteps.toString() : '--',
                  unit: '',
                  helperText: _isBangla ? 'আজকের মোট' : 'Today total',
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _otherMetricCard(
                  icon: Icons.favorite_border,
                  title: _isBangla ? 'ব্লাড প্রেসার' : 'Blood pressure',
                  value: _latestBpText ?? '-- / --',
                  unit: 'mmHg',
                  helperText: _isBangla ? 'সর্বশেষ মাপ' : 'Last reading',
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _otherMetricCard(
                  icon: Icons.bubble_chart_outlined,
                  title: _isBangla ? 'কোলেস্টেরল' : 'Cholesterol',
                  value: _latestCholesterolText != null
                      ? _latestCholesterolText!.split(',').first
                      : '--',
                  unit: 'mg/dL',
                  helperText: _isBangla ? 'LDL / HDL' : 'LDL / HDL',
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

// Mini metric card (UNCHANGED)
Widget _otherMetricCard({
  required IconData icon,
  required String title,
  required String value,
  required String unit,
  required String helperText,
}) {
  const Color borderTeal = Color(0xFF0C8578);

  return Container(
    height: 110,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
      border: const Border(
        top: BorderSide(color: Color(0xFFE5EDF2), width: 1),
        right: BorderSide(color: Color(0xFFE5EDF2), width: 1),
        bottom: BorderSide(color: Color(0xFFE5EDF2), width: 1),
        left: BorderSide(color: Color(0xFFE5EDF2), width: 1),
      ),
    ),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: borderTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(icon, size: 14, color: borderTeal),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                unit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 4),
        Text(
          helperText,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black45,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}




  // ===================================================================
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      drawer: AppDrawer(isEnglish: !_isBangla),
      appBar: AppBar(
        title: Text(
          _isBangla
              ? 'ডায়াবেটিস সেলফ-ম্যানেজমেন্ট'
              : 'Diabetes Self-Management',
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadLatestAssessment();
            await _loadRightPathSummary();
            await _loadMonitoringSummary();
            await _loadMetricsSnapshot();
            await _loadMealPlanSummary();
            await _loadReminderSummary();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroHeader(theme),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
        DailyWellnessCard(
  today: _rightPathToday,
  weekly: _rightPathWeekly,

  // NEW FIELD (only this!)
  glucoseMgdl: _todayGlucoseMgdl,

  isEnglish: !_isBangla,
  onTap: () async {
    final updated = await context.push(DailyWellnessScreen.routeName);

    if (!mounted) return;

    if (updated is RightPathTodayStatus) {
      setState(() {
        _rightPathToday = updated;
      });

      await _loadRightPathSummary();
    } else {
      await _loadRightPathSummary();
    }
  },
),




                      const SizedBox(height: 16),
                      _buildTodayGlucoseCard(theme),
                      const SizedBox(height: 16),
                      _buildGlucoseMainChartCard(theme),
                      const SizedBox(height: 16),
                      _buildOtherMetricsSection(theme),
                      const SizedBox(height: 24),
                      _buildQuickActionsSection(theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Language toggle ----------------
  Widget _buildLanguageToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE9F1F9),
        borderRadius: BorderRadius.circular(32),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleLanguage(false),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: !_isBangla ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: !_isBangla
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'English',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: !_isBangla ? Colors.black87 : Colors.grey[700],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleLanguage(true),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _isBangla ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: _isBangla
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'বাংলা',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _isBangla ? Colors.black87 : Colors.grey[700],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Full Risk Card ----------------
  Widget _buildRiskCard(ThemeData theme) {
    if (_isLoadingRisk) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            const SizedBox(
              height: 40,
              width: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _isBangla
                    ? 'ঝুঁকি তথ্য লোড হচ্ছে...'
                    : 'Loading risk information...',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    if (_riskError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFD32F2F)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _riskError!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: const Color(0xFFD32F2F)),
              ),
            ),
            IconButton(
              onPressed: _loadLatestAssessment,
              icon: const Icon(Icons.refresh, color: Color(0xFFD32F2F)),
            ),
          ],
        ),
      );
    }

    if (_latestAssessment == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isBangla
                  ? 'এখনও কোনো ঝুঁকি মূল্যায়ন করা হয়নি'
                  : 'No risk assessment yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _isBangla
                  ? 'আপনার প্রিডায়াবেটিস ও ডায়াবেটিস ঝুঁকি জানতে একটি দ্রুত মূল্যায়ন সম্পন্ন করুন।'
                  : 'Complete a quick assessment to know your risk of prediabetes and diabetes.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey[800], height: 1.5),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push('/risk-form'),
                icon: const Icon(Icons.arrow_forward),
                label: Text(_isBangla ? 'এখনই শুরু করুন' : 'Start now'),
              ),
            ),
          ],
        ),
      );
    }

    final assessment = _latestAssessment!;
    final level = _mapBandToLevel(assessment.band);
    final color = _riskColor(level);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.95),
                  color.withOpacity(0.75),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withOpacity(0.22),
                  child: const Icon(Icons.health_and_safety,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _riskTitle(level),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18)
                .copyWith(top: 12),
            child: Text(
              _isBangla ? assessment.messageBn : assessment.message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey[900], height: 1.5),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18)
                .copyWith(bottom: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildChip(
                  theme,
                  label: _isBangla
                      ? 'স্কোর: ${assessment.total}'
                      : 'Score: ${assessment.total}',
                ),
                if (assessment.submittedAt != null)
                  _buildChip(
                    theme,
                    label: _isBangla
                        ? 'আপডেট: ${_formatDateBangla(assessment.submittedAt!)}'
                        : 'Updated: ${_formatDate(assessment.submittedAt!)}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(ThemeData theme, {required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            theme.textTheme.bodySmall?.copyWith(color: Colors.grey[800]),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')} '
        '${_monthName(dt.month)} '
        '${dt.year}';
  }

  String _formatDateBangla(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')} '
        '${_monthName(dt.month)} '
        '${dt.year}';
  }

  String _monthName(int m) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return names[m - 1];
  }

  // ---------------- Quick Actions ----------------
Widget _buildQuickActionsSection(ThemeData theme) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _isBangla ? 'দ্রুত অ্যাকশন' : 'Quick Actions',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,

        // ✅ FIX: increase tile height (2.0 makes them too short → bottom overflow)
        childAspectRatio: 1.40,

        children: [
          _buildQuickTile(
            icon: Icons.restaurant_menu_outlined,
            titleEn: 'Lifestyle & Meals',
            titleBn: 'লাইফস্টাইল ও খাবার',
            onTap: () => context.go('/tools'),
            body: _buildMealPlanSummaryBody(),
          ),
          _buildQuickTile(
            icon: Icons.alarm_outlined,
            titleEn: 'Reminders',
            titleBn: 'রিমাইন্ডার',
            onTap: () => context.go('/reminders'),
            body: _buildReminderSummaryBody(),
          ),
        ],
      ),
    ],
  );
}

Widget _buildQuickTile({
  required IconData icon,
  required String titleEn,
  required String titleBn,
  required VoidCallback onTap,
  Widget? body,
}) {
  final isEnglish = !_isBangla;

  List<Color> headerColors() {
    return const [
      Color(0xFF0C8578),
      Color(0xFF129F8A),
    ];
  }

  Color bodyBackground() => Colors.white;

  IconData backgroundIcon() {
    final key = titleEn.toLowerCase();
    if (key.contains('monitor')) return Icons.monitor_heart_rounded;
    if (key.contains('education')) return Icons.menu_book_rounded;
    if (key.contains('lifestyle')) return Icons.restaurant_menu_rounded;
    if (key.contains('reminder')) return Icons.alarm_rounded;
    return Icons.info_outline_rounded;
  }

  return InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: bodyBackground(),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              gradient: LinearGradient(colors: headerColors()),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEnglish ? titleEn : titleBn,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // content
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: body ??
                          Text(
                            isEnglish
                                ? 'Tap to view details'
                                : 'বিস্তারিত দেখতে ট্যাপ করুন',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                              height: 1.2,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ✅ FIX: fixed-width icon area prevents right overflow
                  SizedBox(
                    width: 36,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Icon(
                        backgroundIcon(),
                        size: 34,
                        color: Colors.black.withOpacity(0.15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}