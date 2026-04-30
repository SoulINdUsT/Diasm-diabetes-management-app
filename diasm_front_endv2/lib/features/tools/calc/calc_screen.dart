
import 'package:flutter/material.dart';
import '../../../core/tools_repository.dart';

// NEW imports
import 'package:diasm_front_endv2/core/lifestyle_repository.dart';
import 'package:diasm_front_endv2/core/lifestyle_models.dart';

class CalcScreen extends StatefulWidget {
  static const routeName = '/tools/calc';

  final bool isEnglish;
  const CalcScreen({super.key, required this.isEnglish});

  @override
  State<CalcScreen> createState() => _CalcScreenState();
}

class _CalcScreenState extends State<CalcScreen> {
  final _repo = ToolsRepository.instance;

  // NEW: lifestyle repo for meal-plan recommendation
  final _lifestyleRepo = LifestyleRepository();

  // local language state (toggle-able)
  late bool _isEnglish;

  // BMI controllers
  final _bmiWeightCtrl = TextEditingController();
  final _bmiHeightCtrl = TextEditingController();

  // BMR controllers
  final _bmrWeightCtrl = TextEditingController();
  final _bmrHeightCtrl = TextEditingController();
  final _bmrAgeCtrl = TextEditingController();

  String _sex = 'male';
  String _activity = 'sedentary';

  Map<String, dynamic>? _bmiResult;
  Map<String, dynamic>? _bmrResult;

  bool _loadingBmi = false;
  bool _loadingBmr = false;

  // meal-plan recommendation state (from BMR)
  MealPlanRecommendation? _recommendedPlan;
  bool _loadingRecommendation = false;
  bool _assigningPlan = false;

  @override
  void initState() {
    super.initState();
    _isEnglish = widget.isEnglish; // start from passed language
  }

