
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';


import '../../core/monitoring_repository.dart';
import '../../core/monitoring_models.dart';
import 'monitoring_log_form_screen.dart';
import 'monitoring_glucose_history_screen.dart';
import 'widgets/fitbit_line_chart.dart';
import 'widgets/glucose_bar_chart.dart';

class MonitoringScreen extends StatefulWidget {
  static const routeName = '/monitoring';

  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
 // Palette (hooked into global theme)
static const Color cPrimary = AppColors.primary;
static const Color cPrimaryDark = AppColors.primaryDark;
static const Color cAccent = AppColors.accent;
static const Color cBg = AppColors.background;

  bool isEnglish = true;

  final _repo = MonitoringRepository();

  DashboardSnapshot? _snapshot;
  List<GlucoseDailyPoint> _glucoseDaily = [];
  List<WeightDailyPoint> _weightDaily = [];
  List<StepsWeeklyPoint> _stepsWeekly = [];

  bool _loading = true;
  String? _loadError;

  // helper for YYYY-MM-DD
  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 6));

      final results = await Future.wait([
        _repo.getDashboardSnapshot(),
        _repo.getGlucoseDailySeries(
          from: _fmtDate(from),
          to: _fmtDate(now),
        ),
        _repo.getWeightDailySeries(),
        _repo.getStepsWeekly(weeks: 8),
      ]);

      setState(() {
        _snapshot = results[0] as DashboardSnapshot?;
        _glucoseDaily = (results[1] as List<GlucoseDailyPoint>);
        _weightDaily = (results[2] as List<WeightDailyPoint>);
        _stepsWeekly = (results[3] as List<StepsWeeklyPoint>);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  // ---------- derived % change helpers
  double? _pctFromSeries(List<double> values) {
    if (values.length < 2) return null;
    final prev = values[values.length - 2];
    final last = values.last;
    if (prev == 0) return null;
    return ((last - prev) / prev) * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        //backgroundColor: cPrimary,
       // foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Monitoring",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // settings later (maybe summary/history)
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _errorView()
                : RefreshIndicator(
                    onRefresh: _fetchAll,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _langSwitch(),
                          const SizedBox(height: 12),

                          Text(
                            isEnglish ? "Today's Summary" : "আজকের সারাংশ",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),

                          _summaryRow(),
                          const SizedBox(height: 8),

                          _bpCholRow(),
                          const SizedBox(height: 14),

                          _glucoseCard(),
                          const SizedBox(height: 12),
                          _weightCard(),
                          const SizedBox(height: 12),
                          _stepsCard(),
                        ],
                      ),
                    ),
                  ),
      ),
      bottomSheet: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE5E5E5)),
              ),
            ),
            onPressed: () {
              context.push(MonitoringLogFormScreen.routeName).then((_) {
                _fetchAll();
              });
            },
            icon: const Icon(Icons.add),
            label: Text(
              isEnglish ? "Add New Entry" : "নতুন এন্ট্রি যোগ করুন",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _loadError ?? "Unknown error",
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  // ---------- UI blocks ----------

  Widget _langSwitch() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isEnglish = true),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isEnglish ? cPrimaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  "English",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isEnglish ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isEnglish = false),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !isEnglish ? cPrimaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  "বাংলা",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: !isEnglish ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow() {
    final snap = _snapshot;
    final g = snap?.lastGlucoseMgdl;
    final w = snap?.lastWeightKg;
    final s = snap?.lastSteps;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _miniCard(
                icon: Icons.water_drop_outlined,
                title: isEnglish ? "Glucose" : "গ্লুকোজ",
                value: g == null ? "--" : g.toStringAsFixed(0),
                unit: "mg/dL",
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _miniCard(
                icon: Icons.monitor_weight_outlined,
                title: isEnglish ? "Weight" : "ওজন",
                value: w == null ? "--" : w.toStringAsFixed(1),
                unit: "kg",
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _miniCard(
          icon: Icons.directions_walk,
          title: isEnglish ? "Steps" : "পদক্ষেপ",
          value: s == null ? "--" : s.toString(),
          unit: "",
          fullWidth: true,
        ),
      ],
    );
  }

    Widget _bpCholRow() {
    final bp = _snapshot?.lastBp; // "120/80" or null
    final cholTotal = _snapshot?.lastCholTotal;
    final cholHdl = _snapshot?.lastCholHdl;
    final cholLdl = _snapshot?.lastCholLdl;

    final cholLine = (cholHdl == null && cholLdl == null)
        ? (isEnglish
            ? "HDL / LDL not logged"
            : "HDL / LDL এখনো লগ করা হয়নি")
        : "HDL ${cholHdl?.toStringAsFixed(0) ?? '--'} | "
          "LDL ${cholLdl?.toStringAsFixed(0) ?? '--'}";

    return Row(
      children: [
        // BP card (unchanged, still uses _miniCard)
        Expanded(
          child: _miniCard(
            icon: Icons.favorite_border,
            title: isEnglish ? "Blood Pressure" : "রক্তচাপ",
            value: bp ?? "--",
            unit: "mmHg",
            fullWidth: true,
          ),
        ),
        const SizedBox(width: 10),
        // Custom Cholesterol card with extra HDL/LDL line
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEDEDED)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bloodtype_outlined,
                        color: cPrimary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEnglish ? "Cholesterol" : "কোলেস্টেরল",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      cholTotal == null
                          ? "--"
                          : cholTotal.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "mg/dL",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  cholLine,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _glucoseCard() {
    final latest = _snapshot?.lastGlucoseMgdl;
    final hba1c = _snapshot?.lastHba1c;

    final values = _glucoseDaily.map((e) => e.avgMgdl).toList();
    final labels = _glucoseDaily.map((e) => _shortDay(e.day)).toList();
    final pct = _pctFromSeries(values);

    return _sectionCard(
      title: isEnglish ? "Glucose Levels" : "গ্লুকোজ লেভেল",
      subtitleRight: isEnglish ? "Today" : "আজ",
      headerChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                latest == null ? "--" : latest.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                "mg/dL",
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(width: 8),
              _pctWidget(pct),
              const Spacer(),
              if (hba1c != null)
  Text(
    "HbA1c ${hba1c.toStringAsFixed(1)}%",
    style: const TextStyle(
      fontSize: 14,               // bigger
      fontWeight: FontWeight.w800,
      color: Color(0xFF05668D),   // same teal as header (cPrimary)
    ),
  ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                context.push(
                  MonitoringGlucoseHistoryScreen.routeName,
                  extra: isEnglish,
                );
              },
              child: Text(isEnglish ? "View Details" : "বিস্তারিত দেখুন"),
            ),
          ),
        ],
      ),
      child: values.length >= 2
          ? GlucoseBarChart(
              values: values,
              labels: labels,
              height: 140,
            )
          : _emptyChartHint(),
    );
  }

  Widget _weightCard() {
    final latest = _snapshot?.lastWeightKg;

    final values = _weightDaily
        .where((e) => e.weightKg != null)
        .map((e) => e.weightKg!)
        .toList();

    final labels = _weightDaily.map((e) => _shortDay(e.day)).toList();
    final pct = _pctFromSeries(values);

    return _sectionCard(
      title: isEnglish ? "Weight" : "ওজন",
      subtitleRight: isEnglish ? "Last 7 Days" : "শেষ ৭ দিন",
      headerChild: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            latest == null ? "--" : latest.toStringAsFixed(1),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 6),
          const Text(
            "kg",
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(width: 8),
          _pctWidget(pct),
        ],
      ),
      child: values.length >= 2
          ? FitbitLineChart(values: values, labels: labels, height: 140)
          : _emptyChartHint(),
    );
  }

  Widget _stepsCard() {
    final latest = _snapshot?.lastSteps;

    final values = _stepsWeekly.map((e) => e.weekSteps.toDouble()).toList();

    // convert index -> weekday name (Sun, Mon, Tue...)
    final labels = List.generate(
      _stepsWeekly.length,
      (i) => _weekdayName(i),
    );

    final pct = _pctFromSeries(values);

    return _sectionCard(
      title: isEnglish ? "Steps" : "পদক্ষেপ",
      subtitleRight: isEnglish ? "Last 7 Days" : "শেষ ৭ দিন",
      headerChild: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            latest == null ? "--" : latest.toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 6),
          Text(
            isEnglish ? "steps" : "পদক্ষেপ",
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(width: 8),
          _pctWidget(pct),
        ],
      ),
      child: values.length >= 2
          ? FitbitLineChart(values: values, labels: labels, height: 130)
          : _emptyChartHint(),
    );
  }

  Widget _miniCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        children: [
          Icon(icon, color: cPrimary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitleRight,
    required Widget headerChild,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                subtitleRight,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          headerChild,
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _emptyChartHint() {
    return Container(
      height: 110,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isEnglish ? "Chart will appear here" : "এখানে চার্ট দেখাবে",
        style: const TextStyle(color: Colors.black54),
      ),
    );
  }

  Widget _pctWidget(double? pct) {
    if (pct == null) return const SizedBox.shrink();
    final positive = pct >= 0;
    return Text(
      "${positive ? "+" : ""}${pct.toStringAsFixed(0)}%",
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: positive ? Colors.green : Colors.red,
      ),
    );
  }

  String _shortDay(DateTime d) {
    const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    return days[d.weekday % 7];
  }

  String _weekdayName(int i) {
    const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    return days[i % 7];
  }
}
