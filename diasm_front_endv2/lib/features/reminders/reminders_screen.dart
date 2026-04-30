import 'package:flutter/material.dart';

import '../../core/reminder_models.dart';
import '../../core/reminder_repository.dart';
import '../../core/notification_service.dart'; // ✅ NEW
import 'reminder_form_screen.dart';
import '../../core/reminder_scheduler.dart';


class RemindersScreen extends StatefulWidget {
  static const routeName = "/reminders";

  final bool isEnglish;
  const RemindersScreen({super.key, required this.isEnglish});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _repo = ReminderRepository.fromClient();

  ReminderType? _filterType; // null = all
  bool? _filterActive; // null = all

  late Future<List<Reminder>> _future;

  // ---------- COLOR PALETTE (medium–hard pastels by type) ----------
  static const Color _medicationBg = Color(0xFFE4C3FF); // purple
  static const Color _hydrationBg = Color(0xFFBED9FF); // blue
  static const Color _hba1cBg = Color(0xFFF8CF9E); // orange
  static const Color _bpBg = Color(0xFFF7B9B9); // soft red
  static const Color _customBg = Color(0xFFE1E5F0); // grey-blue

  Color _typeBackground(ReminderType t) {
    switch (t) {
      case ReminderType.medication:
        return _medicationBg;
      case ReminderType.hydration:
        return _hydrationBg;
      case ReminderType.hba1c:
        return _hba1cBg;
      case ReminderType.bp:
        return _bpBg;
      case ReminderType.custom:
      default:
        return _customBg;
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Reminder>> _load() {
    return _repo.getReminders(type: _filterType, active: _filterActive);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  String _typeLabel(ReminderType t) =>
      widget.isEnglish ? t.labelEn() : t.labelBn();

  //  medical icon mapping
  IconData _typeIcon(ReminderType t) {
    switch (t) {
      case ReminderType.medication:
        return Icons.medication_liquid_rounded;
      case ReminderType.hydration:
        return Icons.water_drop_rounded;
      case ReminderType.hba1c:
        return Icons.biotech_rounded;
      case ReminderType.bp:
        return Icons.monitor_heart_rounded;
      case ReminderType.custom:
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,


      appBar: AppBar(
        title: Text(widget.isEnglish ? "Reminders" : "রিমাইন্ডার"),
        actions: [
          // ✅ TEMP: test notification button
          IconButton(
            tooltip: widget.isEnglish
                ? "Test notification"
                : "টেস্ট নোটিফিকেশন",
            icon: const Icon(Icons.notifications),
            onPressed: () {
              NotificationService.showTestNotification();
            },
          ),
          PopupMenuButton<bool?>(
            onSelected: (v) {
              setState(() => _filterActive = v);
              _refresh();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: null,
                child: Text(widget.isEnglish ? "All" : "সব"),
              ),
              PopupMenuItem(
                value: true,
                child: Text(widget.isEnglish ? "Active" : "চালু"),
              ),
              PopupMenuItem(
                value: false,
                child: Text(widget.isEnglish ? "Inactive" : "বন্ধ"),
              ),
            ],
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTypeChips(),
          Expanded(
            child: FutureBuilder<List<Reminder>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      "${widget.isEnglish ? "Error" : "সমস্যা"}: ${snap.error}",
                    ),
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      widget.isEnglish
                          ? "No reminders yet."
                          : "এখনও কোনো রিমাইন্ডার নেই।",
                      style: TextStyle(
                        fontSize: 14.5,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final r = items[i];

                      return Card(
                        color: _typeBackground(r.type),
                        elevation: 1.8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _typeIcon(r.type),
                              color: Theme.of(context).colorScheme.primary,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            r.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15.5,
                            ),
                          ),
                          subtitle: Text(
                            _buildSubtitle(r),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: r.active ? Colors.black87 : Colors.black54,
                              fontStyle: r.active
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                          trailing: Switch(
  value: r.active,
  onChanged: (val) async {
    try {
      final updated = await _repo.toggleActive(r.id);

      await ReminderScheduler.rescheduleForReminder(
        updated,
        isEnglish: widget.isEnglish,
      );

      _refresh();
    } catch (_) {}
  },
),

                          onTap: () => _openEdit(r),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        label: Text(widget.isEnglish ? "Add Reminder" : "রিমাইন্ডার যোগ করুন"),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTypeChips() {
    final types = ReminderType.values;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(widget.isEnglish ? "All" : "সব"),
            selected: _filterType == null,
            onSelected: (_) {
              setState(() => _filterType = null);
              _refresh();
            },
          ),
          const SizedBox(width: 8),
          ...types.map((t) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(_typeLabel(t)),
                selected: _filterType == t,
                onSelected: (_) {
                  setState(() => _filterType = t);
                  _refresh();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  String _buildSubtitle(Reminder r) {
    final sched = (r.timesJson != null && r.timesJson!.isNotEmpty)
        ? (widget.isEnglish
            ? "Times: ${r.timesJson!.join(", ")}"
            : "সময়: ${r.timesJson!.join(", ")}")
        : (r.intervalMinutes != null
            ? (widget.isEnglish
                ? "Every ${r.intervalMinutes} min"
                : "প্রতি ${r.intervalMinutes} মিনিটে")
            : (r.rrule != null && r.rrule!.isNotEmpty
                ? (widget.isEnglish ? "Rule: ${r.rrule}" : "রুল: ${r.rrule}")
                : (widget.isEnglish ? "No schedule" : "কোনো শিডিউল নেই")));

    final activeTxt = r.active
        ? (widget.isEnglish ? "Active" : "চালু")
        : (widget.isEnglish ? "Inactive" : "বন্ধ");

    return "$activeTxt • $sched";
  }

  Future<void> _openCreate() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderFormScreen(isEnglish: widget.isEnglish),
      ),
    );
    if (ok == true) _refresh();
  }

  Future<void> _openEdit(Reminder r) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ReminderFormScreen(isEnglish: widget.isEnglish, existing: r),
      ),
    );
    if (ok == true) _refresh();
  }
}
