
import 'package:flutter/material.dart';

import 'package:diasm_front_endv2/core/lifestyle_models.dart';
import 'package:diasm_front_endv2/core/lifestyle_repository.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';


// For change-plan screen
import 'package:diasm_front_endv2/features/tools/lifestyle/mealplan_select_screen.dart';
// For local language toggle
import 'package:diasm_front_endv2/widgets/language_toggle.dart';

class MealPlanMainScreen extends StatefulWidget {
  static const routeName = '/tools/lifestyle/mealplan';

  final bool isEnglish;
  const MealPlanMainScreen({super.key, required this.isEnglish});

  @override
  State<MealPlanMainScreen> createState() => _MealPlanMainScreenState();
}

class _MealPlanMainScreenState extends State<MealPlanMainScreen> {
  final _repo = LifestyleRepository();

  bool _loading = true;
  String? _error;

  MealPlanAssignment? _assignment;
  MealPlan? _plan;

  late bool _isEnglish;

  @override
  void initState() {
    super.initState();
    _isEnglish = widget.isEnglish;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final assignments = await _repo.getUserMealPlans();

      MealPlanAssignment? active;
      if (assignments.isNotEmpty) {
        try {
          active = assignments.firstWhere((a) => a.active);
        } catch (_) {
          active = assignments.first;
        }
      }

      MealPlan? plan;

      if (active != null && active.mealPlanId > 0) {
        plan = await _repo.getMealPlanById(active.mealPlanId);
      }

      if (plan == null) {
        final templates = await _repo.getAllMealPlans(limit: 1);
        if (templates.isNotEmpty) {
          final template = templates.first;
          plan = await _repo.getMealPlanById(template.id) ?? template;
        }
      }

      if (!mounted) return;
      setState(() {
        _assignment = active;
        _plan = plan;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load meal plan.';
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------
  // Change Plan Handler
  // ---------------------------------------------------
  Future<void> _openChangePlan() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MealPlanSelectScreen(isEnglish: _isEnglish),
      ),
    );

    if (result == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = _isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Meal Plan' : 'খাবার পরিকল্পনা'),
      ),
      body: _buildBody(isEn),
    );
  }

  Widget _buildBody(bool isEn) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(isEn ? _error! : 'লোড করা যায়নি।'),
      );
    }

    final plan = _plan;
    if (plan == null) {
      return Center(
        child: Text(
          isEn
              ? 'No meal plan assigned yet.'
              : 'এখনও কোনো মিল প্ল্যান সেট করা হয়নি।',
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LanguageToggle(
            isEnglish: isEn,
            onChanged: (val) {
              setState(() {
                _isEnglish = val;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildPlanHeader(isEn, plan),
          const SizedBox(height: 16),
          _buildMacroStrip(isEn, plan.totals),
          const SizedBox(height: 16),
          _buildMealSections(isEn, plan),
          const SizedBox(height: 16),
          _buildFooter(isEn),
        ],
      ),
    );
  }

  // HEADER WITH CHANGE PLAN BUTTON
  Widget _buildPlanHeader(bool isEn, MealPlan plan) {
    final subtitle = StringBuffer();
    subtitle.write(plan.calories.toStringAsFixed(0));
    subtitle.write(' kcal');
    if (plan.forDiabetesType != null &&
        plan.forDiabetesType!.trim().isNotEmpty) {
      subtitle.write(' • ');
      subtitle.write(plan.forDiabetesType);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.restaurant_menu, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle.toString(),
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(isEn ? 'Template plan' : 'টেমপ্লেট প্ল্যান'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Chip(
                        label: Text(isEn
                            ? 'Balanced carbs / protein / fat'
                            : 'সুষম কার্ব / প্রোটিন / ফ্যাট'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: _openChangePlan,
                      child: Text(
                        isEn ? 'Change plan' : 'প্ল্যান পরিবর্তন করুন',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroStrip(bool isEn, MealTotals? totals) {
    final t =
        totals ?? MealTotals(calories: 0, proteinG: 0, carbsG: 0, fatG: 0);

    Widget chip(IconData icon, String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(value, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(Icons.rice_bowl_outlined, isEn ? 'Carbs' : 'কার্ব',
            '${t.carbsG.toStringAsFixed(0)} g'),
        const SizedBox(width: 8),
        chip(Icons.egg_alt_outlined, isEn ? 'Protein' : 'প্রোটিন',
            '${t.proteinG.toStringAsFixed(0)} g'),
        const SizedBox(width: 8),
        chip(Icons.opacity_outlined, isEn ? 'Fat' : 'ফ্যাট',
            '${t.fatG.toStringAsFixed(0)} g'),
      ],
    );
  }

  Widget _buildMealSections(bool isEn, MealPlan plan) {
    final sections = <_MealSectionConfig>[
      _MealSectionConfig(
          key: 'breakfast',
          labelEn: 'Breakfast',
          labelBn: 'ব্রেকফাস্ট',
          icon: Icons.breakfast_dining),
      _MealSectionConfig(
          key: 'mid_morning',
          labelEn: 'Mid-morning snack',
          labelBn: 'মধ্যসকালের স্ন্যাক',
          icon: Icons.local_cafe_outlined),
      _MealSectionConfig(
  key: 'lunch',
  labelEn: 'Lunch',
  labelBn: 'দুপুরের খাবার',
  icon: FontAwesomeIcons.utensils,
),
      _MealSectionConfig(
          key: 'evening',
          labelEn: 'Evening snack',
          labelBn: 'বিকালের স্ন্যাক',
          icon: Icons.local_dining),
      _MealSectionConfig(
          key: 'dinner',
          labelEn: 'Dinner',
          labelBn: 'রাতের খাবার',
          icon: Icons.dinner_dining),
      _MealSectionConfig(
          key: 'snack',
          labelEn: 'Snack',
          labelBn: 'স্ন্যাক',
          icon: Icons.fastfood_outlined),
    ];

    List<Widget> cards = [];

    for (final s in sections) {
      final items = plan.itemsByMeal[s.key] ?? const <MealItem>[];
      if (items.isEmpty) continue;

      final kcal = _sumCalories(items);

      cards.add(
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(s.icon),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEn ? s.labelEn : s.labelBn,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${kcal.toStringAsFixed(0)} kcal',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  children: items.map((item) => _buildFoodRow(isEn, item)).toList(),
                ),
              ],
            ),
          ),
        ),
      );
      cards.add(const SizedBox(height: 12));
    }

    if (cards.isEmpty) {
      return Text(
        isEn ? 'No meal items in this plan.' : 'এই প্ল্যানে কোনো খাবারের আইটেম নেই।',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cards,
    );
  }

  // ============================
  // UPDATED ROW + NAME + ICON LOGIC
  // ============================

  Widget _buildFoodRow(bool isEn, MealItem item) {
    final displayName = _friendlyFoodName(isEn, item);
    final icon = _iconForFood(item, displayName: displayName);

    final subtitleParts = <String>[];

    if (item.grams != null && item.grams! > 0) {
      subtitleParts.add('${item.grams!.toStringAsFixed(0)} g');
    }
    if (item.notes != null && item.notes!.trim().isNotEmpty) {
      subtitleParts.add(item.notes!.trim());
    }

    final kcal = item.calories;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(displayName.isEmpty ? (isEn ? 'Item' : 'খাবার') : displayName),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' • ')),
      trailing: kcal == null
          ? null
          : Text('${kcal.toStringAsFixed(0)} kcal',
              style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  /// Produce user-friendly names (EN/BN) without touching backend/DB.
  String _friendlyFoodName(bool isEn, MealItem item) {
    final rawEn = (item.foodNameEn ?? item.customLabel ?? '').trim();
    final rawBn = (item.foodNameBn ?? '').trim();

    // Prefer BN when Bangla UI, but fall back to EN/customLabel.
    final raw = isEn ? rawEn : (rawBn.isNotEmpty ? rawBn : rawEn);
    final lower = raw.toLowerCase();

    // Lean protein generic → friendly
    if (lower.contains('lean protein') || lower.contains('চর্বিহীন প্রোটিন')) {
      return isEn ? 'Protein (fish/chicken/egg/dal)' : 'প্রোটিন (মাছ/মুরগি/ডিম/ডাল)';
    }

    // Mixed / broken "murgir dim, farm er" style → Egg
    if (lower.contains('murgir') && lower.contains('dim')) {
      return isEn ? 'Egg' : 'ডিম';
    }

    // Generic vegetables
    if (lower.contains('vegetables, non-starchy') ||
        lower.contains('non-starchy vegetable') ||
        lower.contains('নন-স্টার্চি সবজি')) {
      return isEn ? 'Vegetables' : 'সবজি';
    }

    // Roti / Chapati
    if (lower.contains('roti') ||
        lower.contains('chapati') ||
        lower.contains('রুটি') ||
        lower.contains('চাপাটি')) {
      return isEn ? 'Roti / Chapati (whole wheat)' : 'রুটি/চাপাটি (আটা)';
    }

    // Rice
    if (lower.contains('rice') || lower.contains('ভাত')) {
      return isEn ? 'Rice' : 'ভাত';
    }

    // Peanuts / nuts
    if (lower.contains('peanut') || lower.contains('বাদাম')) {
      return isEn ? 'Peanuts / Nuts' : 'বাদাম';
    }

    // Milk / yogurt / curd
    if (lower.contains('milk') ||
        lower.contains('yogurt') ||
        lower.contains('curd') ||
        lower.contains('দুধ') ||
        lower.contains('দই')) {
      return isEn ? 'Milk / Yogurt' : 'দুধ/দই';
    }

    // Fruit
    if (lower.contains('fruit') || lower.contains('ফল')) {
      return isEn ? 'Fruit' : 'ফল';
    }

    return raw;
  }

  /// Better icon selection. Supports English + Bangla keywords.
 IconData _iconForFood(MealItem item, {String? displayName}) {
  final name =
      ((displayName ?? item.foodNameEn ?? item.customLabel ?? '')).toLowerCase();

  bool hasAny(List<String> keys) => keys.any((k) => name.contains(k));

  // ----------------------------
  // Grains / bread
  // ----------------------------
  // Roti/Chapati icon:
  // NOTE: FontAwesome does not have a "flatbread/roti" icon. Closest clear option is breadSlice.
  if (hasAny(['roti', 'chapati', 'bread', 'রুটি', 'চাপাটি'])) {
    return FontAwesomeIcons.breadSlice;
  }

  // Rice icon: keep Material (your C1)
  if (hasAny(['rice', 'ভাত', 'চাল'])) {
    return Icons.rice_bowl_outlined;
  }

  // ----------------------------
  // Protein types (your P2)
  // ----------------------------
  // If the label is generic like "Protein (fish/chicken/egg/dal)"
  if (hasAny(['protein (', 'প্রোটিন (', 'lean protein'])) {
    return FontAwesomeIcons.drumstickBite;
  }

  // Fish
  if (hasAny(['fish', 'মাছ'])) return FontAwesomeIcons.fish;

  // Chicken
  if (hasAny(['chicken', 'মুরগি'])) return FontAwesomeIcons.drumstickBite;

  // Beef / Mutton / Meat
  if (hasAny(['beef', 'mutton', 'meat', 'গরু', 'খাসি'])) {
    return FontAwesomeIcons.cow;
  }

  // Egg
  if (hasAny(['egg', 'ডিম'])) return FontAwesomeIcons.egg;

  // Dal / lentil / pulses
  if (hasAny(['dal', 'lentil', 'ডাল'])) return FontAwesomeIcons.seedling;

  // ----------------------------
  // Vegetables / salad
  // ----------------------------
  if (hasAny(['vegetable', 'veg', 'salad', 'সবজি', 'শাক'])) {
    return FontAwesomeIcons.leaf;
  }

  // ----------------------------
  // Dairy
  // ----------------------------
  if (hasAny(['milk', 'yogurt', 'curd', 'দুধ', 'দই'])) {
    return FontAwesomeIcons.glassWater;
  }

  // Nuts
  if (hasAny(['peanut', 'nuts', 'বাদাম'])) {
    return FontAwesomeIcons.bowlFood;
  }

  // Fruit
  if (hasAny(['fruit', 'ফল'])) {
    return FontAwesomeIcons.appleWhole;
  }

  // Default
  return FontAwesomeIcons.utensils;
}


  double _sumCalories(List<MealItem> items) {
    double t = 0;
    for (final i in items) {
      t += i.calories ?? 0;
    }
    return t;
  }

  Widget _buildFooter(bool isEn) {
    return Text(
      isEn
          ? 'Based on BIRDEM diabetic diet book. This is a general template; individual needs may vary.'
          : 'বারডেম ডায়াবেটিক ডায়েট বই ভিত্তিক। এটি একটি সাধারণ টেমপ্লেট; ব্যক্তিভেদে প্রয়োজন ভিন্ন হতে পারে।',
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: Theme.of(context).hintColor),
    );
  }
}

class _MealSectionConfig {
  final String key;
  final String labelEn;
  final String labelBn;
  final IconData icon;

  _MealSectionConfig({
    required this.key,
    required this.labelEn,
    required this.labelBn,
    required this.icon,
  });
}
