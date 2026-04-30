
import 'package:flutter/material.dart';

import 'package:diasm_front_endv2/core/api_client.dart';
import 'package:diasm_front_endv2/core/auth_storage.dart';

class ActivityHistoryScreen extends StatefulWidget {
  static const routeName = '/tools/lifestyle/activity/history';

  final bool isEnglish;
  const ActivityHistoryScreen({super.key, required this.isEnglish});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final ApiClient _api = ApiClient();
  final AuthStorage _auth = AuthStorage();

  bool _loading = true;
  String? _error;
  List<dynamic> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<int> _resolveUserId() async {
    final id = await _auth.getUserId();
    if (id != null) return id;
    return 1;
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = await _resolveUserId();

      final res = await _api.dio.get(
        '/lifestyle/activity/daily',
        queryParameters: {
          'user_id': userId,
          'limit': 14, // last 14 days
        },
      );

      final data = res.data;
      final list = (data is Map<String, dynamic>)
          ? (data['data'] as List<dynamic>? ?? const [])
          : (data as List<dynamic>? ?? const []);

      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load history.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Activity History' : 'কার্যকলাপের ইতিহাস'),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEn
                    ? 'Could not load history.'
                    : 'ইতিহাস লোড করা যায়নি।',
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadHistory,
                child: Text(isEn ? 'Retry' : 'আবার চেষ্টা করুন'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(
          isEn ? 'No activity history yet.' : 'এখনও কোনো কার্যকলাপের ইতিহাস নেই।',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildWeeklySummaryCard(isEn);
        }

        final row = _items[index - 1] as Map<String, dynamic>;

        final dayStr = row['day']?.toString() ?? '';
        final minutesStr = row['minutes']?.toString() ?? '0';
        final distanceStr = row['distance_km']?.toString() ?? '0';

        final title = _formatDayDate(dayStr, isEn);

        final subtitle = isEn
            ? 'Minutes: $minutesStr · Distance: $distanceStr km'
            : 'মিনিট: $minutesStr · দূরত্ব: $distanceStr কিমি';

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            title: Text(title),
            subtitle: Text(subtitle),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------
  // Weekly summary "mini chart" at the top
  // ---------------------------------------------------
  Widget _buildWeeklySummaryCard(bool isEn) {
    // Take up to 7 most recent entries and reverse so oldest -> newest
    final bars = _items.take(7).toList().reversed.toList();

    // Compute max minutes for scaling
    double maxMinutes = 0;
    for (final raw in bars) {
      final row = raw as Map<String, dynamic>;
      final m = double.tryParse(row['minutes']?.toString() ?? '0') ?? 0;
      if (m > maxMinutes) maxMinutes = m;
    }
    if (maxMinutes <= 0) {
      maxMinutes = 1; // avoid divide-by-zero
    }

    final daysLabelEn =
        bars.length == 1 ? 'Last 1 day' : 'Last ${bars.length} days';
    final daysLabelBn =
        bars.length == 1 ? 'শেষ ১ দিন' : 'শেষ ${bars.length} দিন';

    final cs = Theme.of(context).colorScheme;

    // 7 different colors for 7 days
    final palette = <Color>[
      cs.primary,
      cs.secondary,
      cs.tertiary,
      cs.primaryContainer,
      cs.secondaryContainer,
      cs.tertiaryContainer,
      cs.error,
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEn ? 'Weekly Activity' : 'সাপ্তাহিক কার্যকলাপ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: bars
                    .asMap()
                    .entries
                    .map((entry) {
                      final index = entry.key;
                      final raw = entry.value;
                      final row = raw as Map<String, dynamic>;
                      final dayStr = row['day']?.toString() ?? '';
                      final minutes =
                          double.tryParse(row['minutes']?.toString() ?? '0') ??
                              0;

                      final date = _parseDay(dayStr);
                      final label = _weekdayLabel(date, isEn);

                      final heightFactor =
                          (minutes / maxMinutes).clamp(0.0, 1.0);

                      final color = palette[index % palette.length];

                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: heightFactor,
                                  child: Container(
                                    width: 14,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              minutes.toStringAsFixed(0),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isEn
                  ? '$daysLabelEn · minutes per day'
                  : '$daysLabelBn · প্রতিদিনের মিনিট',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // Helpers
  // ---------------------------------------------------
  DateTime _parseDay(String dayStr) {
    try {
      return DateTime.parse(dayStr);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _weekdayLabel(DateTime d, bool isEn) {
    const en = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const bn = ['সো', 'মং', 'বু', 'বৃ', 'শু', 'শনি', 'রবি'];
    final idx = d.weekday - 1; // 1..7 -> 0..6
    if (idx < 0 || idx > 6) return '';
    return isEn ? en[idx] : bn[idx];
  }

  String _formatDayDate(String dayStr, bool isEn) {
    if (dayStr.isEmpty) return dayStr;

    try {
      final parts = dayStr.split('-');
      if (parts.length != 3) return dayStr;

      final y = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final day = int.tryParse(parts[2]) ?? 0;

      if (day < 1 || day > 31 || m < 1 || m > 12 || y == 0) {
        return dayStr;
      }

      final enMonths = <String>[
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
        'Dec',
      ];

      final bnMonths = <String>[
        'জানুয়ারি',
        'ফেব্রুয়ারি',
        'মার্চ',
        'এপ্রিল',
        'মে',
        'জুন',
        'জুলাই',
        'আগস্ট',
        'সেপ্টেম্বর',
        'অক্টোবর',
        'নভেম্বর',
        'ডিসেম্বর',
      ];

      final monthName = isEn ? enMonths[m - 1] : bnMonths[m - 1];

      return '$day $monthName $y';
    } catch (_) {
      return dayStr;
    }
  }
}
