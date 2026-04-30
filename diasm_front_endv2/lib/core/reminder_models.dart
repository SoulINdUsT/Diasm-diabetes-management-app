import 'dart:convert';

enum ReminderType {
  medication,
  hydration,
  hba1c,
  bp,
  custom;

  static ReminderType fromApi(String v) {
    switch (v.toUpperCase()) {
      case 'MEDICATION':
        return ReminderType.medication;
      case 'HYDRATION':
        return ReminderType.hydration;
      case 'HBA1C':
        return ReminderType.hba1c;
      case 'BP':
        return ReminderType.bp;
      case 'CUSTOM':
      default:
        return ReminderType.custom;
    }
  }

  String toApi() {
    switch (this) {
      case ReminderType.medication:
        return 'MEDICATION';
      case ReminderType.hydration:
        return 'HYDRATION';
      case ReminderType.hba1c:
        return 'HBA1C';
      case ReminderType.bp:
        return 'BP';
      case ReminderType.custom:
        return 'CUSTOM';
    }
  }

  String labelEn() {
    switch (this) {
      case ReminderType.medication:
        return 'Medication';
      case ReminderType.hydration:
        return 'Hydration';
      case ReminderType.hba1c:
        return 'HbA1c';
      case ReminderType.bp:
        return 'Blood Pressure';
      case ReminderType.custom:
        return 'Custom';
    }
  }

  String labelBn() {
    switch (this) {
      case ReminderType.medication:
        return 'ওষুধ';
      case ReminderType.hydration:
        return 'পানি';
      case ReminderType.hba1c:
        return 'HbA1c';
      case ReminderType.bp:
        return 'রক্তচাপ';
      case ReminderType.custom:
        return 'কাস্টম';
    }
  }
}

class Reminder {
  final int id;
  final int userId;
  final ReminderType type;
  final String title;
  final String messageEn;
  final String messageBn;
  final String timezone;

  final String? rrule;
  final List<String>? timesJson;
  final int? intervalMinutes;

  final DateTime startDate;
  final DateTime? endDate;

  final bool active;
  final int snoozeMinutes;

  final Map<String, dynamic>? metaJson;
  final DateTime? lastEnqueuedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  Reminder({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.messageEn,
    required this.messageBn,
    required this.timezone,
    required this.startDate,
    required this.createdAt,
    required this.updatedAt,
    this.rrule,
    this.timesJson,
    this.intervalMinutes,
    this.endDate,
    this.active = true,
    this.snoozeMinutes = 0,
    this.metaJson,
    this.lastEnqueuedAt,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    List<String>? parseTimes(dynamic v) {
      if (v == null) return null;
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String && v.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(v);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      return null;
    }

    Map<String, dynamic>? parseMap(dynamic v) {
      if (v == null) return null;
      if (v is Map<String, dynamic>) return v;
      if (v is String && v.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(v);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {}
      }
      return null;
    }

    return Reminder(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      type: ReminderType.fromApi(json['type'] ?? 'CUSTOM'),
      title: (json['title'] ?? '').toString(),
      messageEn: (json['message_en'] ?? '').toString(),
      messageBn: (json['message_bn'] ?? '').toString(),
      timezone: (json['timezone'] ?? 'Asia/Dhaka').toString(),
      rrule: json['rrule']?.toString(),
      timesJson: parseTimes(json['times_json']),
      intervalMinutes: json['interval_minutes'] == null
          ? null
          : (json['interval_minutes'] as num).toInt(),
      startDate: DateTime.parse(json['start_date']),
      endDate:
          json['end_date'] == null ? null : DateTime.parse(json['end_date']),
      active: (json['active'] ?? 1) == 1 || json['active'] == true,
      snoozeMinutes: json['snooze_minutes'] == null
          ? 0
          : (json['snooze_minutes'] as num).toInt(),
      metaJson: parseMap(json['meta_json']),
      lastEnqueuedAt: json['last_enqueued_at'] == null
          ? null
          : DateTime.tryParse(json['last_enqueued_at'].toString()),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJsonForCreateOrUpdate() {
    return {
      "type": type.toApi(),
      "title": title,
      "message_en": messageEn,
      "message_bn": messageBn,
      "timezone": timezone,
      "rrule": rrule,
      "times_json": timesJson,
      "interval_minutes": intervalMinutes,
      "start_date": _fmtDate(startDate),
      "end_date": endDate == null ? null : _fmtDate(endDate!),
      "active": active ? 1 : 0,
      "snooze_minutes": snoozeMinutes,
      "meta_json": metaJson,
    };
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Reminder copyWith({
    ReminderType? type,
    String? title,
    String? messageEn,
    String? messageBn,
    String? timezone,
    String? rrule,
    List<String>? timesJson,
    int? intervalMinutes,
    DateTime? startDate,
    DateTime? endDate,
    bool? active,
    int? snoozeMinutes,
    Map<String, dynamic>? metaJson,
  }) {
    return Reminder(
      id: id,
      userId: userId,
      type: type ?? this.type,
      title: title ?? this.title,
      messageEn: messageEn ?? this.messageEn,
      messageBn: messageBn ?? this.messageBn,
      timezone: timezone ?? this.timezone,
      rrule: rrule ?? this.rrule,
      timesJson: timesJson ?? this.timesJson,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      active: active ?? this.active,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      metaJson: metaJson ?? this.metaJson,
      lastEnqueuedAt: lastEnqueuedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

enum ReminderEventStatus {
  scheduled,
  sent,
  delivered,
  ack,
  skipped,
  error;

  static ReminderEventStatus fromApi(String v) {
    switch (v.toUpperCase()) {
      case 'SCHEDULED':
        return ReminderEventStatus.scheduled;
      case 'SENT':
        return ReminderEventStatus.sent;
      case 'DELIVERED':
        return ReminderEventStatus.delivered;
      case 'ACK':
        return ReminderEventStatus.ack;
      case 'SKIPPED':
        return ReminderEventStatus.skipped;
      case 'ERROR':
      default:
        return ReminderEventStatus.error;
    }
  }
}

class ReminderEvent {
  final int id;
  final int reminderId;
  final DateTime scheduledAt;
  final ReminderEventStatus status;
  final int attempt;
  final Map<String, dynamic>? payloadJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReminderEvent({
    required this.id,
    required this.reminderId,
    required this.scheduledAt,
    required this.status,
    required this.attempt,
    required this.createdAt,
    required this.updatedAt,
    this.payloadJson,
  });

  factory ReminderEvent.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsePayload(dynamic v) {
      if (v == null) return null;
      if (v is Map<String, dynamic>) return v;
      if (v is String && v.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(v);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {}
      }
      return null;
    }

    return ReminderEvent(
      id: (json['id'] as num).toInt(),
      reminderId: (json['reminder_id'] as num).toInt(),
      scheduledAt: DateTime.parse(json['scheduled_at']),
      status: ReminderEventStatus.fromApi(json['status'] ?? 'ERROR'),
      attempt: json['attempt'] == null ? 0 : (json['attempt'] as num).toInt(),
      payloadJson: parsePayload(json['payload_json']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
