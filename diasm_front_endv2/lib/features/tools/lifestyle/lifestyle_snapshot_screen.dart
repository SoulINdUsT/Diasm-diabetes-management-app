
import 'package:flutter/material.dart';

import 'package:diasm_front_endv2/core/lifestyle_models.dart';
import 'package:diasm_front_endv2/core/lifestyle_repository.dart';

import 'package:diasm_front_endv2/features/tools/lifestyle/hydration_log_screen.dart';
import 'package:diasm_front_endv2/features/tools/lifestyle/hydration_goal_screen.dart';

import 'package:diasm_front_endv2/features/tools/lifestyle/activity_log_screen.dart';
import 'package:diasm_front_endv2/features/tools/lifestyle/activity_history_screen.dart';
import 'package:diasm_front_endv2/features/tools/lifestyle/fasting_main_screen.dart';
import 'package:diasm_front_endv2/features/tools/lifestyle/mealplan_main_screen.dart';

class LifestyleSnapshotScreen extends StatefulWidget {
  final bool isEnglish;
  const LifestyleSnapshotScreen({super.key, required this.isEnglish});

  @override
  State<LifestyleSnapshotScreen> createState() => _LifestyleSnapshotScreenState();
}

class _LifestyleSnapshotScreenState extends State<LifestyleSnapshotScreen> {
  final _repo = LifestyleRepository();

  LifestyleSnapshot? _snapshot;
  bool _loading = true;
  String? _error;

