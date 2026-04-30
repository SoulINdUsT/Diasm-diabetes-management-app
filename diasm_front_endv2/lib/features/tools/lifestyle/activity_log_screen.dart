
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:diasm_front_endv2/core/api_client.dart';
import 'package:diasm_front_endv2/core/auth_storage.dart';

class ActivityLogScreen extends StatefulWidget {
  static const routeName = '/tools/lifestyle/activity/log';

  final bool isEnglish;
  const ActivityLogScreen({super.key, required this.isEnglish});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final _formKey = GlobalKey<FormState>();

  final _minutesController = TextEditingController();
  final _distanceController = TextEditingController();
  final _kcalController = TextEditingController();
  final _notesController = TextEditingController();

  final ApiClient _api = ApiClient();
  final AuthStorage _auth = AuthStorage();

  bool _saving = false;

  @override
  void dispose() {
    _minutesController.dispose();
    _distanceController.dispose();
    _kcalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<int> _resolveUserId() async {
    final id = await _auth.getUserId();
    if (id != null) return id;
    return 1;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final isEn = widget.isEnglish;

    try {
      final userId = await _resolveUserId();
      final now = DateTime.now().toIso8601String(); // BD local timestamp

      final minutes = double.parse(_minutesController.text.trim());

      final distanceKm = _distanceController.text.trim().isEmpty
          ? null
          : double.parse(_distanceController.text.trim());

      final kcal = _kcalController.text.trim().isEmpty
          ? null
          : double.parse(_kcalController.text.trim());

      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      await _api.dio.post(
        '/lifestyle/activity/event',
        data: {
          'user_id': userId,
          'event_type': 'workout',
          'minutes': minutes,
          'distance_km': distanceKm,
          'kcal': kcal,
          'source': 'manual',
          'event_at': now, // FIXED TIMESTAMP
          'notes': notes,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn ? 'Activity saved.' : 'কর্মকাণ্ড সেভ হয়েছে।',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn
                ? 'Could not save activity. Please try again.'
                : 'কর্মকাণ্ড সেভ করা যায়নি, আবার চেষ্টা করুন।',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Log Activity' : 'কর্মকাণ্ড লিখুন'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: _buildWorkoutForm(isEn),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _submit,
        icon: _saving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(isEn ? 'Save' : 'সেভ করুন'),
      ),
    );
  }

  // ---------------------------------------------------------------
  // WORKOUT FORM (only form now)
  // ---------------------------------------------------------------
  Widget _buildWorkoutForm(bool isEn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEn ? 'Activity / workout today' : 'আজকের কার্যকলাপ / ব্যায়াম',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _minutesController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: isEn ? 'Active minutes' : 'সক্রিয় মিনিট',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return isEn ? 'Enter minutes' : 'মিনিট লিখুন';
            }
            if (double.tryParse(value.trim()) == null) {
              return isEn ? 'Enter a valid number' : 'শুধু সংখ্যা দিন';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _distanceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText:
                isEn ? 'Distance (km, optional)' : 'দূরত্ব (কিমি, ঐচ্ছিক)',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value != null &&
                value.trim().isNotEmpty &&
                double.tryParse(value.trim()) == null) {
              return isEn ? 'Number only' : 'শুধু সংখ্যা দিন';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _kcalController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText:
                isEn ? 'Calories burned (optional)' : 'ক্যালরি (ঐচ্ছিক)',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value != null &&
                value.trim().isNotEmpty &&
                double.tryParse(value.trim()) == null) {
              return isEn ? 'Number only' : 'শুধু সংখ্যা দিন';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: isEn ? 'Notes (optional)' : 'নোট (ঐচ্ছিক)',
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
