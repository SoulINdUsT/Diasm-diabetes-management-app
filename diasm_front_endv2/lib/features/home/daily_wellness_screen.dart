
import 'package:flutter/material.dart';

import '../../core/rightpath_repository.dart';
import '../../core/rightpath_models.dart';

class DailyWellnessScreen extends StatefulWidget {
  static const routeName = '/daily-wellness';

  const DailyWellnessScreen({super.key});

  @override
  State<DailyWellnessScreen> createState() => _DailyWellnessScreenState();
}

class _DailyWellnessScreenState extends State<DailyWellnessScreen> {
  final _repo = RightPathRepository();

  bool _isBangla = false; // local toggle

  bool _loading = true;
  bool _saving = false;
  String? _error;

  int _walkMinutes = 30;
  int _hydrationGlasses = 6;
  bool _mealsOnTime = true;
  double _sleepHours = 7.0;
  bool _glucoseChecked = false;

  RightPathTodayStatus? _todayStatus;

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  Future<void> _loadToday() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _repo.getTodayStatus();
      if (!mounted) return;

      if (res != null) {
        _todayStatus = res;
        _walkMinutes = res.walkMinutes ?? _walkMinutes;
        _hydrationGlasses = res.hydrationGlasses ?? _hydrationGlasses;
        _mealsOnTime = res.mealsOnTime ?? _mealsOnTime;
        _sleepHours = res.sleepHours ?? _sleepHours;
        _glucoseChecked = res.glucoseChecked ?? _glucoseChecked;
      }
    } catch (_) {
      if (!mounted) return;
      _error = _isBangla
          ? 'আজকের তথ্য লোড করা যায়নি।'
          : 'Failed to load today’s wellness data.';
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final res = await _repo.saveTodayStatus(
        walkMinutes: _walkMinutes,
        hydrationGlasses: _hydrationGlasses,
        mealsOnTime: _mealsOnTime,
        sleepHours: _sleepHours,
        glucoseChecked: _glucoseChecked,
      );

      if (!mounted) return;

      setState(() {
        _todayStatus = res;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isBangla
                ? 'আজকের ওয়েলনেস আপডেট হয়েছে!'
                : 'Wellness updated for today!',
          ),
        ),
      );

      // return the latest object so Home can update immediately
      Navigator.of(context).maybePop(res);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _isBangla
            ? 'সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।'
            : 'Could not save today’s wellness. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isBangla ? 'আজকের ওয়েলনেস লগ' : 'Today’s Wellness Log',
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _isBangla = !_isBangla);
            },
            child: Text(
              _isBangla ? 'EN' : 'বাংলা',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      _isBangla
                          ? 'আজকের জন্য ছোট একটা চেক-ইন করুন।'
                          : 'Do a quick check-in for today.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.black87),
                    ),
                    const SizedBox(height: 16),

                    // walking
                    _buildIntStepperField(
                      icon: Icons.directions_walk,
                      labelEn: 'Walking minutes',
                      labelBn: 'হাঁটার সময় (মিনিট)',
                      unitEn: 'min',
                      unitBn: 'মিনিট',
                      value: _walkMinutes,
                      min: 0,
                      max: 120,
                      step: 5,
                      onChanged: (v) => setState(() => _walkMinutes = v),
                    ),
                    const SizedBox(height: 12),

                    // water
                    _buildIntStepperField(
                      icon: Icons.local_drink,
                      labelEn: 'Glasses of water',
                      labelBn: 'পানির গ্লাস',
                      unitEn: 'glasses',
                      unitBn: 'গ্লাস',
                      value: _hydrationGlasses,
                      min: 0,
                      max: 12,
                      step: 1,
                      onChanged: (v) => setState(() => _hydrationGlasses = v),
                    ),
                    const SizedBox(height: 12),

                    // meals on time
                    _buildBoolSwitchField(
                      icon: Icons.restaurant_menu,
                      labelEn: 'Meals on time',
                      labelBn: 'খাবার সময়মতো হয়েছে?',
                      value: _mealsOnTime,
                      onChanged: (v) => setState(() => _mealsOnTime = v),
                    ),
                    const SizedBox(height: 12),

                    // sleep
                    _buildSleepSliderField(),
                    const SizedBox(height: 12),

                    // glucose checked
                    _buildBoolSwitchField(
                      icon: Icons.bloodtype,
                      labelEn: 'Checked glucose today',
                      labelBn: 'আজ গ্লুকোজ পরীক্ষা করেছেন?',
                      value: _glucoseChecked,
                      onChanged: (v) => setState(() => _glucoseChecked = v),
                    ),
                    const SizedBox(height: 20),

                    // save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _isBangla
                              ? 'আজকের চেক-ইন সেভ করুন'
                              : 'Save today’s check-in',
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _buildTodayResultCard(theme),
                  ],
                ),
              ),
      ),
    );
  }

  // ---------- Widgets for fields ----------

  Widget _buildIntStepperField({
    required IconData icon,
    required String labelEn,
    required String labelBn,
    required String unitEn,
    required String unitBn,
    required int value,
    required int min,
    required int max,
    required int step,
    required ValueChanged<int> onChanged,
  }) {
    final label = _isBangla ? labelBn : labelEn;
    final unit = _isBangla ? unitBn : unitEn;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$value $unit',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: value > min
                ? () => onChanged((value - step).clamp(min, max))
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            onPressed: value < max
                ? () => onChanged((value + step).clamp(min, max))
                : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildBoolSwitchField({
    required IconData icon,
    required String labelEn,
    required String labelBn,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final label = _isBangla ? labelBn : labelEn;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSleepSliderField() {
    final label =
        _isBangla ? 'ঘুমের সময় (ঘণ্টা)' : 'Sleep hours (last night)';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bedtime, color: Theme.of(context).primaryColor),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                _sleepHours.toStringAsFixed(1),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Slider(
            min: 0,
            max: 12,
            divisions: 24,
            value: _sleepHours,
            label: _sleepHours.toStringAsFixed(1),
            onChanged: (v) => setState(() => _sleepHours = v),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayResultCard(ThemeData theme) {
    final s = _todayStatus;
    if (s == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          _isBangla
              ? 'স্কোর দেখতে আজকের চেক-ইন সেভ করুন।'
              : 'Save today’s check-in to see your wellness score.',
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      );
    }

    final score = s.dailyScore ?? 0;

    Color statusColor;
    String statusLabel;

    if (score >= 80) {
      statusColor = const Color(0xFF43A047);
      statusLabel = _isBangla ? 'সঠিক পথে' : 'On track';
    } else if (score >= 60) {
      statusColor = const Color(0xFFFFA726);
      statusLabel = _isBangla ? 'মোটামুটি' : 'Almost there';
    } else {
      statusColor = const Color(0xFFE53935);
      statusLabel = _isBangla ? 'কেয়ার প্রয়োজন' : 'Needs care';
    }

    final msg = _isBangla ? (s.messageBn ?? '') : (s.messageEn ?? '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
            _isBangla ? 'আজকের ওয়েলনেস স্কোর' : 'Today’s wellness score',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                score.toString(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                '/100',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          const SizedBox(height: 8),
          Text(
            msg,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
