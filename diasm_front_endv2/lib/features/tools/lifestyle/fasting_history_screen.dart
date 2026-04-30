import 'package:flutter/material.dart';

import 'package:diasm_front_endv2/core/lifestyle_models.dart';
import 'package:diasm_front_endv2/core/lifestyle_repository.dart';

class FastingHistoryScreen extends StatefulWidget {
  final bool isEnglish;
  const FastingHistoryScreen({super.key, required this.isEnglish});

  @override
  State<FastingHistoryScreen> createState() => _FastingHistoryScreenState();
}

class _FastingHistoryScreenState extends State<FastingHistoryScreen> {
  final _repo = LifestyleRepository();

  bool _loading = true;
  String? _error;
  List<FastingHistoryItem> _history = <FastingHistoryItem>[];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _repo.getFastingHistory();
      if (!mounted) return;
      setState(() {
        _history = rows ?? <FastingHistoryItem>[];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load fasting history.';
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatHm(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour > 12 ? local.hour - 12 : local.hour;
    final m = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Fasting History' : 'উপবাস ইতিহাস'),
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
          isEn ? _error! : 'ইতিহাস লোড করা যায়নি।',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_history.isEmpty) {
      return Center(
        child: Text(
          isEn
              ? 'No fasting history yet.'
              : 'এখনও কোনো উপবাসের ইতিহাস নেই।',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _history[index];
          final dateStr = _formatDate(item.startAt);
          final durationStr = item.hours.toStringAsFixed(1);
          final endTime =
              item.endAt != null ? _formatHm(item.endAt!) : '--';
          final kind = item.fastKind;
          final status = item.brokeReason ?? 'completed';

          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
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
            ),
          );
        },
      ),
    );
  }
}
