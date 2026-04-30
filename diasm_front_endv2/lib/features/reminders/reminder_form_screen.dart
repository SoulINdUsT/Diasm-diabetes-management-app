import 'package:flutter/material.dart';

import '../../core/reminder_models.dart';
import '../../core/reminder_repository.dart';
import '../../core/notification_service.dart'; // ✅ NEW
import '../../core/reminder_scheduler.dart';
//import '../../core/reminder_scheduler.dart';



class ReminderFormScreen extends StatefulWidget {
  final bool isEnglish;
  final Reminder? existing;

  const ReminderFormScreen({
    super.key,
    required this.isEnglish,
    this.existing,
  });

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _repo = ReminderRepository.fromClient();
  final _formKey = GlobalKey<FormState>();

  late ReminderType _type;
  late TextEditingController _title;
  late TextEditingController _msgEn;
  late TextEditingController _msgBn;
  late TextEditingController _rrule;
  late TextEditingController _interval;

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String _timezone = "Asia/Dhaka";
  bool _active = true;
  int _snoozeMinutes = 0;
  final List<String> _times = [];

  // meta_json
  final _metaDose = TextEditingController();
  final _metaContext = TextEditingController();

  bool _saving = false;

  String t(String en, String bn) => widget.isEnglish ? en : bn;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;

    _type = ex?.type ?? ReminderType.medication;
    _title = TextEditingController(text: ex?.title ?? "");
    _msgEn = TextEditingController(text: ex?.messageEn ?? "");
    _msgBn = TextEditingController(text: ex?.messageBn ?? "");
    _rrule = TextEditingController(text: ex?.rrule ?? "");
    _interval =
        TextEditingController(text: ex?.intervalMinutes?.toString() ?? "");

    _startDate = ex?.startDate ?? DateTime.now();
    _endDate = ex?.endDate;
    _timezone = ex?.timezone ?? "Asia/Dhaka";
    _active = ex?.active ?? true;
    _snoozeMinutes = ex?.snoozeMinutes ?? 0;
    _times.addAll(ex?.timesJson ?? []);