  // Meal plan state
  bool _mealPlanLoading = true;
  List<MealPlanAssignment> _userMealPlans = const [];
  MealPlan? _activeMealPlan;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMealPlan();
  }

  // ---------------------------------------------------
  // LOAD SNAPSHOT
  // ---------------------------------------------------
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snap = await _repo.getSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load.';
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------
  // LOAD MEAL PLAN
  // ---------------------------------------------------
  Future<void> _loadMealPlan() async {
    setState(() {
      _mealPlanLoading = true;
    });

    try {
      final plans = await _repo.getUserMealPlans();
      MealPlanAssignment? active;

      if (plans.isNotEmpty) {
        try {
          active = plans.firstWhere((p) => p.active);
        } catch (_) {
          active = plans.first;
        }
      }

      MealPlan? plan;

      // Case 1: assignment exists
      if (active != null && active.mealPlanId > 0) {
        plan = await _repo.getMealPlanById(active.mealPlanId);
      }

      // Case 2: fallback to template
      if (plan == null) {
        final templates = await _repo.getAllMealPlans(limit: 1);
        if (templates.isNotEmpty) {
          final t = templates.first;
          plan = await _repo.getMealPlanById(t.id) ?? t;
        }
      }

      if (!mounted) return;
      setState(() {
        _userMealPlans = plans;
        _activeMealPlan = plan;
        _mealPlanLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userMealPlans = const [];
        _activeMealPlan = null;
        _mealPlanLoading = false;
      });
    }
  }

  // ---------------------------------------------------
  // HYDRATION HANDLERS
  // ---------------------------------------------------
  Future<void> _openAddWater() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HydrationLogScreen()),
    );
    if (result == true) await _load();
  }

  Future<void> _openSetGoal() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HydrationGoalScreen(isEnglish: widget.isEnglish),
      ),
    );
    if (result == true) await _load();
  }

  // ---------------------------------------------------
  // ACTIVITY HANDLERS
  // ---------------------------------------------------
  Future<void> _openLogActivity() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityLogScreen(isEnglish: widget.isEnglish),
      ),
    );
    if (result == true) await _load();
  }

  Future<void> _openActivityHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityHistoryScreen(isEnglish: widget.isEnglish),
      ),
    );
  }

  // ---------------------------------------------------
  // FASTING HANDLER
  // ---------------------------------------------------
  Future<void> _openFasting() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FastingMainScreen(isEnglish: widget.isEnglish),
      ),
    );
    await _load();
  }

  // ---------------------------------------------------
  // UI BUILD
  // ---------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isEn = widget.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Lifestyle Summary' : 'লাইফস্টাইল সারাংশ'),
      ),
      body: _buildBody(isEn),
      floatingActionButton: _buildFab(isEn),
    );
  }

  Widget _buildBody(bool isEn) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Text(isEn ? _error! : 'লোড করা যায়নি।'),
      );
    }

    if (_snapshot == null) {
      return Center(
        child: Text(isEn ? 'No data' : 'কোনো ডেটা নেই'),
      );
    }

    final activity = _snapshot!.activity;
    final hydration = _snapshot!.hydration;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildActivityCard(isEn, activity),
        const SizedBox(height: 16),
        _buildHydrationCard(isEn, hydration),
        const SizedBox(height: 16),
        _buildFastingCard(isEn),
        const SizedBox(height: 16),
        _buildMealPlanCard(isEn),
      ],
    );
  }

  // ---------------------------------------------------
  // ACTIVITY CARD
  // ---------------------------------------------------
  Widget _buildActivityCard(bool isEn, ActivitySummary activity) {
    if (activity.today.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn ? 'Activity Today' : 'আজকের কার্যকলাপ',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isEn
                    ? 'No activity logged yet.'
                    : 'আজ এখনও কোনো কর্মকাণ্ড যোগ করা হয়নি।',
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _openLogActivity,
                child: Text(
                  isEn ? 'Log Activity' : 'কর্মকাণ্ড যোগ করুন',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final row = activity.today.first as Map<String, dynamic>;
    final minutesStr = row['minutes']?.toString() ?? '0';
    final distanceStr = row['distance_km']?.toString() ?? '0';

    final todayMin = double.tryParse(minutesStr) ?? 0.0;
    const dailyGoalMin = 30.0;
    const weeklyGoalMin = 150.0;

    final dailyProgress = (todayMin / dailyGoalMin).clamp(0.0, 1.0);

    String weeklyText = '';
    if (activity.weekly.isNotEmpty) {
      final w = activity.weekly.first as Map<String, dynamic>;
      final totalMin = w['total_min_7d']?.toString() ?? '0';
      final avgMin = w['avg_min_per_day_7d']?.toString() ?? '0';

      if (isEn) {
        weeklyText = 'This Week: $totalMin / $weeklyGoalMin min · $avgMin min/day';
      } else {
        final totalBn = _toBanglaDigits(totalMin);
        final weeklyGoalBn = _toBanglaDigits(weeklyGoalMin.toStringAsFixed(0));
        final avgBn = _toBanglaDigits(avgMin);
        weeklyText = 'এই সপ্তাহ: $totalBn / $weeklyGoalBn মিনিট · গড়ে $avgBn মিনিট/দিন';
      }
    }

    final ringText = isEn
        ? '${todayMin.toStringAsFixed(0)}/${dailyGoalMin.toStringAsFixed(0)}'
        : _toBanglaDigits(
            '${todayMin.toStringAsFixed(0)}/${dailyGoalMin.toStringAsFixed(0)}',
          );

    final minutesLine = isEn
        ? 'Minutes today: ${todayMin.toStringAsFixed(0)}'
        : 'আজকের মিনিট: ${_toBanglaDigits(todayMin.toStringAsFixed(0))}';

    final distanceLine = isEn
        ? 'Distance: $distanceStr km'
        : 'দূরত্ব: ${_toBanglaDigits(distanceStr)} কিমি';

    final goalChipText = isEn
        ? 'Goal: ${dailyGoalMin.toStringAsFixed(0)} min'
        : 'লক্ষ্য: ${_toBanglaDigits(dailyGoalMin.toStringAsFixed(0))} মিনিট';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEn ? 'Activity Today' : 'আজকের কার্যকলাপ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    goalChipText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: dailyProgress,
                        strokeWidth: 8,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ringText,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            isEn ? 'min today' : 'মিনিট আজ',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(minutesLine, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(distanceLine, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      if (weeklyText.isNotEmpty)
                        Text(weeklyText, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _openActivityHistory,
                  child: Text(isEn ? 'History' : 'ইতিহাস'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _openLogActivity,
                  child: Text(isEn ? 'Log Activity' : 'কর্মকাণ্ড যোগ করুন'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // HYDRATION CARD
  // ---------------------------------------------------
  Widget _buildHydrationCard(bool isEn, HydrationSummary h) {
  const double defaultGoalMl = 2000.0; // 8 glasses * 250ml
  const double forcedGoalMl = 2000.0;

  final totalMl = (h.totalMl ?? 0).toDouble();
  final totalVal = totalMl.toStringAsFixed(0);
  final totalText = isEn ? '$totalVal ml' : '${_toBanglaDigits(totalVal)} মি.লি.';

  // Use server goal if present, otherwise fallback to default (frontend-only)
  final double goalMl = (h.goalMl != null && h.goalMl! > 0)
      ? h.goalMl!.toDouble()
      : defaultGoalMl;

 final goalVal = forcedGoalMl.toStringAsFixed(0);

final goalText = isEn
    ? 'Goal: $goalVal ml'
    : 'লক্ষ্য: ${_toBanglaDigits(goalVal)} মি.লি.';

final pct = forcedGoalMl <= 0 ? 0.0 : ((totalMl / forcedGoalMl) * 100).clamp(0.0, 999.0);
final pctVal = pct.toStringAsFixed(0);

final progressText = isEn
    ? 'Progress: $pctVal%'
    : 'অগ্রগতি: ${_toBanglaDigits(pctVal)}%';

  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn ? 'Hydration Today' : 'আজকের পানি',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            (isEn ? 'Total: ' : 'সর্বমোট: ') + totalText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(goalText, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(progressText, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ),
  );
}


  // ---------------------------------------------------
  // FASTING CARD
  // ---------------------------------------------------
  Widget _buildFastingCard(bool isEn) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEn ? 'Fasting' : 'উপবাস',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              isEn
                  ? 'Track your intermittent, religious or medical fasting in one place.'
                  : 'ইন্টারমিটেন্ট, ধর্মীয় বা চিকিৎসাগত উপবাস এক জায়গা থেকে ট্র্যাক করুন।',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _openFasting,
                child: Text(isEn ? 'Open Fasting Tracker' : 'উপবাস ট্র্যাকার খুলুন'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // MEAL PLAN CARD
  // ---------------------------------------------------
  Widget _buildMealPlanCard(bool isEn) {
    if (_mealPlanLoading) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final plan = _activeMealPlan;

    if (plan == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.restaurant_menu),
                  const SizedBox(width: 8),
                  Text(
                    isEn ? "Today's Meal Plan" : 'আজকের খাবার পরিকল্পনা',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isEn ? 'No meal plan assigned yet.' : 'এখনও কোনো মিল প্ল্যান সেট করা হয়নি।',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _openMealPlanDetail,
                  child: Text(isEn ? 'Browse plans' : 'প্ল্যান নির্বাচন করুন'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final kcalVal = plan.calories.toStringAsFixed(0);
    final buffer = StringBuffer();

    if (isEn) {
      buffer.write('$kcalVal kcal');
      if (plan.forDiabetesType != null && plan.forDiabetesType!.trim().isNotEmpty) {
        buffer.write(' / ${plan.forDiabetesType}');
      }
    } else {
      buffer.write('${_toBanglaDigits(kcalVal)} ক্যালরি');
      if (plan.forDiabetesType != null && plan.forDiabetesType!.trim().isNotEmpty) {
        buffer.write(' / ${plan.forDiabetesType}');
      }
    }

    final subtitle = buffer.toString();
    final mealOrder = ['breakfast', 'lunch', 'dinner'];
    final List<Widget> mealRows = [];

    for (final key in mealOrder) {
      final items = plan.itemsByMeal[key] ?? const <MealItem>[];
      if (items.isEmpty) continue;

      final label = _labelForMeal(key, isEn);
      final icon = _iconForMeal(key);

     final names = items
    .take(2)
    .map((i) => _friendlyChipName(isEn, i))
    .where((s) => s.trim().isNotEmpty)
    .toList();


      mealRows.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    if (names.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: -4,
                        children: names
                            .map(
                              (n) => Chip(
                                label: Text(
                                  n,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant_menu),
                const SizedBox(width: 8),
                Text(
                  isEn ? "Today's Meal Plan" : 'আজকের খাবার পরিকল্পনা',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              plan.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            ...mealRows,
            if (mealRows.isNotEmpty) const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _openMealPlanDetail,
                child: Text(isEn ? 'View full plan' : 'পূর্ণ প্ল্যান দেখুন'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelForMeal(String k, bool isEn) {
    switch (k) {
      case 'breakfast':
        return isEn ? 'Breakfast' : 'ব্রেকফাস্ট';
      case 'mid_morning':
        return isEn ? 'Mid-morning snack' : 'মধ্যসকালের স্ন্যাক';
      case 'lunch':
        return isEn ? 'Lunch' : 'দুপুরের খাবার';
      case 'evening':
        return isEn ? 'Evening snack' : 'বিকালের স্ন্যাক';
      case 'dinner':
        return isEn ? 'Dinner' : 'রাতের খাবার';
      case 'snack':
        return isEn ? 'Snack' : 'স্ন্যাক';
      default:
        return k;
    }
  }

  IconData _iconForMeal(String k) {
    switch (k) {
      case 'breakfast':
        return Icons.wb_sunny_outlined;
      case 'mid_morning':
        return Icons.local_cafe_outlined;
      case 'lunch':
        return Icons.restaurant_outlined;
      case 'evening':
        return Icons.local_dining;
      case 'dinner':
        return Icons.nights_stay_outlined;
      case 'snack':
        return Icons.fastfood_outlined;
      default:
        return Icons.restaurant_menu;
    }
  }

  // ✅ FIXED: Always reload after returning from MealPlanMainScreen
  Future<void> _openMealPlanDetail() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MealPlanMainScreen(isEnglish: widget.isEnglish),
      ),
    );

    // Always refresh after coming back (covers "changed once" or "changed 10 times")
    await _loadMealPlan();
    await _load();
  }

  // ---------------------------------------------------
  // Bangla digit helper
  // ---------------------------------------------------
  String _toBanglaDigits(String input) {
    const latin = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

    final buf = StringBuffer();
    for (final ch in input.split('')) {
      final idx = latin.indexOf(ch);
      if (idx == -1) {
        buf.write(ch);
      } else {
        buf.write(bangla[idx]);
      }
    }
    return buf.toString();
  }

  String _friendlyChipName(bool isEn, MealItem item) {
  final rawEn = (item.foodNameEn ?? item.customLabel ?? '').trim();
  final rawBn = (item.foodNameBn ?? '').trim();

  final raw = isEn ? rawEn : (rawBn.isNotEmpty ? rawBn : rawEn);
  final lower = raw.toLowerCase();

  if (lower.contains('lean protein') || lower.contains('চর্বিহীন প্রোটিন')) {
    return isEn ? 'Protein (fish/chicken/egg/dal)' : 'প্রোটিন (মাছ/মুরগি/ডিম/ডাল)';
  }

  if (lower.contains('murgir') && lower.contains('dim')) {
    return isEn ? 'Egg' : 'ডিম';
  }

  if (lower.contains('vegetables, non-starchy') ||
      lower.contains('non-starchy vegetable') ||
      lower.contains('নন-স্টার্চি সবজি')) {
    return isEn ? 'Vegetables' : 'সবজি';
  }

  if (lower.contains('roti') ||
      lower.contains('chapati') ||
      lower.contains('রুটি') ||
      lower.contains('চাপাটি')) {
    return isEn ? 'Roti/Chapati (whole wheat)' : 'রুটি/চাপাটি (আটা)';
  }

  if (lower.contains('rice') || lower.contains('ভাত')) {
    return isEn ? 'Rice' : 'ভাত';
  }

  if (lower.contains('peanut') || lower.contains('nuts') || lower.contains('বাদাম')) {
    return isEn ? 'Peanuts / Nuts' : 'বাদাম';
  }

  if (lower.contains('milk') ||
      lower.contains('yogurt') ||
      lower.contains('curd') ||
      lower.contains('দুধ') ||
      lower.contains('দই')) {
    return isEn ? 'Milk / Yogurt' : 'দুধ/দই';
  }

  if (lower.contains('fruit') || lower.contains('ফল')) {
    return isEn ? 'Fruit' : 'ফল';
  }

  return raw;
}




  // ---------------------------------------------------
  // FAB
  // ---------------------------------------------------
  Widget _buildFab(bool isEn) {
    return FloatingActionButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.water_drop_outlined),
                    title: Text(isEn ? 'Add water intake' : 'পানি যোগ করুন'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _openAddWater();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(isEn ? 'Set hydration goal' : 'পানির লক্ষ্য নির্ধারণ'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _openSetGoal();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.directions_run_outlined),
                    title: Text(isEn ? 'Log activity' : 'কর্মকাণ্ড যোগ করুন'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _openLogActivity();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
      child: const Icon(Icons.add),
    );
  }
}
