import 'dart:async';

import 'package:flutter/material.dart';

import 'package:diasm_front_endv2/core/lifestyle_models.dart';
import 'package:diasm_front_endv2/core/lifestyle_repository.dart';
import 'package:diasm_front_endv2/features/tools/lifestyle/fasting_history_screen.dart';

class FastingMainScreen extends StatefulWidget {
  static const routeName = '/tools/lifestyle/fasting';

  final bool isEnglish;
  const FastingMainScreen({super.key, required this.isEnglish});

  @override
  State<FastingMainScreen> createState() => _FastingMainScreenState();
}

class _FastingMainScreenState extends State<FastingMainScreen> {
  final _repo = LifestyleRepository();

  FastingActiveSession? _active;
  List<FastingSummaryDay> _summary = <FastingSummaryDay>[];
  List<FastingHistoryItem> _history = <FastingHistoryItem>[];

  bool _loading = true;
  String? _error;

  bool _savingStart = false;
  bool _savingEnd = false;

  final _formKey = GlobalKey<FormState>();
  String _fastKind = 'intermittent';
  final TextEditingController _protocolController =
      TextEditingController(text: '16-8');
  final TextEditingController _targetHoursController =
      TextEditingController(text: '16');
  final TextEditingController _notesController = TextEditingController();

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _protocolController.dispose();
    _targetHoursController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_active == null) return;
      // Just rebuild so elapsed time & ring update
      setState(() {});
    });
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repo.getFastingActive(),
        _repo.getFastingSummary(),
        _repo.getFastingHistory(),
      ]);

      if (!mounted) return;

      setState(() {
        _active = results[0] as FastingActiveSession?;
        _summary =
            (results[1] as List<FastingSummaryDay>?) ?? <FastingSummaryDay>[];
        _history =
            (results[2] as List<FastingHistoryItem>?) ?? <FastingHistoryItem>[];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load fasting data.';
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------
  // OPEN FULL HISTORY SCREEN
  // ---------------------------------------------------
  Future<void> _openFullHistory(bool isEn) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FastingHistoryScreen(isEnglish: isEn),
      ),
    );
  }

  // ---------------------------------------------------
  // HELPERS
  // ---------------------------------------------------

  String _formatHm(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour > 12 ? local.hour - 12 : local.hour;
    final m = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // HH:MM:SS formatter based on total seconds
  String _formatElapsedHms(int totalSeconds) {
    final sec = totalSeconds < 0 ? 0 : totalSeconds;
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  int _summaryFastsToday() {
    if (_summary.isEmpty) return 0;
    final now = DateTime.now();
    for (final d in _summary) {
      final dt = d.day.toLocal();
      if (dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day) {
        return d.fastsStarted;
      }
    }
    return 0;
  }

  int _summary16hLast7Days() {
    if (_summary.isEmpty) return 0;
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 6));
    int total = 0;
    for (final d in _summary) {
      final dt = d.day.toLocal();
      if (!dt.isBefore(DateTime(from.year, from.month, from.day)) &&
          !dt.isAfter(DateTime(now.year, now.month, now.day))) {
        total += d.count16hPlus;
      }
    }
    return total;
  }

  // ---------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------

  Future<void> _handleStartFast() async {
    if (_savingStart) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final isEn = widget.isEnglish;

    final protocol = _protocolController.text.trim();
    final targetStr = _targetHoursController.text.trim();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    final target = double.tryParse(targetStr) ?? 0;
    if (target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn
                ? 'Please enter a valid target duration in hours.'
                : 'সঠিক লক্ষ্য সময় (ঘণ্টা) লিখুন।',
          ),
        ),
      );
      return;
    }

    setState(() {
      _savingStart = true;
    });

    try {
      final ok = await _repo.startFast(
        fastKind: _fastKind,
        protocol: protocol.isEmpty ? 'custom' : protocol,
        targetHours: target,
        notes: notes,
      );

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEn ? 'Fast started.' : 'উপবাস শুরু হয়েছে।',
            ),
          ),
        );
        await _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEn
                  ? 'Could not start fast. Please try again.'
                  : 'উপবাস শুরু করা যায়নি, আবার চেষ্টা করুন।',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingStart = false;
        });
      }
    }
  }

  Future<void> _handleEndFast() async {
    if (_savingEnd) return;

    final isEn = widget.isEnglish;

    setState(() {
      _savingEnd = true;
    });

    try {
      final ok = await _repo.endFast(reason: 'completed');

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEn ? 'Fast ended.' : 'উপবাস শেষ হয়েছে।',
            ),
          ),
        );
        await _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEn
                  ? 'Could not end fast. Please try again.'
                  : 'উপবাস শেষ করা যায়নি, আবার চেষ্টা করুন।',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingEnd = false;
        });
      }
    }
  }

  // ---------------------------------------------------
  // UI
  // ---------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isEn = widget.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Fasting Tracker' : 'উপবাস ট্র্যাকার'),
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
        child: Text(
          isEn ? _error! : 'ডেটা লোড করা যায়নি।',
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCurrentFastCard(isEn),
          const SizedBox(height: 16),
          _buildSummaryCard(isEn),
          const SizedBox(height: 16),
          _buildHistorySection(isEn),
        ],
      ),
    );
  }

  // ---------------------------------------------------
  // CURRENT FAST / START FORM
  // ---------------------------------------------------

  Widget _buildCurrentFastCard(bool isEn) {
    final active = _active;

    if (active == null) {
      // No active fast → show start form
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? 'No active fast' : 'বর্তমানে কোনো উপবাস চলছে না',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _fastKind,
                  decoration: InputDecoration(
                    labelText: isEn ? 'Fast type' : 'উপবাসের ধরন',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'intermittent',
                      child: Text(isEn ? 'Intermittent' : 'ইন্টারমিটেন্ট'),
                    ),
                    DropdownMenuItem(
                      value: 'religious',
                      child: Text(isEn ? 'Religious' : 'ধর্মীয়'),
                    ),
                    DropdownMenuItem(
                      value: 'medical',
                      child: Text(isEn ? 'Medical' : 'চিকিৎসাগত'),
                    ),
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text(isEn ? 'Custom' : 'নিজস্ব'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _fastKind = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _protocolController,
                  decoration: InputDecoration(
                    labelText: isEn
                        ? 'Select your fasting time (e.g. 16-8)'
                        : 'উপবাসের সময় লিখুন (যেমন ১৬-৮)',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return isEn
                          ? 'Please enter fasting time.'
                          : 'উপবাসের সময় লিখুন।';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _targetHoursController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        isEn ? 'Target duration (hours)' : 'লক্ষ্য সময় (ঘণ্টা)',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return isEn
                          ? 'Please enter target hours.'
                          : 'লক্ষ্য ঘণ্টা লিখুন।';
                    }
                    final v = double.tryParse(value.trim());
                    if (v == null || v <= 0) {
                      return isEn
                          ? 'Enter a valid number greater than 0.'
                          : '০-এর বেশি সঠিক সংখ্যা লিখুন।';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isEn ? 'Notes (optional)' : 'নোট (ঐচ্ছিক)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savingStart ? null : _handleStartFast,
                    child: _savingStart
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEn ? 'Start Fast' : 'উপবাস শুরু করুন'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Active fast present → central ring
    final now = DateTime.now().toUtc();
    final start = active.startAt.toUtc();
    final elapsedSeconds = now.difference(start).inSeconds;
    final elapsedHours = elapsedSeconds / 3600.0;

    final target = active.targetHours <= 0 ? 1.0 : active.targetHours;
    final progress = (elapsedHours / target).clamp(0.0, 1.0);

    final expectedEnd = start.add(
      Duration(minutes: (active.targetHours * 60).round()),
    );

    final elapsedHms = _formatElapsedHms(elapsedSeconds);
    final startTimeStr = _formatHm(active.startAt);
    final endTimeStr = _formatHm(expectedEnd);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isEn ? 'Current Fast' : 'চলমান উপবাস',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        elapsedHms,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEn ? 'elapsed' : 'কেটেছে',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isEn
                  ? '${active.targetHours.toStringAsFixed(0)} hours target'
                  : 'লক্ষ্য ${active.targetHours.toStringAsFixed(0)} ঘণ্টা',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Start' : 'শুরু',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      startTimeStr,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isEn ? 'End' : 'শেষ',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      endTimeStr,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
            if (active.notes != null && active.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  active.notes!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savingEnd ? null : _handleEndFast,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _savingEnd
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEn ? 'End Fast' : 'উপবাস শেষ করুন'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // SUMMARY CARD
  // ---------------------------------------------------

  Widget _buildSummaryCard(bool isEn) {
    final todayCount = _summaryFastsToday();
    final week16h = _summary16hLast7Days();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEn ? 'Fasting Summary' : 'উপবাস সারাংশ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isEn
                  ? 'Fasts started today: $todayCount'
                  : 'আজকের শুরু করা উপবাস: $todayCount',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              isEn
                  ? '16+ hour fasts (last 7 days): $week16h'
                  : '১৬+ ঘণ্টার উপবাস (শেষ ৭ দিন): $week16h',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // HISTORY SECTION
  // ---------------------------------------------------

  Widget _buildHistorySection(bool isEn) {
    if (_history.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              isEn
                  ? 'No fasting history yet.'
                  : 'এখনও কোনো উপবাসের ইতিহাস নেই।',
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title + "View all"
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEn ? 'Fasting History' : 'উপবাস ইতিহাস',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: () => _openFullHistory(isEn),
                    child: Text(
                      isEn ? 'View all' : 'সব দেখুন',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Preview list inside the card
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final item = _history[index];
                final dateStr = _formatDate(item.startAt);
                final durationStr = item.hours.toStringAsFixed(1);
                final endTime =
                    item.endAt != null ? _formatHm(item.endAt!) : '--';
                final kind = item.fastKind;
                final status = item.brokeReason ?? 'completed';

                return ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    child: Icon(Icons.history, size: 18),
                  ),
                  title: Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    isEn
                        ? 'Duration: ${durationStr}h · Type: $kind · $status'
                        : 'সময়কাল: $durationStrঘণ্টা · ধরন: $kind · $status',
                  ),
                  trailing: Text(
                    endTime,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
