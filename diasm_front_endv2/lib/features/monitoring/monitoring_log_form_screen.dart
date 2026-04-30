import 'package:flutter/material.dart';
import '../../core/monitoring_repository.dart';
import '../../core/monitoring_models.dart';

class MonitoringLogFormScreen extends StatefulWidget {
  static const routeName = '/monitoring/log-form';

  const MonitoringLogFormScreen({super.key});

  @override
  State<MonitoringLogFormScreen> createState() =>
      _MonitoringLogFormScreenState();
}

class _MonitoringLogFormScreenState extends State<MonitoringLogFormScreen> {
  // Palette (teacher approved)
  static const Color cPrimary = Color(0xFF05668D);
  static const Color cPrimaryDark = Color(0xFF028090);
  static const Color cAccent = Color(0xFF02C39A);
  static const Color cBg = Color(0xFFF0F3BD);

  final _glucoseCtrl = TextEditingController();
  final _hba1cCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _sysCtrl = TextEditingController();
  final _diaCtrl = TextEditingController();

  // Cholesterol controllers
  final _cholCtrl = TextEditingController();      // total
  final _cholHdlCtrl = TextEditingController();   // HDL
  final _cholLdlCtrl = TextEditingController();   // LDL

  final _glucoseKind = ValueNotifier<String>('RBS');

  // NEW: steps controller
  final _stepsCtrl = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _glucoseCtrl.dispose();
    _hba1cCtrl.dispose();
    _weightCtrl.dispose();
    _sysCtrl.dispose();
    _diaCtrl.dispose();

    // Cholesterol dispose
    _cholCtrl.dispose();
    _cholHdlCtrl.dispose();
    _cholLdlCtrl.dispose();

    // NEW: dispose steps
    _stepsCtrl.dispose();

