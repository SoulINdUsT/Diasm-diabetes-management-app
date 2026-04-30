
// lib/features/profile/profile_screen.dart
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'package:diasm_front_endv2/core/auth_repository.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';

  final bool isEnglish;

  const ProfileScreen({
    super.key,
    this.isEnglish = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authRepository = AuthRepository();

  final _nameController = TextEditingController();
  final _dobController = TextEditingController();

  String? _sex; // 'male' | 'female' | 'other'
  String? _diabetesType; // 'none' | 'type1' | 'type2' | ...
  String? _location; // 'urban' | 'rural'

  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await _authRepository.getProfile();

      // normalize backend values (prevents dropdown crash on "unknown"/bad values)
      String? norm(String? v) {
        final s = (v ?? '').trim().toLowerCase();
        if (s.isEmpty || s == 'unknown' || s == 'null') return null;
        return s;
      }

      const allowedSex = {'male', 'female', 'other'};
      const allowedLocation = {'urban', 'rural'};
      const allowedDiabetes = {
        'none',
        'type1',
        'type2',
        'prediabetes',
        'gestational',
        'other',
      };

      setState(() {
        _nameController.text = (profile['name'] ?? '').toString();

        final dob = profile['dob']?.toString();
        if (dob != null && dob.isNotEmpty && dob.length >= 10) {
          _dobController.text = dob.substring(0, 10); // YYYY-MM-DD
        } else {
          _dobController.text = '';
        }

        final sex = norm(profile['sex']?.toString());
        final location = norm(profile['location']?.toString());
        final diabetes = norm(profile['diabetes_type']?.toString());

        _sex = (sex != null && allowedSex.contains(sex)) ? sex : null;
        _location =
            (location != null && allowedLocation.contains(location))
                ? location
                : null;

        // Diabetes: safe default so dropdown always has a matching item
        _diabetesType =
            (diabetes != null && allowedDiabetes.contains(diabetes))
                ? diabetes
                : 'none';
      });
    } catch (_) {
      // ignore errors here, just show empty form
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dobController.text) ??
        DateTime(DateTime.now().year - 30, 1, 1);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _dobController.text =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      String? diabetesTypeCode = _diabetesType;
      if (diabetesTypeCode == null || diabetesTypeCode.isEmpty) {
        diabetesTypeCode = 'none';
      }

      await _authRepository.updateProfile(
        name: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        dob: _dobController.text.trim().isEmpty
            ? null
            : _dobController.text.trim(),
        sex: _sex,
        location: _location,
        diabetesType: diabetesTypeCode,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEnglish
                ? 'Profile updated successfully.'
                : 'প্রোফাইল আপডেট হয়েছে।',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEnglish
                ? 'Failed to update profile. Please try again.'
                : 'প্রোফাইল আপডেট করতে সমস্যা হয়েছে।',
          ),
          behavior: SnackBarBehavior.floating,
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
    final t = widget.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(t ? 'Profile' : 'প্রোফাইল'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    _buildHeaderCard(t),
                    const SizedBox(height: 16),
                    _buildFormCard(t),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderCard(bool t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primaryDark,
            child: const Icon(
              Icons.person,
              color: AppColors.background,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t ? 'Your profile' : 'আপনার প্রোফাইল',
                  style: AppTextStyles.title.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t
                      ? 'Keep this information updated for better tips.'
                      : 'ভাল পরামর্শ পেতে তথ্যগুলো আপডেট রাখুন।',
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(bool t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t ? 'Basic information' : 'মূল তথ্য',
              style: AppTextStyles.title,
            ),
            const SizedBox(height: 12),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t ? 'Name' : 'নাম',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t ? 'Please enter your name' : 'অনুগ্রহ করে নাম লিখুন';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // DOB
            TextFormField(
              controller: _dobController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: t ? 'Date of birth (YYYY-MM-DD)' : 'জন্মতারিখ',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today_outlined, size: 20),
                  onPressed: _pickDate,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              t ? 'Health profile' : 'স্বাস্থ্য প্রোফাইল',
              style: AppTextStyles.title,
            ),
            const SizedBox(height: 12),

            // Sex
            _buildDropdown<String>(
              label: t ? 'Sex' : 'লিঙ্গ',
              value: _sex,
              items: [
                DropdownMenuItem(
                  value: 'male',
                  child: Text(t ? 'Male' : 'পুরুষ'),
                ),
                DropdownMenuItem(
                  value: 'female',
                  child: Text(t ? 'Female' : 'মহিলা'),
                ),
                DropdownMenuItem(
                  value: 'other',
                  child: Text(t ? 'Other' : 'অন্যান্য'),
                ),
              ],
              onChanged: (val) => setState(() => _sex = val),
            ),
            const SizedBox(height: 12),

            // Diabetes type
            _buildDropdown<String>(
              label: t
                  ? 'Diabetes type (optional)'
                  : 'ডায়াবেটিসের ধরন (ঐচ্ছিক)',
              value: _diabetesType ?? 'none',
              items: [
                DropdownMenuItem(
                  value: 'none',
                  child: Text(
                    t
                        ? 'Not sure / will set later'
                        : 'নিশ্চিত নই / পরে সেট করব',
                  ),
                ),
                DropdownMenuItem(
                  value: 'type2',
                  child: Text(t ? 'Type 2' : 'টাইপ ২'),
                ),
                DropdownMenuItem(
                  value: 'type1',
                  child: Text(t ? 'Type 1' : 'টাইপ ১'),
                ),
                DropdownMenuItem(
                  value: 'prediabetes',
                  child: Text(t ? 'Prediabetes' : 'প্রিডায়াবেটিস'),
                ),
                DropdownMenuItem(
                  value: 'gestational',
                  child:
                      Text(t ? 'Gestational (pregnancy)' : 'গর্ভকালীন ডায়াবেটিস'),
                ),
                DropdownMenuItem(
                  value: 'other',
                  child: Text(t ? 'Other' : 'অন্যান্য'),
                ),
              ],
              onChanged: (val) => setState(() => _diabetesType = val),
            ),
            const SizedBox(height: 12),

            // Location
            _buildDropdown<String>(
              label: t ? 'Location' : 'অবস্থান',
              value: _location,
              items: [
                DropdownMenuItem(
                  value: 'urban',
                  child: Text(t ? 'Urban' : 'শহর'),
                ),
                DropdownMenuItem(
                  value: 'rural',
                  child: Text(t ? 'Rural' : 'গ্রাম'),
                ),
              ],
              onChanged: (val) => setState(() => _location = val),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        t ? 'Save' : 'সেভ করুন',
                        style: AppTextStyles.button,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}
