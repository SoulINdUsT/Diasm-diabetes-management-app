
import 'package:dio/dio.dart';
import 'reminder_models.dart';
import 'api_client.dart';

class ReminderRepository {
  final Dio _dio;

  ReminderRepository(this._dio);

  factory ReminderRepository.fromClient() {
    // Match your other repositories’ pattern
    return ReminderRepository(ApiClient().dio);
  }

  Future<List<Reminder>> getReminders({
    ReminderType? type,
    bool? active,
  }) async {
    final params = <String, dynamic>{};
    if (type != null) params['type'] = type.toApi();
    if (active != null) params['active'] = active ? 1 : 0;

    // ✅ FIXED: removed /api/v1 prefix
    final res = await _dio.get('/reminders', queryParameters: params);
    final data = res.data;

    final list = (data is List) ? data : (data['data'] ?? data['items'] ?? []);
    return (list as List)
        .map((e) => Reminder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Reminder> getReminder(int id) async {
    // ✅ FIXED: removed /api/v1 prefix
    final res = await _dio.get('/reminders/$id');
    final data = res.data is Map ? res.data['data'] ?? res.data : res.data;
    return Reminder.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Reminder> createReminder(Reminder r) async {
    // ✅ Ensure backend-required fields exist even if user fills only one message field
    final payload = _buildCreateUpdatePayload(r);

    final res = await _dio.post('/reminders', data: payload);
    final data = res.data is Map ? res.data['data'] ?? res.data : res.data;
    return Reminder.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Reminder> updateReminder(int id, Reminder r) async {
    // ✅ Same rule for update
    final payload = _buildCreateUpdatePayload(r);

    final res = await _dio.put('/reminders/$id', data: payload);
    final data = res.data is Map ? res.data['data'] ?? res.data : res.data;
    return Reminder.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> deleteReminder(int id) async {
    // ✅ FIXED: removed /api/v1 prefix
    await _dio.delete('/reminders/$id');
  }

  Future<Reminder> toggleActive(int id) async {
    // ✅ FIXED: removed /api/v1 prefix
    final res = await _dio.post('/reminders/$id/toggle');
    final data = res.data is Map ? res.data['data'] ?? res.data : res.data;
    return Reminder.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Reminder> snooze(int id, int minutes) async {
    // ✅ FIXED: removed /api/v1 prefix
    final res = await _dio.post(
      '/reminders/$id/snooze',
      data: {"minutes": minutes},
    );
    final data = res.data is Map ? res.data['data'] ?? res.data : res.data;
    return Reminder.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<ReminderEvent>> getEvents(
    int reminderId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = _fmtDate(from);
    if (to != null) params['to'] = _fmtDate(to);

    // ✅ FIXED: removed /api/v1 prefix
    final res = await _dio.get(
      '/reminders/$reminderId/events',
      queryParameters: params,
    );
    final data = res.data;

    final list = (data is List) ? data : (data['data'] ?? data['items'] ?? []);
    return (list as List)
        .map((e) => ReminderEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Build payload for create/update that satisfies backend validation:
  /// title, timezone, message_en, message_bn are required.
  ///
  /// If user fills only one message field, we copy it to the other.
  /// If both are empty, we fall back to title.
  Map<String, dynamic> _buildCreateUpdatePayload(Reminder r) {
    final raw = r.toJsonForCreateOrUpdate();

    final title = (raw['title'] ?? '').toString().trim();

    final msgEn = (raw['message_en'] ?? '').toString().trim();
    final msgBn = (raw['message_bn'] ?? '').toString().trim();

    final fallback = msgEn.isNotEmpty
        ? msgEn
        : (msgBn.isNotEmpty ? msgBn : title);

    raw['timezone'] = (raw['timezone'] ?? 'Asia/Dhaka').toString().trim();
    raw['message_en'] = msgEn.isNotEmpty ? msgEn : fallback;
    raw['message_bn'] = msgBn.isNotEmpty ? msgBn : fallback;

    return raw;
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
