
// lib/core/monitoring_models.dart
// Models for Monitoring (Metrics) module.
// Matches backend routes in src/modules/metrics/metrics.routes.js and controller responses.

class DashboardSnapshot {
  final double? lastWeightKg;
  final double? lastBmi;
  final double? lastGlucoseMgdl;
  final String? lastBp; // "120/80" style from backend
  final int? lastSteps;
  final double? lastCholTotal;
  final double? lastCholHdl;
  final double? lastCholLdl;
  final double? lastHba1c;

  DashboardSnapshot({
    this.lastWeightKg,
    this.lastBmi,
    this.lastGlucoseMgdl,
    this.lastBp,
    this.lastSteps,
    this.lastCholTotal,
    this.lastCholHdl,
    this.lastCholLdl,
    this.lastHba1c,
  });

  String? get lastBpSys {
    if (lastBp == null || !lastBp!.contains('/')) return null;
    return lastBp!.split('/')[0];
  }

  String? get lastBpDia {
    if (lastBp == null || !lastBp!.contains('/')) return null;
    return lastBp!.split('/')[1];
  }

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    double? d(dynamic v) => v == null ? null : double.tryParse(v.toString());
    int? i(dynamic v) => v == null ? null : int.tryParse(v.toString());

    return DashboardSnapshot(
      lastWeightKg: d(json['last_weight']),
      lastBmi: d(json['last_bmi']),
      lastGlucoseMgdl: d(json['last_glucose']),
      lastBp: json['last_bp']?.toString(),
      lastSteps: i(json['last_steps']),
      lastCholTotal: d(json['last_chol_total']),
      lastCholHdl: d(json['last_chol_hdl']),
      lastCholLdl: d(json['last_chol_ldl']),
      lastHba1c: d(json['last_hba1c']),
    );
  }
}

// ---------------- Latest glucose model (Home card) ----------------
// This is safe: it does not affect any existing code.
class LatestGlucoseReading {
  final int? id;
  final int? userId;
  final DateTime? measuredAt;
  final String? kind;
  final double? valueMgdl;

  // IMPORTANT: backend/db may send either key
  // - value_mmoll  (your current DB)
  // - value_mmol   (correct spelling)
  final double? valueMmol;

  final String? context;
  final double? insulinUnits;
  final String? source;
  final String? note;

  LatestGlucoseReading({
    this.id,
    this.userId,
    this.measuredAt,
    this.kind,
    this.valueMgdl,
    this.valueMmol,
    this.context,
    this.insulinUnits,
    this.source,
    this.note,
  });

  factory LatestGlucoseReading.fromJson(Map<String, dynamic> json) {
    double? d(dynamic v) => v == null ? null : double.tryParse(v.toString());
    int? i(dynamic v) => v == null ? null : int.tryParse(v.toString());

    DateTime? dt(dynamic v) {
      if (v == null) return null;
      final parsed = DateTime.tryParse(v.toString());
      return parsed;
    }

    // support both keys safely
    final mmoll = json['value_mmoll'];
    final mmol = json['value_mmol'];

    return LatestGlucoseReading(
      id: i(json['id']),
      userId: i(json['user_id']),
      measuredAt: dt(json['measured_at']),
      kind: json['kind']?.toString(),
      valueMgdl: d(json['value_mgdl']),
      valueMmol: d(mmoll ?? mmol),
      context: json['context']?.toString(),
      insulinUnits: d(json['insulin_units']),
      source: json['source']?.toString(),
      note: json['note']?.toString(),
    );
  }
}

class GlucoseDailyPoint {
  final DateTime day;
  final double avgMgdl;

  GlucoseDailyPoint({required this.day, required this.avgMgdl});

  factory GlucoseDailyPoint.fromJson(Map<String, dynamic> json) {
    return GlucoseDailyPoint(
      day: DateTime.parse(json['day'].toString()),
      avgMgdl: double.parse(json['avg_mgdl'].toString()),
    );
  }
}

class WeightDailyPoint {
  final DateTime day;
  final double? weightKg;
  final double? bmi;

  WeightDailyPoint({required this.day, this.weightKg, this.bmi});

  factory WeightDailyPoint.fromJson(Map<String, dynamic> json) {
    double? d(dynamic v) => v == null ? null : double.tryParse(v.toString());
    return WeightDailyPoint(
      day: DateTime.parse(json['day'].toString()),
      weightKg: d(json['weight_kg']),
      bmi: d(json['bmi']),
    );
  }
}

class StepsWeeklyPoint {
  final int isoWeek; // e.g. 202547
  final int weekSteps;

  StepsWeeklyPoint({required this.isoWeek, required this.weekSteps});

