import 'package:flutter/material.dart';
import 'package:diasm_front_endv2/core/lifestyle_repository.dart';

class HydrationLogScreen extends StatefulWidget {
  const HydrationLogScreen({super.key});

  @override
  State<HydrationLogScreen> createState() => _HydrationLogScreenState();
}

class _HydrationLogScreenState extends State<HydrationLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _volumeController = TextEditingController();
  final LifestyleRepository _repo = LifestyleRepository();

  bool _saving = false;

  @override
  void dispose() {
    _volumeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final volume = int.tryParse(_volumeController.text.trim());
    if (volume == null || volume <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid volume.')),
      );
      return;
    }

    setState(() => _saving = true);

    final ok = await _repo.logHydration(volume);

    if (!mounted) return;

    setState(() => _saving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Water intake saved.')),
      );
      // VERY IMPORTANT: this tells LifestyleSnapshotScreen to refresh
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to log hydration')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Water Intake'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _volumeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Volume (ml)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  final v = int.tryParse(value.trim());
                  if (v == null || v <= 0) {
                    return 'Enter a positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