    final meta = ex?.metaJson ?? {};
    _metaDose.text = (meta['dose'] ?? "").toString();
    _metaContext.text = (meta['context'] ?? "").toString();
  }

  @override
  void dispose() {
    _title.dispose();
    _msgEn.dispose();
    _msgBn.dispose();
    _rrule.dispose();
    _interval.dispose();
    _metaDose.dispose();
    _metaContext.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? t("Edit Reminder", "রিমাইন্ডার এডিট")
            : t("Add Reminder", "রিমাইন্ডার যোগ করুন")),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _deleteReminder,
            )
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _buildTypeDropdown(),
              const SizedBox(height: 10),

              TextFormField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: t("Title", "টাইটেল"),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? t("Required", "প্রয়োজন") : null,
              ),

              const SizedBox(height: 10),

              // Message EN
              TextFormField(
                controller: _msgEn,
                decoration: InputDecoration(
                  labelText: t("Message (BN)", "মেসেজ (BN)"),
                  hintText: t(
                    "Example: Time to take your medicine.",
                    "উদাহরণ: ওষুধ খাওয়ার সময় হয়েছে।",
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final en = v?.trim() ?? "";
                  final bn = _msgBn.text.trim();
                  if (en.isEmpty && bn.isEmpty) return t("Required", "প্রয়োজন");
                  return null;
                },
              ),

              const SizedBox(height: 10),

              // Message BN
              TextFormField(
                controller: _msgBn,
                decoration: InputDecoration(
                  labelText: t("Message (EN)", "মেসেজ (EN)"),
                  hintText: t(
                    "Example: Drink a glass of water.",
                    "উদাহরণ: এক গ্লাস পানি পান করুন।",
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final bn = v?.trim() ?? "";
                  final en = _msgEn.text.trim();
                  if (bn.isEmpty && en.isEmpty) return t("Required", "প্রয়োজন");
                  return null;
                },
              ),

              const SizedBox(height: 12),
              _buildScheduleBlock(),
              const SizedBox(height: 12),
              _buildDatePickers(),
              const SizedBox(height: 12),
              _buildMetaBlock(),
              const SizedBox(height: 12),

              SwitchListTile(
                title: Text(t("Active", "চালু")),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: _save,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving
                    ? t("Saving...", "সেভ হচ্ছে...")
                    : t("Save Reminder", "সেভ করুন")),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<ReminderType>(
      initialValue: _type,
      decoration: InputDecoration(
        labelText: t("Type", "ধরন"),
        border: const OutlineInputBorder(),
      ),
      items: ReminderType.values
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(t(e.labelEn(), e.labelBn())),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _type = v;
          if (_type != ReminderType.medication) _metaDose.clear();
        });
        FocusScope.of(context).unfocus();
      },
    );
  }

  Widget _buildScheduleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t("Schedule", "শিডিউল"),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),

        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: -6,
                children: _times
                    .map((time) => Chip(
                          label: Text(time),
                          onDeleted: () {
                            setState(() => _times.remove(time));
                          },
                        ))
                    .toList(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.access_time),
              onPressed: _addTime,
              tooltip: t("Add time", "সময় যোগ করুন"),
            )
          ],
        ),

        const SizedBox(height: 8),

        TextFormField(
          controller: _interval,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: t("Interval minutes (optional)", "ইন্টারভাল মিনিট (ঐচ্ছিক)"),
            border: const OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 8),

        TextFormField(
          controller: _rrule,
          decoration: InputDecoration(
            labelText: t("RRULE (optional)", "RRULE (ঐচ্ছিক)"),
            border: const OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 6),
        Text(
          t(
            "At least one schedule is required: times OR interval OR rrule.",
            "কমপক্ষে একটি শিডিউল দিতে হবে: সময় অথবা ইন্টারভাল অথবা rrule।",
          ),
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDatePickers() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: _startDate,
              );
              if (d != null) setState(() => _startDate = d);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: t("Start date", "শুরু তারিখ"),
                border: const OutlineInputBorder(),
              ),
              child: Text(_fmtDate(_startDate)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: _endDate ?? _startDate,
              );
              setState(() => _endDate = d);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: t("End date (optional)", "শেষ তারিখ (ঐচ্ছিক)"),
                border: const OutlineInputBorder(),
              ),
              child: Text(_endDate == null ? "-" : _fmtDate(_endDate!)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t("Extra info (meta)", "অতিরিক্ত তথ্য (meta)"),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),

        if (_type == ReminderType.medication)
          TextFormField(
            controller: _metaDose,
            decoration: InputDecoration(
              labelText: t("Dose (optional)", "ডোজ (ঐচ্ছিক)"),
              border: const OutlineInputBorder(),
            ),
          ),

        const SizedBox(height: 8),

        TextFormField(
          controller: _metaContext,
          decoration: InputDecoration(
            labelText: t("Context / note (optional)", "কনটেক্সট / নোট (ঐচ্ছিক)"),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    final val = "$hh:$mm";
    if (_times.contains(val)) return;
    setState(() => _times.add(val));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Backend schedule validation
    final intervalVal = int.tryParse(_interval.text.trim());
    final hasTimes = _times.isNotEmpty;
    final hasInterval = intervalVal != null && intervalVal > 0;
    final hasRrule = _rrule.text.trim().isNotEmpty;

    if (!hasTimes && !hasInterval && !hasRrule) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t("Please add a schedule.", "একটি শিডিউল দিন।"))),
      );
      return;
    }

    // ✅ Auto-fill missing message field
    var messageEn = _msgEn.text.trim();
    var messageBn = _msgBn.text.trim();
    if (messageEn.isEmpty && messageBn.isNotEmpty) messageEn = messageBn;
    if (messageBn.isEmpty && messageEn.isNotEmpty) messageBn = messageEn;

    setState(() => _saving = true);

      try {
      final meta = <String, dynamic>{};
      if (_metaDose.text.trim().isNotEmpty) meta['dose'] = _metaDose.text.trim();
      if (_metaContext.text.trim().isNotEmpty) {
        meta['context'] = _metaContext.text.trim();
      }

      final base = widget.existing;

      final reminder = (base ??
              Reminder(
                id: 0,
                userId: 0, // backend uses token user
                type: _type,
                title: _title.text.trim(),
                messageEn: messageEn,
                messageBn: messageBn,
                timezone: _timezone,
                startDate: _startDate,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ))
          .copyWith(
        type: _type,
        title: _title.text.trim(),
        messageEn: messageEn,
        messageBn: messageBn,
        timezone: _timezone,
        startDate: _startDate,
        endDate: _endDate,
        active: _active,
        snoozeMinutes: _snoozeMinutes,
        timesJson: hasTimes ? List<String>.from(_times) : null,
        intervalMinutes: hasInterval ? intervalVal : null,
        rrule: hasRrule ? _rrule.text.trim() : null,
        metaJson: meta.isEmpty ? null : meta,
      );

      // Save to backend and get the real saved reminder (with real id)
            Reminder saved;
      if (widget.existing == null) {
        saved = await _repo.createReminder(reminder);
      } else {
        saved = await _repo.updateReminder(widget.existing!.id, reminder);
      }

      // Try to schedule notifications, but don't fail the save if it breaks
      try {
        await ReminderScheduler.rescheduleForReminder(
          saved,
          isEnglish: widget.isEnglish,
        );
      } catch (_) {
        // for now we ignore notification errors, reminder is still saved
      }

      if (!mounted) return;
      Navigator.pop(context, true);


    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${t("Save failed", "সেভ হয়নি")}: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteReminder() async {
    final ex = widget.existing!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t("Delete reminder?", "রিমাইন্ডার ডিলিট করবেন?")),
        content: Text(ex.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t("Cancel", "বাতিল")),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t("Delete", "ডিলিট")),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      await _repo.deleteReminder(ex.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${t("Delete failed", "ডিলিট হয়নি")}: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
