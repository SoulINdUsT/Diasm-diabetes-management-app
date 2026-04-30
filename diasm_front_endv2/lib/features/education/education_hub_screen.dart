
// lib/features/education/education_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/education_models.dart';
import '../../core/education_repository.dart';

class EducationHubScreen extends StatefulWidget {
  const EducationHubScreen({super.key});

  @override
  State<EducationHubScreen> createState() => _EducationHubScreenState();
}

class _EducationHubScreenState extends State<EducationHubScreen> {
  final EducationRepository _repo = EducationRepository();

  bool _isEnglish = true;
  late Future<List<EducationCategory>> _futureCategories;

  /// We keep a fixed list of categories (slug + backend code) so
  /// routing and ordering stay stable, while names come from backend.
  final List<_CategoryDef> _categoryDefs = const [
    _CategoryDef(
      slug: 'what-is-diabetes',
      code: 'DIABETES_BASICS',
      defaultTitleEn: 'What is diabetes?',
      icon: Icons.info_outline,
    ),
    _CategoryDef(
      slug: 'food-nutrition',
      code: 'NUTRITION',
      defaultTitleEn: 'Food & nutrition',
      icon: Icons.restaurant_outlined,
    ),
    _CategoryDef(
      slug: 'exercise',
      code: 'EXERCISE',
      defaultTitleEn: 'Exercise',
      icon: Icons.fitness_center,
    ),
    _CategoryDef(
      slug: 'medication-insulin',
      code: 'MEDS_INSULIN',
      defaultTitleEn: 'Medication & insulin',
      icon: Icons.healing_outlined,
    ),
    _CategoryDef(
      slug: 'monitoring',
      code: 'MONITORING',
      defaultTitleEn: 'Monitoring',
      icon: Icons.monitor_heart_outlined,
    ),
    _CategoryDef(
      slug: 'complications',
      code: 'COMPLICATIONS',
      defaultTitleEn: 'Complications',
      icon: Icons.warning_amber_rounded,
    ),
    _CategoryDef(
      slug: 'foot-eye-care',
      code: 'FOOT_EYE',
      defaultTitleEn: 'Foot/Eye care',
      icon: Icons.visibility_outlined,
    ),
    _CategoryDef(
      slug: 'mental-health',
      code: 'COPING_MH',
      defaultTitleEn: 'Coping & mental health',
      icon: Icons.psychology_outlined,
    ),
  ];

  // High-contrast vibrant colors for each category
final List<Color> _cardColors = const [
  Color(0xFF03A9F4), // Diabetes Basics - Sky Blue
  Color(0xFF4CAF50), // Food & Nutrition - Green
  Color(0xFFFF9800), // Exercise - Orange
  Color(0xFF9C27B0), // Medication - Purple
  Color.fromARGB(255, 27, 73, 110), // Monitoring - Blue
  Color(0xFFF44336), // Complications - Red
  Color(0xFF009688), // Foot/Eye care - Teal
  Color(0xFFE91E63), // Mental health - Pink
];

  // Front-end Bangla titles mapped by backend code
  final Map<String, String> _banglaTitles = const {
    'DIABETES_BASICS': 'ডায়াবেটিস কী?',
    'NUTRITION': 'খাদ্য ও পুষ্টি',
    'EXERCISE': 'ব্যায়ামের উপকারিতা',
    'MEDS_INSULIN': 'ওষুধ ও ইনসুলিন',
    'MONITORING': 'রক্তের শর্করা পর্যবেক্ষণ',
    'COMPLICATIONS': 'জটিলতা প্রতিরোধ',
    'FOOT_EYE': 'পা ও চোখের যত্ন',
    'COPING_MH': 'মানসিক স্বাস্থ্য ও সহায়তা',
  };



  @override
  void initState() {
    super.initState();
    _futureCategories = _loadCategories();
  }

Future<List<EducationCategory>> _loadCategories() {
  // Just get English names from backend once
  return _repo.getCategories(lang: 'en');
}


  void _toggleLanguage(bool value) {
    if (_isEnglish == value) return;
    setState(() {
      _isEnglish = value;
      _futureCategories = _loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Education Hub'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          _LanguageSwitcher(
            isEnglish: _isEnglish,
            onChanged: _toggleLanguage,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<EducationCategory>>(
              future: _futureCategories,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Spinner while categories load
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _isEnglish
                            ? 'Failed to load education categories.\nPlease try again.'
                            : 'শিক্ষা বিভাগের তালিকা লোড করতে সমস্যা হয়েছে।\nআবার চেষ্টা করুন।',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final categories = snapshot.data ?? [];
                // Index by backend code for quick lookup
                final Map<String, EducationCategory> byCode = {
                  for (final c in categories) c.code: c,
                };

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _categoryDefs.length,
                  itemBuilder: (context, index) {
                    final def = _categoryDefs[index];
                   final backendCat = byCode[def.code];

// Always take English as base from backend / defaults
final baseTitle = backendCat?.nameEn ?? def.defaultTitleEn;

// If toggle is Bangla, try Bangla map; otherwise use English
final title = _isEnglish
    ? baseTitle
    : (_banglaTitles[def.code] ?? baseTitle);

                    final color = _cardColors[index % _cardColors.length];

                    return _CategoryCard(
                      title: title,
                      slug: def.slug,
                      color: color,
                      icon: def.icon,
                      isEnglish: _isEnglish,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Small helper model used only inside this file
class _CategoryDef {
  final String slug; // used as ?id= in topics screen
  final String code; // backend code, e.g. DIABETES_BASICS
  final String defaultTitleEn;
  final IconData icon;

  const _CategoryDef({
    required this.slug,
    required this.code,
    required this.defaultTitleEn,
    required this.icon,
  });
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final String slug;
  final bool isEnglish;
  final Color color;
  final IconData icon;

  const _CategoryCard({
    required this.title,
    required this.slug,
    required this.isEnglish,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          // Build URL manually with query string, matching app_router.dart
          final encodedTitle = Uri.encodeComponent(title);
          final path = '/education/topics?id=$slug&title=$encodedTitle';
          context.push(path);
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.95),
                color.withOpacity(0.75),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withOpacity(0.20),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Reusable language switcher (English / বাংলা)
class _LanguageSwitcher extends StatelessWidget {
  final bool isEnglish;
  final ValueChanged<bool> onChanged;

  const _LanguageSwitcher({
    required this.isEnglish,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2F1), // soft teal-ish bar
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isEnglish ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isEnglish
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    'English',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isEnglish
                          ? theme.colorScheme.primary
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: !isEnglish ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: !isEnglish
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    'বাংলা',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: !isEnglish
                          ? theme.colorScheme.primary
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

