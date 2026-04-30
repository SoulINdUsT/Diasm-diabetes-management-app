// lib/core/rightpath_models.dart

/// Backend status: ON_TRACK / ALMOST / NEEDS_CARE
enum RightPathStatus {
  onTrack,
  almost,
  needsCare,
  unknown,
}

RightPathStatus rightPathStatusFromString(String? value) {
  switch (value) {
    case 'ON_TRACK':
      return RightPathStatus.onTrack;
    case 'ALMOST':
      return RightPathStatus.almost;
    case 'NEEDS_CARE':
      return RightPathStatus.needsCare;
    default:
      return RightPathStatus.unknown;
  }
}

String rightPathStatusToLabelEn(RightPathStatus s) {
  switch (s) {
    case RightPathStatus.onTrack:
      return 'On track';
    case RightPathStatus.almost:
      return 'Almost there';
    case RightPathStatus.needsCare:
      return 'Needs care';
    case RightPathStatus.unknown:
    default:
      return 'Unknown';
  }
}

String rightPathStatusToLabelBn(RightPathStatus s) {
  switch (s) {
    case RightPathStatus.onTrack:
      return 'ভালো চলছে';
    case RightPathStatus.almost:
      return 'কিছুটা উন্নতি দরকার';
    case RightPathStatus.needsCare:
      return 'সতর্ক হওয়া জরুরি';
    case RightPathStatus.unknown:
    default:
      return 'অজানা';
  }
}

/// /right-path/today response
class RightPathTodayStatus {
  final int userId;
  final DateTime date;
  final int dailyScore; // 0–100
  final RightPathStatus status;

  final int walkMinutes;
  final int hydrationGlasses;
  final bool mealsOnTime;
  final bool glucoseChecked;
  final double sleepHours;

  final String messageEn;
  final String messageBn;

  RightPathTodayStatus({
    required this.userId,
    required this.date,
    required this.dailyScore,
    required this.status,
    required this.walkMinutes,
    required this.hydrationGlasses,
    required this.mealsOnTime,
    required this.glucoseChecked,
    required this.sleepHours,
    required this.messageEn,
    required this.messageBn,
  });

  factory RightPathTodayStatus.fromJson(Map<String, dynamic> json) {
    final dateStr = json['date'] as String? ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();

    int asInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is String) return int.tryParse(v.trim()) ?? 0;
      return 0;
    }

    double asDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim()) ?? 0.0;
      return 0.0;
    }

    bool asBool(dynamic v) {
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is String) {
        final s = v.toLowerCase().trim();
        return s == '1' || s == 'true' || s == 'yes';
      }
      return false;
    }

    return RightPathTodayStatus(
      userId: asInt(json['userId']),
      date: date,
      dailyScore: asInt(json['dailyScore']),
      status: rightPathStatusFromString(json['status'] as String?),
      walkMinutes: asInt(json['walkMinutes']),
      hydrationGlasses: asInt(json['hydrationGlasses']),
      mealsOnTime: asBool(json['mealsOnTime']),
      glucoseChecked: asBool(json['glucoseChecked']),
      sleepHours: asDouble(json['sleepHours']),
      messageEn: (json['messageEn'] ?? '') as String,
      messageBn: (json['messageBn'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'date': date.toIso8601String().substring(0, 10),
        'dailyScore': dailyScore,
        'status': status.toString().split('.').last,
        'walkMinutes': walkMinutes,
        'hydrationGlasses': hydrationGlasses,
        'mealsOnTime': mealsOnTime,
        'glucoseChecked': glucoseChecked,
        'sleepHours': sleepHours,
        'messageEn': messageEn,
        'messageBn': messageBn,
      };

  /// 0.0–1.0 for progress indicators
  double get scoreFraction => (dailyScore.clamp(0, 100)) / 100.0;
}

/// /right-path/weekly-summary response
class RightPathWeeklySummary {
  final DateTime fromDate;
  final DateTime toDate;
  final int daysTracked;
  final int averageScore;
  final int onTrackDays;
  final int almostDays;
  final int needsCareDays;
  final bool weightCheckedThisWeek;

  RightPathWeeklySummary({
    required this.fromDate,
    required this.toDate,
    required this.daysTracked,
    required this.averageScore,
    required this.onTrackDays,
    required this.almostDays,
    required this.needsCareDays,
    required this.weightCheckedThisWeek,
  });

  factory RightPathWeeklySummary.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is String) return int.tryParse(v.trim()) ?? 0;
      return 0;
    }

    bool asBool(dynamic v) {
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is String) {
        final s = v.toLowerCase().trim();
        return s == '1' || s == 'true' || s == 'yes';
      }
      return false;
    }

    DateTime asDate(dynamic v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return RightPathWeeklySummary(
      fromDate: asDate(json['fromDate']),
      toDate: asDate(json['toDate']),
      daysTracked: asInt(json['daysTracked']),
      averageScore: asInt(json['averageScore']),
      onTrackDays: asInt(json['onTrackDays']),
      almostDays: asInt(json['almostDays']),
      needsCareDays: asInt(json['needsCareDays']),
      weightCheckedThisWeek: asBool(json['weightCheckedThisWeek']),
    );
  }

  Map<String, dynamic> toJson() => {
        'fromDate': fromDate.toIso8601String(),
        'toDate': toDate.toIso8601String(),
        'daysTracked': daysTracked,
        'averageScore': averageScore,
        'onTrackDays': onTrackDays,
        'almostDays': almostDays,
        'needsCareDays': needsCareDays,
        'weightCheckedThisWeek': weightCheckedThisWeek,
      };
}
