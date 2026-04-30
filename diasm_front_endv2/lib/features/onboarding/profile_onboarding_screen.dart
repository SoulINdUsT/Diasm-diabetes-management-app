
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:diasm_front_endv2/core/auth_repository.dart';

class ProfileOnboardingScreen extends StatefulWidget {
  const ProfileOnboardingScreen({super.key});

  @override
  State<ProfileOnboardingScreen> createState() =>
      _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen> {
  final _authRepository = AuthRepository();

  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Form keys per step for fine-grained validation
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  // Controllers / state
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime? _dob;
  String _sex = 'male';
  String _diabetesType = 'type2';

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  int get _totalSteps => 3;

  double get _progress => (_currentStep + 1) / _totalSteps;

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 30, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobController.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
    });
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleNext() async {
    // Validate current step before moving forward or submitting.
    switch (_currentStep) {
      case 0:
        if (_step1Key.currentState?.validate() != true) return;
        _goToStep(1);
        break;
      case 1:
        if (_step2Key.currentState?.validate() != true) return;
        _goToStep(2);
        break;
      case 2:
        if (_step3Key.currentState?.validate() != true) return;
        await _submit();
        break;
    }
  }

  void _handleBack() {
    if (_currentStep == 0) return;
    _goToStep(_currentStep - 1);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final dobString = _dob != null
          ? _dob!.toIso8601String().split('T').first
          : _dobController.text.trim();

      await _authRepository.updateProfile(
        name: _nameController.text.trim(),
        dob: dobString,
        sex: _sex,
        location: _locationController.text.trim(),
        //diabetesType: _diabetesType,
      );

      if (!mounted) return;

      // Backend sets profileCompleted = true for this user.
      // Navigate to home.
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save profile. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildStepHeader() {
    final titles = [
      'Basic info',
      'Diabetes profile',
      'Location & review',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(_totalSteps, (index) {
            final isActive = index == _currentStep;
            final isCompleted = index < _currentStep;

            Color bg;
            Color fg;

            if (isActive) {
              bg = Theme.of(context).colorScheme.primary;
              fg = Theme.of(context).colorScheme.onPrimary;
            } else if (isCompleted) {
              bg = Theme.of(context).colorScheme.primary.withOpacity(0.15);
              fg = Theme.of(context).colorScheme.primary;
            } else {
              bg = Theme.of(context).colorScheme.surfaceVariant;
              fg = Theme.of(context).colorScheme.onSurfaceVariant;
            }

            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: index == _totalSteps - 1 ? 0 : 8,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        titles[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                          color: fg,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tell us about you',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'We use this information to personalize your DIAsm experience.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Name
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              if (value.trim().length < 2) {
                return 'Name seems too short';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // DOB
          GestureDetector(
            onTap: _pickDob,
            child: AbsorbPointer(
              child: TextFormField(
                controller: _dobController,
                decoration: const InputDecoration(
                  labelText: 'Date of birth',
                  hintText: 'Tap to select',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please select your date of birth';
                  }
                  return null;
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sex
          const Text(
            'Sex',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildChoiceChip(
                label: 'Male',
                value: 'male',
                groupValue: _sex,
                onChanged: (val) {
                  setState(() {
                    _sex = val;
                  });
                },
              ),
              _buildChoiceChip(
                label: 'Female',
                value: 'female',
                groupValue: _sex,
                onChanged: (val) {
                  setState(() {
                    _sex = val;
                  });
                },
              ),
              _buildChoiceChip(
                label: 'Other',
                value: 'other',
                groupValue: _sex,
                onChanged: (val) {
                  setState(() {
                    _sex = val;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your diabetes profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'This helps us tailor goals, reminders, and education for your needs.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 20),

          const Text(
            'What type of diabetes have you been diagnosed with?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),

          Column(
            children: [
              _buildRadioCard(
                title: 'Type 2 diabetes',
                description:
                    'Most common in adults, often linked with weight and lifestyle factors.',
                value: 'type2',
                groupValue: _diabetesType,
                onChanged: (val) {
                  setState(() {
                    _diabetesType = val;
                  });
                },
              ),
              const SizedBox(height: 10),
              _buildRadioCard(
                title: 'Type 1 diabetes',
                description:
                    'Usually diagnosed earlier in life, requires insulin from diagnosis.',
                value: 'type1',
                groupValue: _diabetesType,
                onChanged: (val) {
                  setState(() {
                    _diabetesType = val;
                  });
                },
              ),
              const SizedBox(height: 10),
              _buildRadioCard(
                title: 'Gestational diabetes',
                description:
                    'Diabetes diagnosed during pregnancy (current or past).',
                value: 'gestational',
                groupValue: _diabetesType,
                onChanged: (val) {
                  setState(() {
                    _diabetesType = val;
                  });
                },
              ),
              const SizedBox(height: 10),
              _buildRadioCard(
                title: 'Other / not sure',
                description:
                    'If you are not sure or have another form, choose this for now.',
                value: 'other',
                groupValue: _diabetesType,
                onChanged: (val) {
                  setState(() {
                    _diabetesType = val;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Form(
      key: _step3Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where do you live?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'We use your location to adapt education and lifestyle tips.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'City / area, country',
              hintText: 'e.g. Dhaka, Bangladesh',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your location';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          const Text(
            'Review your information',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          _buildSummaryRow('Name', _nameController.text.trim()),
          _buildSummaryRow('Date of birth', _dobController.text.trim()),
          _buildSummaryRow(
            'Sex',
            _sex == 'male'
                ? 'Male'
                : _sex == 'female'
                    ? 'Female'
                    : 'Other',
          ),
          _buildSummaryRow(
            'Diabetes type',
            _diabetesType == 'type2'
                ? 'Type 2'
                : _diabetesType == 'type1'
                    ? 'Type 1'
                    : _diabetesType == 'gestational'
                        ? 'Gestational'
                        : 'Other / not sure',
          ),
          _buildSummaryRow('Location', _locationController.text.trim()),
          const SizedBox(height: 8),
          const Text(
            'You can update these later from your profile screen as well.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    final effective = value.isEmpty ? 'Not set yet' : value;
    final isMissing = value.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              effective,
              style: TextStyle(
                fontSize: 13,
                color: isMissing
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required String value,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    final selected = value == groupValue;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(value),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildRadioCard({
    required String title,
    required String description,
    required String value,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    final isSelected = value == groupValue;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 1.4 : 1,
          ),
          color: isSelected
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.04)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLastStep = _currentStep == _totalSteps - 1;

    return SafeArea(
      top: false,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : _handleBack,
                  child: const Text('Back'),
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleNext,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isLastStep ? 'Finish' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Set up your profile'),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () {
            // Skip profile setup and go to home
            context.go('/home');
          },
          child: const Text(
            'Skip',
            style: TextStyle(
              color: Colors.white, // or Theme.of(context).colorScheme.onPrimary
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: _buildStepHeader(),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SingleChildScrollView(
                  child: _buildStep1(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SingleChildScrollView(
                  child: _buildStep2(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SingleChildScrollView(
                  child: _buildStep3(),
                ),
              ),
            ],
          ),
        ),
        _buildBottomBar(),
      ],
    ),
  );
}
}