    super.dispose();
  }

  double? _parseDoubleField(String label, String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null) {
      throw Exception("Invalid $label value");
    }
    return v;
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;

    setState(() => _submitting = true);

    final repo = MonitoringRepository();
    final now = DateTime.now();

    try {
      // ---------------------------------------------------
      // 1) Glucose
      // ---------------------------------------------------
      // -------- GLUCOSE --------
      final glucoseText = _glucoseCtrl.text.trim();
      if (glucoseText.isNotEmpty) {
        final glucoseVal = double.tryParse(glucoseText);
        if (glucoseVal == null) {
          throw Exception("Invalid glucose value");
        }

        await repo.addGlucose(
          AddGlucosePayload(
            valueMgdl: glucoseVal,
            kind: _glucoseKind.value, // << NEW
            measuredAt: now,
            source: "manual",
          ),
        );
      }

      // ---------------------------------------------------
      // 2) HbA1c
      // ---------------------------------------------------
      final hba1cText = _hba1cCtrl.text.trim();
      if (hba1cText.isNotEmpty) {
        final v = double.tryParse(hba1cText);
        if (v == null) throw Exception("Invalid HbA1c value");

        await repo.addHbA1c(
          AddHbA1cPayload(
            measuredAt: now,
            hba1cPercent: v,
            labName: null,
            source: "manual",
            note: null,
          ),
        );
      }

      // ---------------------------------------------------
      // 3) Weight
      // ---------------------------------------------------
      final weightText = _weightCtrl.text.trim();
      if (weightText.isNotEmpty) {
        final v = double.tryParse(weightText);
        if (v == null) throw Exception("Invalid weight");

        await repo.addWeight(
          AddWeightPayload(
            measuredAt: now,
            weightKg: v,
            heightCm: null,
            source: "manual",
          ),
        );
      }

      // ---------------------------------------------------
      // 4) Blood Pressure (BP)
      // ---------------------------------------------------
      final sysTxt = _sysCtrl.text.trim();
      final diaTxt = _diaCtrl.text.trim();

      if (sysTxt.isNotEmpty && diaTxt.isNotEmpty) {
        final sys = int.tryParse(sysTxt);
        final dia = int.tryParse(diaTxt);

        if (sys == null || dia == null) {
          throw Exception("BP values must be whole numbers");
        }

        await repo.addBP(
          AddBPPayload(
            sysMmHg: sys,
            diaMmHg: dia,
            measuredAt: now,
            source: "manual",
          ),
        );
      }

      // ---------------------------------------------------
      // 5) Cholesterol / Lipids (Total + HDL + LDL)
      // ---------------------------------------------------
      final totalText = _cholCtrl.text;
      final hdlText = _cholHdlCtrl.text;
      final ldlText = _cholLdlCtrl.text;

      final totalVal = _parseDoubleField("total cholesterol", totalText);
      final hdlVal = _parseDoubleField("HDL", hdlText);
      final ldlVal = _parseDoubleField("LDL", ldlText);

      // Only send if at least one of the three is provided
      if (totalVal != null || hdlVal != null || ldlVal != null) {
        await repo.addLipids(
          AddLipidsPayload(
            measuredAt: now,
            totalMgdl: totalVal,
            hdlMgdl: hdlVal,
            ldlMgdl: ldlVal,
            source: "manual",
          ),
        );
      }

      // ---------------------------------------------------
      // 6) Steps  (NEW)
      // ---------------------------------------------------
      final stepsText = _stepsCtrl.text.trim();
      if (stepsText.isNotEmpty) {
        final stepsVal = int.tryParse(stepsText);
        if (stepsVal == null) throw Exception("Invalid steps value");

        await repo.addSteps(
          AddStepsPayload(
            steps: stepsVal,
            dayDate: now, // repo formats YYYY-MM-DD
            measuredAt: null, // optional
            durationMin: null,
            caloriesKcal: null,
            source: "manual",
            note: null,
          ),
        );
      }

      // ---------------------------------------------------
      // DONE
      // ---------------------------------------------------
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved successfully")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.6,
        title: const Text(
          "Log Data",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    _sectionCard(
                      title: "Glucose",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _unitTextField(
                            controller: _glucoseCtrl,
                            hint: "Enter Glucose Level",
                            unit: "mg/dL",
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "গ্লুকোজ লেভেল লিখুন",
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 12),

                          // NEW: Glucose Kind Dropdown
                          ValueListenableBuilder<String>(
                            valueListenable: _glucoseKind,
                            builder: (context, value, _) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF6F6F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButton<String>(
                                  value: value,
                                  isExpanded: true,
                                  underline: SizedBox(),
                                  items: const [
                                    DropdownMenuItem(
                                        value: "FBS",
                                        child: Text("FBS (Fasting)")),
                                    DropdownMenuItem(
                                        value: "RBS",
                                        child: Text("RBS (Random)")),
                                    DropdownMenuItem(
                                        value: "PP2",
                                        child: Text(
                                            "PP2 (2 hr Post Meal)")),
                                    DropdownMenuItem(
                                        value: "BeforeMeal",
                                        child: Text("Before Meal")),
                                    DropdownMenuItem(
                                        value: "AfterMeal",
                                        child: Text("After Meal")),
                                    DropdownMenuItem(
                                        value: "Bedtime",
                                        child: Text("Bedtime")),
                                    DropdownMenuItem(
                                        value: "Custom",
                                        child: Text("Custom")),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) _glucoseKind.value = v;
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    _sectionCard(
                      title: "HbA1c",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _unitTextField(
                            controller: _hba1cCtrl,
                            hint: "Enter HbA1c Level",
                            unit: "%",
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "HbA1c লেভেল লিখুন",
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    _sectionCard(
                      title: "Weight",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _unitTextField(
                            controller: _weightCtrl,
                            hint: "Enter Weight",
                            unit: "kg",
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "ওজন লিখুন (কেজি)",
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    _sectionCard(
                      title: "Blood Pressure",
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _simpleTextField(
                                  controller: _sysCtrl,
                                  hint: "Systolic",
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _simpleTextField(
                                  controller: _diaCtrl,
                                  hint: "Diastolic",
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: const [
                              Expanded(
                                child: Text(
                                  "সিস্টোলিক",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "ডায়াস্টোলিক",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // UPDATED Cholesterol section: Total + HDL + LDL
                    _sectionCard(
                      title: "Cholesterol",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _unitTextField(
                            controller: _cholCtrl,
                            hint: "Enter Total Cholesterol",
                            unit: "mg/dL",
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _cholHdlCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                    hintText: "HDL",
                                    suffixText: "mg/dL",
                                    filled: true,
                                    fillColor: const Color(0xFFF6F6F6),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _cholLdlCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                    hintText: "LDL",
                                    suffixText: "mg/dL",
                                    filled: true,
                                    fillColor: const Color(0xFFF6F6F6),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "কোলেস্টেরল লেভেল লিখুন (মোট, HDL, LDL)",
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),

                    // NEW Steps UI
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: "Steps",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _unitTextField(
                            controller: _stepsCtrl,
                            hint: "Enter Steps",
                            unit: "steps",
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "পদক্ষেপ সংখ্যা লিখুন",
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cAccent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _submitting ? "Saving..." : "Submit",
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------- reusable UI blocks

  Widget _sectionCard({required String title, required Widget child}) {
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _unitTextField({
    required TextEditingController controller,
    required String hint,
    required String unit,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: const Color(0xFFF6F6F6),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          unit,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _simpleTextField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF6F6F6),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
