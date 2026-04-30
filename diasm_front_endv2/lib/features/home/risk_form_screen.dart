import 'package:flutter/material.dart';

//import '../../core/risk_models.dart';
import '../../core/risk_submission_model.dart';
import '../../core/risk_repository.dart';

class RiskFormScreen extends StatefulWidget {
  const RiskFormScreen({super.key});

  @override
  State<RiskFormScreen> createState() => _RiskFormScreenState();
}

class _RiskFormScreenState extends State<RiskFormScreen> {
  final RiskRepository _repository = RiskRepository();

  bool _isSubmitting = false;
  String? _errorMessage;

  /// Stores selected answers:
  /// key = questionId, value = RiskAnswerPayload
  final Map<int, RiskAnswerPayload> _answers = {};

 final List<_RiskQuestion> _questions = const [
  _RiskQuestion(
    id: 1,
    title: 'Age',
    description: 'Select your age group.',
    options: [
      _RiskOption(id: 31, label: 'Less than 35 years'), // ✅ FIXED (was 1)
      _RiskOption(id: 2, label: '35 to 49 years'),
      _RiskOption(id: 3, label: '50 years or more'),
    ],
  ),
  _RiskQuestion(
    id: 2,
    title: 'Waist circumference',
    description: 'Measure at the level of your belly button.',
    options: [
      _RiskOption(id: 4, label: 'Less than 80 cm (female) / 90 cm (male)'),
      _RiskOption(id: 5, label: '80–89 cm (female) / 90–99 cm (male)'),
      _RiskOption(
        id: 6,
        label: '90 cm or more (female) / 100 cm or more (male)',
      ),
    ],
  ),
  _RiskQuestion(
    id: 3,
    title: 'Physical activity',
    description: 'Your usual daily physical activity level.',
    options: [
      _RiskOption(id: 10, label: 'Regular exercise or strenuous work'),
      _RiskOption(id: 11, label: 'Moderate physical activity'),
      _RiskOption(id: 12, label: 'Sedentary (sitting most of the day)'),
    ],
  ),
  _RiskQuestion(
    id: 4,
    title: 'Family history of diabetes',
    description: 'Parents, brothers or sisters with diabetes.',
    options: [
      _RiskOption(id: 13, label: 'No family history'),
      _RiskOption(id: 14, label: 'One parent / sibling'),
      _RiskOption(
        id: 15,
        label: 'Both parents or multiple close relatives',
      ),
    ],
  ),
];



  Future<void> _handleSubmit() async {
    setState(() {
      _errorMessage = null;
    });

    // Validate all questions answered
    if (_answers.length < _questions.length) {
      setState(() {
        _errorMessage = 'Please answer all questions before submitting.';
      });
      return;
    }

    final answersList = _answers.values.toList();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _repository.submitAssessment(1, answersList);

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Assessment submitted'),
          content: Text(
            'Your total score is ${result.total}\n'
            'Risk band: ${result.band}\n\n'
            '${result.message}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      // Pop with "true" so HomeScreen can refresh latest assessment
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Assessment'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Please answer the following questions honestly to calculate your diabetes risk score.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ..._questions.map(_buildQuestionCard),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(_RiskQuestion question) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (question.description != null) ...[
              const SizedBox(height: 4),
              Text(
                question.description!,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 8),
            ...question.options.map(
              (opt) => RadioListTile<int>(
                value: opt.id,
                groupValue: _answers[question.id]?.optionId,
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _answers[question.id] = RiskAnswerPayload(
                      questionId: question.id,
                      optionId: val,
                    );
                  });
                },
                title: Text(opt.label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskQuestion {
  final int id;
  final String title;
  final String? description;
  final List<_RiskOption> options;

  const _RiskQuestion({
    required this.id,
    required this.title,
    this.description,
    required this.options,
  });
}

class _RiskOption {
  final int id;
  final String label;

  const _RiskOption({
    required this.id,
    required this.label,
  });
}