  factory StepsWeeklyPoint.fromJson(Map<String, dynamic> json) {
    return StepsWeeklyPoint(
      isoWeek: int.parse(json['iso_week'].toString()),
      weekSteps: int.parse(json['week_steps'].toString()),
    );
  }
}

// ---------- Request payload helpers (for log form) ----------

class AddWeightPayload {
  final DateTime measuredAt;
  final double weightKg;
  final double? heightCm;
  final String source; // "manual" | "device" | "import" | "api"
  final String? note;

  AddWeightPayload({
    required this.measuredAt,
    required this.weightKg,
    this.heightCm,
    this.source = 'manual',
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'measured_at': measuredAt.toIso8601String(),
        'weight_kg': weightKg,
        if (heightCm != null) 'height_cm': heightCm,
        'source': source,
        if (note != null) 'note': note,
      };
}

class AddGlucosePayload {
  final DateTime measuredAt;
  final String kind; // FBS/RBS/PP2/BeforeMeal/AfterMeal/Bedtime/Custom
  final double valueMgdl;
  final String? context;
  final double? insulinUnits;
  final String source;
  final String? note;

  AddGlucosePayload({
    required this.measuredAt,
    required this.kind,
    required this.valueMgdl,
    this.context,
    this.insulinUnits,
    this.source = 'manual',
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'measured_at': measuredAt.toIso8601String(),
        'kind': kind,
        'value_mgdl': valueMgdl,
        if (context != null) 'context': context,
        if (insulinUnits != null) 'insulin_units': insulinUnits,
        'source': source,
        if (note != null) 'note': note,
      };
}

class AddHbA1cPayload {
  final DateTime measuredAt;
  final double hba1cPercent;
  final String? labName;
  final String source;
  final String? note;

  AddHbA1cPayload({
    required this.measuredAt,
    required this.hba1cPercent,
    this.labName,
    this.source = 'manual',
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'measured_at': measuredAt.toIso8601String(),
        'hba1c_percent': hba1cPercent,
        if (labName != null) 'lab_name': labName,
        'source': source,
        if (note != null) 'note': note,
      };
}

class AddBPPayload {
  final DateTime measuredAt;
  final int sysMmHg;
  final int diaMmHg;
  final int? pulseBpm;
  final String posture; // Sitting/Standing/Lying/Unknown
  final String source;
  final String? note;

  AddBPPayload({
    required this.measuredAt,
    required this.sysMmHg,
    required this.diaMmHg,
    this.pulseBpm,
    this.posture = 'Unknown',
    this.source = 'manual',
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'measured_at': measuredAt.toIso8601String(),
        'sys_mmHg': sysMmHg,
        'dia_mmHg': diaMmHg,
        if (pulseBpm != null) 'pulse_bpm': pulseBpm,
        'posture': posture,
        'source': source,
        if (note != null) 'note': note,
      };
}

class AddLipidsPayload {
  final DateTime measuredAt;
  final double? totalMgdl;
  final double? ldlMgdl;
  final double? hdlMgdl;
  final double? tgMgdl;
  final String source;
  final String? note;

  AddLipidsPayload({
    required this.measuredAt,
    this.totalMgdl,
    this.ldlMgdl,
    this.hdlMgdl,
    this.tgMgdl,
    this.source = 'manual',
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'measured_at': measuredAt.toIso8601String(),
        if (totalMgdl != null) 'total_mgdl': totalMgdl,
        if (ldlMgdl != null) 'ldl_mgdl': ldlMgdl,
        if (hdlMgdl != null) 'hdl_mgdl': hdlMgdl,
        if (tgMgdl != null) 'tg_mgdl': tgMgdl,
        'source': source,
        if (note != null) 'note': note,
      };
}

class AddStepsPayload {
  final DateTime? measuredAt; // optional if you log by day_date on backend
  final DateTime? dayDate; // use one of them
  final int steps;
  final int? durationMin;
  final int? caloriesKcal;
  final String source;
  final String? note;

  AddStepsPayload({
    this.measuredAt,
    this.dayDate,
    required this.steps,
    this.durationMin,
    this.caloriesKcal,
    this.source = 'manual',
    this.note,
  });

  Map<String, dynamic> toJson() => {
        if (measuredAt != null) 'measured_at': measuredAt!.toIso8601String(),
        if (dayDate != null)
          'day_date': dayDate!.toIso8601String().substring(0, 10),
        'steps': steps,
        if (durationMin != null) 'duration_min': durationMin,
        if (caloriesKcal != null) 'calories_kcal': caloriesKcal,
        'source': source,
        if (note != null) 'note': note,
      };
}