  @override
  void dispose() {
    _bmiWeightCtrl.dispose();
    _bmiHeightCtrl.dispose();
    _bmrWeightCtrl.dispose();
    _bmrHeightCtrl.dispose();
    _bmrAgeCtrl.dispose();
    super.dispose();
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // -------- BMI interpretation helpers --------

  Color _bmiColor(String category, ColorScheme cs) {
    switch (category.toLowerCase()) {
      case 'underweight':
        return Colors.blueGrey;
      case 'normal':
        return cs.primary;
      case 'overweight':
        return Colors.orange;
      case 'obese':
        return Colors.redAccent;
      default:
        return cs.primary;
    }
  }

  String _bmiCategoryBn(String categoryEn) {
    switch (categoryEn.toLowerCase()) {
      case 'underweight':
        return 'কম ওজন';
      case 'normal':
        return 'স্বাভাবিক';
      case 'overweight':
        return 'অতিরিক্ত ওজন';
      case 'obese':
        return 'স্থূলতা';
      default:
        return categoryEn;
    }
  }

  String _bmiMessageEn(String category) {
    switch (category.toLowerCase()) {
      case 'underweight':
        return 'Your BMI is below the healthy range. Consider gradual weight gain with nutritious meals.';
      case 'normal':
        return 'Your BMI is in the healthy range. Maintain your current lifestyle.';
      case 'overweight':
        return 'Your BMI is above the healthy range. A small calorie deficit and daily activity can help.';
      case 'obese':
        return 'Your BMI is much above the healthy range. Slow, consistent weight loss is recommended.';
      default:
        return '';
    }
  }

  String _bmiMessageBn(String category) {
    switch (category.toLowerCase()) {
      case 'underweight':
        return 'আপনার BMI স্বাস্থ্যকর সীমার নিচে। পুষ্টিকর খাবার দিয়ে ধীরে ধীরে ওজন বাড়ানো ভালো।';
      case 'normal':
        return 'আপনার BMI স্বাস্থ্যকর সীমার মধ্যে আছে। এই লাইফস্টাইল ধরে রাখুন।';
      case 'overweight':
        return 'আপনার BMI স্বাস্থ্যকর সীমার উপরে। অল্প ক্যালরি কমিয়ে ও নিয়মিত হাঁটা সাহায্য করবে।';
      case 'obese':
        return 'আপনার BMI অনেক বেশি। ধীরে ধীরে, নিয়মিতভাবে ওজন কমানোই নিরাপদ।';
      default:
        return '';
    }
  }

  String _activityLabelEn(String v) {
    switch (v) {
      case 'sedentary':
        return 'Sedentary (little activity)';
      case 'light':
        return 'Light';
      case 'moderate':
        return 'Moderate';
      case 'active':
        return 'Active';
      case 'very_active':
        return 'Very active';
      default:
        return v;
    }
  }

  String _activityLabelBn(String v) {
    switch (v) {
      case 'sedentary':
        return 'কম কাজকর্ম';
      case 'light':
        return 'হালকা';
      case 'moderate':
        return 'মাঝারি';
      case 'active':
        return 'সক্রিয়';
      case 'very_active':
        return 'খুব সক্রিয়';
      default:
        return v;
    }
  }

  // -------- Actions --------

  Future<void> _calculateBmi() async {
    final isEn = _isEnglish;

    final wText =
        _bmiWeightCtrl.text.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    final hText =
        _bmiHeightCtrl.text.trim().replaceAll(RegExp(r'[^0-9.]'), '');

    final w = double.tryParse(wText);
    final h = double.tryParse(hText);

    if (w == null || h == null || w <= 0 || h <= 0) {
      _showMsg(isEn ? 'Enter valid height and weight.' : 'সঠিক উচ্চতা এবং ওজন দিন।');
      return;
    }

    setState(() => _loadingBmi = true);

    final res = await _repo.calculateBMI(weightKg: w, heightCm: h);

    setState(() {
      _loadingBmi = false;
      _bmiResult = res;
    });

    // Auto-fill BMR fields if empty
    if (res != null) {
      if (_bmrHeightCtrl.text.trim().isEmpty) {
        _bmrHeightCtrl.text = h.toStringAsFixed(0);
      }
      if (_bmrWeightCtrl.text.trim().isEmpty) {
        _bmrWeightCtrl.text = w.toStringAsFixed(0);
      }
    }

    if (res == null) {
      _showMsg(isEn ? 'BMI calculation failed.' : 'BMI হিসাব করা যায়নি।');
    }
  }

  Future<void> _calculateBmr() async {
    final isEn = _isEnglish;

    final wText =
        _bmrWeightCtrl.text.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    final hText =
        _bmrHeightCtrl.text.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    final ageText =
        _bmrAgeCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

    final w = double.tryParse(wText);
    final h = double.tryParse(hText);
    final age = int.tryParse(ageText);

    if (w == null || h == null || age == null || w <= 0 || h <= 0 || age <= 0) {
      _showMsg(isEn
          ? 'Enter valid sex, age, height, and weight.'
          : 'সঠিক লিঙ্গ, বয়স, উচ্চতা ও ওজন দিন।');
      return;
    }

    setState(() => _loadingBmr = true);

    final res = await _repo.calculateBMR(
      sex: _sex,
      age: age,
      weightKg: w,
      heightCm: h,
      activityLevel: _activity,
    );

    setState(() {
      _loadingBmr = false;
      _bmrResult = res;
      // also clear previous recommendation when recalculating
      _recommendedPlan = null;
    });

    if (res == null) {
      _showMsg(isEn ? 'Calorie calculation failed.' : 'ক্যালরি হিসাব করা যায়নি।');
      return;
    }

    // after successful BMR, request suggested meal plan
    final daily = (res['daily_calories'] as num?)?.toDouble();
    if (daily != null && daily > 0) {
      await _fetchMealPlanRecommendation(daily);
    }
  }

  // load suggested meal plan for given calories
  Future<void> _fetchMealPlanRecommendation(double targetCalories) async {
    setState(() {
      _loadingRecommendation = true;
      _recommendedPlan = null;
    });

    final rec =
        await _lifestyleRepo.recommendMealPlanForCalories(targetCalories);

    if (!mounted) return;

    setState(() {
      _loadingRecommendation = false;
      _recommendedPlan = rec;
    });
  }

  // assign suggested plan to user
  Future<void> _applySuggestedPlan() async {
    final rec = _recommendedPlan;
    if (rec == null) return;

    final plan = rec.recommended;

    setState(() {
      _assigningPlan = true;
    });

    final ok = await _lifestyleRepo.assignMealPlan(plan.id);

    if (!mounted) return;

    setState(() {
      _assigningPlan = false;
    });

    final isEn = _isEnglish;
    _showMsg(
      ok
          ? (isEn
              ? 'Suggested meal plan applied.'
              : 'প্রস্তাবিত মিল প্ল্যান সেট হয়েছে।')
          : (isEn
              ? 'Could not apply meal plan.'
              : 'মিল প্ল্যান সেট করা যায়নি।'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = _isEnglish;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Calculator' : 'ক্যালকুলেটর'),
        actions: [
          // EN/BN toggle in Calc screen
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('English'),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('বাংলা'),
                ),
              ],
              selected: {_isEnglish},
              onSelectionChanged: (s) {
                setState(() => _isEnglish = s.first);
              },
              showSelectedIcon: false,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SectionCard(
              title: isEn ? 'BMI Calculator' : 'BMI ক্যালকুলেটর',
              icon: Icons.monitor_weight_outlined,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          controller: _bmiHeightCtrl,
                          label: isEn ? 'Height (cm)' : 'উচ্চতা (সেমি)',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NumberField(
                          controller: _bmiWeightCtrl,
                          label: isEn ? 'Weight (kg)' : 'ওজন (কেজি)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.calculate_outlined, size: 18),
                      onPressed: _loadingBmi ? null : _calculateBmi,
                      label: _loadingBmi
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEn ? 'Calculate BMI' : 'BMI হিসাব করুন'),
                    ),
                  ),

                  if (_bmiResult != null) ...[
                    const SizedBox(height: 14),
                    Builder(builder: (_) {
                      final catEn = '${_bmiResult!['category']}';
                      final bmiVal = (_bmiResult!['bmi'] as num).toDouble();

                      // current height for healthy weight range
                      final hText = _bmiHeightCtrl.text
                          .trim()
                          .replaceAll(RegExp(r'[^0-9.]'), '');
                      final heightCm = double.tryParse(hText) ?? 0.0;

                      return _BmiResultPanel(
                        isEnglish: isEn,
                        bmi: bmiVal,
                        heightCm: heightCm,
                        categoryEn: catEn,
                        categoryLabel:
                            isEn ? catEn : _bmiCategoryBn(catEn),
                        color: _bmiColor(catEn, cs),
                        message:
                            isEn ? _bmiMessageEn(catEn) : _bmiMessageBn(catEn),
                      );
                    }),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            _SectionCard(
              title: isEn ? 'BMR & Daily Calories' : 'BMR ও দৈনিক ক্যালরি',
              icon: Icons.local_fire_department_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isEn ? 'Sex' : 'লিঙ্গ'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _SexChip(
                        text: isEn ? 'Male' : 'পুরুষ',
                        selected: _sex == 'male',
                        onTap: () => setState(() => _sex = 'male'),
                      ),
                      const SizedBox(width: 8),
                      _SexChip(
                        text: isEn ? 'Female' : 'নারী',
                        selected: _sex == 'female',
                        onTap: () => setState(() => _sex = 'female'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          controller: _bmrAgeCtrl,
                          label: isEn ? 'Age (years)' : 'বয়স (বছর)',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NumberField(
                          controller: _bmrHeightCtrl,
                          label: isEn ? 'Height (cm)' : 'উচ্চতা (সেমি)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _NumberField(
                    controller: _bmrWeightCtrl,
                    label: isEn ? 'Weight (kg)' : 'ওজন (কেজি)',
                  ),
                  const SizedBox(height: 12),

                  Text(isEn ? 'Activity level' : 'শারীরিক কার্যকলাপ'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _activity,
                    items: [
                      DropdownMenuItem(
                        value: 'sedentary',
                        child: Text(isEn ? 'Sedentary' : 'কম কাজকর্ম'),
                      ),
                      DropdownMenuItem(
                        value: 'light',
                        child: Text(isEn ? 'Light' : 'হালকা'),
                      ),
                      DropdownMenuItem(
                        value: 'moderate',
                        child: Text(isEn ? 'Moderate' : 'মাঝারি'),
                      ),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text(isEn ? 'Active' : 'সক্রিয়'),
                      ),
                      DropdownMenuItem(
                        value: 'very_active',
                        child: Text(isEn ? 'Very active' : 'খুব সক্রিয়'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _activity = v);
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.calculate_outlined, size: 18),
                      onPressed: _loadingBmr ? null : _calculateBmr,
                      label: _loadingBmr
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEn ? 'Calculate Calories' : 'ক্যালরি হিসাব করুন'),
                    ),
                  ),

                  if (_bmrResult != null) ...[
                    const SizedBox(height: 14),
                    _BmrResultPanel(
                      isEnglish: isEn,
                      bmr: (_bmrResult!['bmr'] as num).toDouble(),
                      tdee: (_bmrResult!['daily_calories'] as num).toDouble(),
                      activityText: isEn
                          ? _activityLabelEn(_activity)
                          : _activityLabelBn(_activity),
                    ),

                    // suggested meal plan block
                    const SizedBox(height: 12),
                    if (_loadingRecommendation)
                      Row(
                        children: [
                          const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isEn
                                ? 'Finding a suitable meal plan...'
                                : 'উপযুক্ত মিল প্ল্যান খোঁজা হচ্ছে...',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      )
                    else if (_recommendedPlan != null)
                      _SuggestedPlanCard(
                        isEnglish: isEn,
                        plan: _recommendedPlan!.recommended,
                        assigning: _assigningPlan,
                        onApply: _applySuggestedPlan,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- UI widgets ---------------- */

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _NumberField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _SexChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _SexChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _BmiResultPanel extends StatelessWidget {
  final bool isEnglish;
  final double bmi;
  final double heightCm;

  /// English category: 'underweight', 'normal', 'overweight', 'obese'
  final String categoryEn;

  /// Label to show (EN or BN)
  final String categoryLabel;

  final Color color;
  final String message;

  const _BmiResultPanel({
    required this.isEnglish,
    required this.bmi,
    required this.heightCm,
    required this.categoryEn,
    required this.categoryLabel,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // healthy weight range for this height
    double? healthyMinKg;
    double? healthyMaxKg;
    if (heightCm > 0) {
      final hM = heightCm / 100.0;
      healthyMinKg = 18.5 * hM * hM;
      healthyMaxKg = 24.9 * hM * hM;
    }

    // Recommended goal based on BMI
    String recKey;
    switch (categoryEn.toLowerCase()) {
      case 'underweight':
        recKey = 'gain';
        break;
      case 'normal':
        recKey = 'maintain';
        break;
      case 'overweight':
      case 'obese':
        recKey = 'lose';
        break;
      default:
        recKey = 'maintain';
    }

    String _goalLabel(String key) {
      if (isEnglish) {
        switch (key) {
          case 'maintain':
            return 'Maintain weight';
          case 'lose':
            return 'Lose weight';
          case 'gain':
            return 'Gain weight';
          case 'muscle':
            return 'Build muscle';
        }
      } else {
        switch (key) {
          case 'maintain':
            return 'ওজন ধরে রাখা';
          case 'lose':
            return 'ওজন কমানো';
          case 'gain':
            return 'ওজন বাড়ানো';
          case 'muscle':
            return 'মাংসপেশী গঠন';
        }
      }
      return key;
    }

    Widget goalChip(String key) {
      final selected = (key == recKey);
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          backgroundColor:
              selected ? cs.primary.withOpacity(0.08) : cs.surface,
          side: BorderSide(
            color: selected ? cs.primary : cs.outline.withOpacity(0.6),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        onPressed: () {},
        child: Text(
          _goalLabel(key),
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? cs.primary : cs.onSurface,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: BMI value + category chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bmi.toStringAsFixed(1),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withOpacity(0.6)),
                ),
                child: Text(
                  categoryLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Healthy BMI range
          Text(
            isEnglish
                ? 'Healthy BMI range: 18.5 – 24.9'
                : 'স্বাস্থ্যকর BMI: ১৮.৫ – ২৪.৯',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          // Healthy weight range
          if (healthyMinKg != null && healthyMaxKg != null) ...[
            const SizedBox(height: 2),
            Text(
              isEnglish
                  ? 'Healthy weight range for your height: '
                      '${healthyMinKg.round()}–${healthyMaxKg.round()} kg'
                  : 'আপনার উচ্চতার জন্য স্বাস্থ্যকর ওজন: '
                      '${healthyMinKg.round()}–${healthyMaxKg.round()} কেজি',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],

          const SizedBox(height: 8),
          Text(message),

          const SizedBox(height: 10),

          Text(
            isEnglish ? 'Recommended for you' : 'আপনার জন্য পরামর্শ',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              goalChip('maintain'),
              goalChip('lose'),
              goalChip('gain'),
              goalChip('muscle'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BmrResultPanel extends StatelessWidget {
  final bool isEnglish;
  final double bmr;
  final double tdee;
  final String activityText;

  const _BmrResultPanel({
    required this.isEnglish,
    required this.bmr,
    required this.tdee,
    required this.activityText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEnglish ? 'Your results' : 'আপনার ফলাফল',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),

          _ResultRow(
            label: isEnglish ? 'BMR' : 'BMR',
            value: '${bmr.toStringAsFixed(0)} kcal/day',
          ),
          _ResultRow(
            label:
                isEnglish ? 'Daily calories (TDEE)' : 'দৈনিক ক্যালরি',
            value: '${tdee.toStringAsFixed(0)} kcal/day',
          ),
          const SizedBox(height: 6),
          Text(
            (isEnglish ? 'Activity: ' : 'কাজকর্ম: ') + activityText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),

          Text(
            isEnglish
                ? 'This is an estimate for maintaining weight. For weight loss, a small deficit is usually used.'
                : 'এটি আপনার ওজন ধরে রাখার আনুমানিক ক্যালরি। ওজন কমাতে সাধারণত একটু কম ক্যালরি নেওয়া হয়।',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// suggested meal plan card
class _SuggestedPlanCard extends StatelessWidget {
  final bool isEnglish;
  final MealPlan plan;
  final bool assigning;
  final VoidCallback onApply;

  const _SuggestedPlanCard({
    required this.isEnglish,
    required this.plan,
    required this.assigning,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final subtitle = StringBuffer()
      ..write(plan.calories.toStringAsFixed(0))
      ..write(' kcal');
    if (plan.forDiabetesType != null &&
        plan.forDiabetesType!.trim().isNotEmpty) {
      subtitle.write(' • ');
      subtitle.write(plan.forDiabetesType);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEnglish
                ? 'Recommended meal plan for you'
                : 'আপনার জন্য প্রস্তাবিত মিল প্ল্যান',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            plan.title,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle.toString(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: assigning ? null : onApply,
              child: assigning
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isEnglish
                          ? 'Use this meal plan'
                          : 'এই মিল প্ল্যান সেট করুন',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
