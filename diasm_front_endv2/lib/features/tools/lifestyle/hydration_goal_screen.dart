
import 'package:flutter/material.dart';

import 'package:diasm_front_endv2/core/api_client.dart';
import 'package:diasm_front_endv2/core/auth_storage.dart';

class HydrationGoalScreen extends StatefulWidget {
  final bool isEnglish;
  const HydrationGoalScreen({super.key, required this.isEnglish});

  @override
  State<HydrationGoalScreen> createState() => _HydrationGoalScreenState();
}

class _HydrationGoalScreenState extends State<HydrationGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _goalController = TextEditingController();

  final _api = ApiClient();
  final _auth = AuthStorage();

  bool _loading = false;
  double? _currentGoal;

  @override
  void initState() {
    super.initState();
    _loadCurrentGoal();
  }

  Future<int> _resolveUserId() async {
    final id = await _auth.getUserId();
    if (id != null) return id;
    // fallback to user 1 for now (same as hydration logging)
    return 1;
  }

  Future<void> _loadCurrentGoal() async {
    setState(() => _loading = true);

    try {
      final userId = await _resolveUserId();

      final res = await _api.dio.get(
        '/hydration/goal',
        queryParameters: {'user_id': userId},
      );

      if (res.statusCode == 200 &&
          res.data is Map &&
          res.data['ok'] == true) {
        final data = res.data['data'];
        if (data != null && data['daily_ml'] != null) {
          final raw = data['daily_ml'];
          final goal = double.tryParse(raw.toString());
          if (goal != null) {
            _currentGoal = goal;
            _goalController.text = goal.toStringAsFixed(0);
          }
        }
      }
    } catch (_) {
      // ignore errors, just show empty form
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final isEn = widget.isEnglish;

    if (!_formKey.currentState!.validate()) return;

    final text = _goalController.text.trim();
    final value = double.tryParse(text);
    if (value == null || value <= 0) return;

    setState(() => _loading = true);

    try {
      final userId = await _resolveUserId();

      final body = {
        'user_id': userId,
        'daily_ml': value,
      };

      final res = await _api.dio.put(
        '/hydration/goal',
        data: body,
      );

      final ok = res.statusCode == 200 &&
          res.data is Map &&
          res.data['ok'] == true;

      if (!mounted) return;

      setState(() => _loading = false);

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEn ? "Hydration goal saved." : "পানির লক্ষ্য সেভ হয়েছে।",
            ),
          ),
        );
        // notify previous screen to refresh snapshot
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEn ? "Failed to save goal." : "লক্ষ্য সেভ করা যায়নি।",
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn ? "Failed to save goal." : "লক্ষ্য সেভ করা যায়নি।",
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? "Hydration Goal" : "পানির লক্ষ্য"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_currentGoal != null) ...[
                Text(
                  isEn
                      ? "Current goal: ${_currentGoal!.toStringAsFixed(0)} ml"
                      : "বর্তমান লক্ষ্য: ${_currentGoal!.toStringAsFixed(0)} মি.লি.",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
              ],
              Text(
                isEn ? "Daily goal (ml)" : "দৈনিক লক্ষ্য (মি.লি.)",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _goalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: isEn ? "e.g. 2000" : "যেমন ২০০০",
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) {
                    return isEn
                        ? "Please enter a goal."
                        : "একটি লক্ষ্য লিখুন।";
                  }
                  final numVal = double.tryParse(v);
                  if (numVal == null || numVal <= 0) {
                    return isEn
                        ? "Enter a valid number."
                        : "সঠিক সংখ্যা লিখুন।";
                  }
                  if (numVal < 500) {
                    return isEn
                        ? "Goal should be at least 500 ml."
                        : "লক্ষ্য কমপক্ষে ৫০০ মি.লি. হওয়া উচিত।";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isEn ? "Save goal" : "লক্ষ্য সেভ করুন",
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
