import 'package:flutter/material.dart';

class MonitoringSummaryScreen extends StatefulWidget {
  static const routeName = '/monitoring/summary';

  const MonitoringSummaryScreen({super.key});

  @override
  State<MonitoringSummaryScreen> createState() =>
      _MonitoringSummaryScreenState();
}

class _MonitoringSummaryScreenState extends State<MonitoringSummaryScreen> {
  // Palette 
  static const Color cPrimary = Color(0xFF05668D);
  static const Color cPrimaryDark = Color(0xFF028090);
  static const Color cAccent = Color(0xFF02C39A);
  static const Color cBg = Color(0xFFF0F3BD);

  bool weekly = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.6,
        centerTitle: true,
        title: const Text(
          "Summary",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // later language/global toggle if you want
            },
            icon: const Icon(Icons.public),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _periodToggle(),
              const SizedBox(height: 14),

              const Text(
                "Glucose",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _glucoseSummaryCard(),
              const SizedBox(height: 16),

              const Text(
                "HbA1c",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _simpleMetricCard(
                title: "HbA1c Levels",
                value: "6.5",
                unit: "%",
                subtitle: weekly ? "Last 7 Days" : "Last 30 Days",
              ),
              const SizedBox(height: 16),

              const Text(
                "Weight",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _simpleMetricCard(
                title: "Weight Trend",
                value: "75",
                unit: "kg",
                subtitle: weekly ? "Last 7 Days" : "Last 30 Days",
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Widgets

  Widget _periodToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => weekly = true),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: weekly ? cPrimaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Weekly",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: weekly ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => weekly = false),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !weekly ? cPrimaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Monthly",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: !weekly ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glucoseSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Glucose Levels",
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                "120",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 4),
              const Text(
                "mg/dL",
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(width: 8),
              Text(
                weekly ? "Last 7 Days  ↑ +5%" : "Last 30 Days  ↑ +5%",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Chart placeholder for now
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: cBg.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text(
              "Chart will appear here",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _statMiniCard(
                  label: "Average",
                  value: "120 mg/dL",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statMiniCard(
                  label: "Readings",
                  value: "28",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statMiniCard({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _simpleMetricCard({
    required String title,
    required String value,
    required String unit,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
