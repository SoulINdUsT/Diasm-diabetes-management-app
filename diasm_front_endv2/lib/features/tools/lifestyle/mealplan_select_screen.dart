
import 'package:flutter/material.dart';

import 'package:diasm_front_endv2/core/lifestyle_models.dart';
import 'package:diasm_front_endv2/core/lifestyle_repository.dart';

class MealPlanSelectScreen extends StatefulWidget {
  final bool isEnglish;

  /// Optional: target calories (e.g. from BMR calculator).
  final double? targetCalories;

  const MealPlanSelectScreen({
    super.key,
    required this.isEnglish,
    this.targetCalories,
  });

  @override
  State<MealPlanSelectScreen> createState() => _MealPlanSelectScreenState();
}

class _MealPlanSelectScreenState extends State<MealPlanSelectScreen> {
  final _repo = LifestyleRepository();

  bool _loading = true;
  String? _error;
  List<MealPlan> _plans = const [];
  int? _selectedPlanId;
  bool _saving = false;

  MealPlanRecommendation? _recommendation;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plans = await _repo.getAllMealPlans(limit: 50);

      MealPlanRecommendation? rec;
      if (widget.targetCalories != null) {
        rec = await _repo.recommendMealPlan(widget.targetCalories!);
      }

      if (!mounted) return;

      // If recommendation points to an existing plan, pre-select it.
      int? autoSelectedId;
      if (rec != null) {
        final recId = rec.recommended.id;
        final exists = plans.any((p) => p.id == recId);
        if (exists) autoSelectedId = recId;
      }

      setState(() {
        _plans = plans;
        _recommendation = rec;
        _selectedPlanId = _selectedPlanId ?? autoSelectedId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load meal plans.';
        _loading = false;
      });
    }
  }

  Future<void> _confirmSelection() async {
    final planId = _selectedPlanId;
    if (planId == null) return;

    setState(() {
      _saving = true;
    });

    final ok = await _repo.assignMealPlan(planId);

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEnglish
                ? 'Could not set meal plan.'
                : 'মিল প্ল্যান সেট করা যায়নি।',
          ),
        ),
      );
      return;
    }

    // Success – return to caller and signal refresh
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Choose Meal Plan' : 'মিল প্ল্যান নির্বাচন'),
      ),
      body: _buildBody(isEn),
      bottomNavigationBar: _buildBottomBar(isEn),
    );
  }

  Widget _buildBody(bool isEn) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          isEn ? _error! : 'লোড করা যায়নি।',
        ),
      );
    }

    if (_plans.isEmpty) {
      return Center(
        child: Text(
          isEn ? 'No meal plans available.' : 'কোনো মিল প্ল্যান পাওয়া যায়নি।',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_recommendation != null) ...[
          _buildRecommendationCard(isEn),
          const SizedBox(height: 12),
        ],
        for (final plan in _plans) _buildPlanCard(plan, isEn),
      ],
    );
  }

  Widget _buildRecommendationCard(bool isEn) {
    final rec = _recommendation!;
    final plan = rec.recommended;

    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.primary.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn ? 'Suggested plan for you' : 'আপনার জন্য সাজানো মিল প্ল্যান',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          if (rec.targetCalories > 0)
            Text(
              isEn
                  ? 'Target: ~${rec.targetCalories.toStringAsFixed(0)} kcal/day'
                  : 'টার্গেট: প্রায় ${rec.targetCalories.toStringAsFixed(0)} কিলোক্যালরি/দিন',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          Text(
            plan.title,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${plan.calories.toStringAsFixed(0)} kcal',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            isEn
                ? 'We pre-selected this plan for you. You can still choose a different one from the list below.'
                : 'এ প্ল্যানটি আগে থেকেই নির্বাচিত করা হয়েছে। চাইলে নিচের তালিকা থেকে অন্য প্ল্যানও বেছে নিতে পারেন।',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(MealPlan plan, bool isEn) {
    final selected = plan.id == _selectedPlanId;

    final subtitle = StringBuffer();
    subtitle.write(plan.calories.toStringAsFixed(0));
    subtitle.write(' kcal');
    if (plan.forDiabetesType != null && plan.forDiabetesType!.trim().isNotEmpty) {
      subtitle.write(' • ');
      subtitle.write(plan.forDiabetesType);
    }

    return Card(
      elevation: selected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _selectedPlanId = plan.id;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Radio<int>(
                value: plan.id,
                groupValue: _selectedPlanId,
                onChanged: (v) {
                  setState(() {
                    _selectedPlanId = v;
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle.toString(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (plan.sourceRef != null &&
                        plan.sourceRef!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        plan.sourceRef!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isEn) {
    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                (_selectedPlanId == null || _saving) ? null : _confirmSelection,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isEn ? 'Use this plan' : 'এই প্ল্যান ব্যবহার করুন',
                  ),
          ),
        ),
      ),
    );
  }
}
