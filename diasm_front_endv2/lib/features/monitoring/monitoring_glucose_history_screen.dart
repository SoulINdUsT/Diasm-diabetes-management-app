import 'package:flutter/material.dart';
import '../../core/monitoring_repository.dart';

class MonitoringGlucoseHistoryScreen extends StatefulWidget {
  static const routeName = "/monitoring/glucose-history";

  final bool isEnglish;
  const MonitoringGlucoseHistoryScreen({
    super.key,
    required this.isEnglish,
  });

  @override
  State<MonitoringGlucoseHistoryScreen> createState() =>
      _MonitoringGlucoseHistoryScreenState();
}

class _MonitoringGlucoseHistoryScreenState
    extends State<MonitoringGlucoseHistoryScreen> {
  final _repo = MonitoringRepository(); // factory -> singleton

  bool _loading = true;
  String? _error;

  List<GlucoseLog> _logs = [];

  // kinds order + labels
  final List<String> _kinds = const [
    "FBS",
    "RBS",
    "PP2",
    "BeforeMeal",
    "AfterMeal",
    "Bedtime",
    "Custom",
  ];

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _normKind(String k) => k.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<dynamic> _extractRows(Map<String, dynamic> res) {
    if (res['rows'] is List) return res['rows'] as List;
    if (res['items'] is List) return res['items'] as List;
    if (res['data'] is List) return res['data'] as List;
    return const [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 30));

      final res = await _repo.listGlucose(
        page: 1,
        limit: 500,
        from: _fmtDate(from),
        to: _fmtDate(now),
      );

      final raw = _extractRows(res);

      final logs = raw
          .whereType<Map>()
          .map((e) => GlucoseLog.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ))
          .toList()
        ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));

      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = widget.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEnglish ? "Glucose Details" : "গ্লুকোজ বিস্তারিত"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Text(
                        isEnglish
                            ? "Category-wise History (Last 30 days)"
                            : "ধরণ অনুযায়ী ইতিহাস (শেষ ৩০ দিন)",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ..._kinds.map((kind) {
                        final items = _logs
                            .where((e) =>
                                _normKind(e.kind) == _normKind(kind))
                            .toList()
                          ..sort((a, b) =>
                              b.measuredAt.compareTo(a.measuredAt));

                        if (items.isEmpty) return const SizedBox.shrink();

                        final avg = items
                                .map((e) => e.valueMgdl)
                                .fold<double>(0, (a, b) => a + b) /
                            items.length;

                        final latest = items.first.valueMgdl;

                        return _kindCard(
                          kind: kind,
                          isEnglish: isEnglish,
                          avg: avg,
                          latest: latest,
                          items: items.take(10).toList(),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }

  Widget _kindCard({
    required String kind,
    required bool isEnglish,
    required double avg,
    required double latest,
    required List<GlucoseLog> items,
  }) {
    String kindLabel(String k) {
      if (isEnglish) return k;
      switch (k) {
        case "FBS":
          return "FBS (খালি পেটে)";
        case "RBS":
          return "RBS (যেকোনো সময়)";
        case "PP2":
          return "PP2 (খাবার ২ ঘন্টা পরে)";
        case "BeforeMeal":
          return "খাবারের আগে";
        case "AfterMeal":
          return "খাবারের পরে";
        case "Bedtime":
          return "ঘুমের আগে";
        default:
          return "Custom";
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kindLabel(kind),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniStat(
                  title: isEnglish ? "Average" : "গড়",
                  value: avg.toStringAsFixed(0),
                ),
                const SizedBox(width: 8),
                _miniStat(
                  title: isEnglish ? "Latest" : "সর্বশেষ",
                  value: latest.toStringAsFixed(0),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ...items.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${e.measuredAt.year}-${e.measuredAt.month.toString().padLeft(2, '0')}-${e.measuredAt.day.toString().padLeft(2, '0')}  "
                        "${e.measuredAt.hour.toString().padLeft(2, '0')}:${e.measuredAt.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      "${e.valueMgdl.toStringAsFixed(0)} mg/dL",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _miniStat({required String title, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

// Local model for listGlucose response
class GlucoseLog {
  final int id;
  final DateTime measuredAt;
  final String kind;
  final double valueMgdl;

  GlucoseLog({
    required this.id,
    required this.measuredAt,
    required this.kind,
    required this.valueMgdl,
  });

  factory GlucoseLog.fromJson(Map<String, dynamic> json) {
    return GlucoseLog(
      id: int.tryParse(json["id"].toString()) ?? 0,
      measuredAt: DateTime.parse(json["measured_at"].toString()),
      kind: (json["kind"] ?? "RBS").toString(),
      valueMgdl: double.tryParse(json["value_mgdl"].toString()) ?? 0.0,
    );
  }
}
