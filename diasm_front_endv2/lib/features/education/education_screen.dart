import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Main screen used by the router for the Education tab.
class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  bool _isEnglish = true;

  @override
  Widget build(BuildContext context) {
    final categories = _isEnglish ? _englishCategories : _banglaCategories;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEnglish ? 'Education Hub' : 'শিক্ষা কেন্দ্র'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          _LanguageSwitcher(
            isEnglish: _isEnglish,
            onChanged: (isEnglish) {
              setState(() {
                _isEnglish = isEnglish;
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return _CategoryCard(
                  title: cat.title,
                  subtitle: cat.subtitle,
                  icon: cat.icon,
                  onTap: () {
                    final encodedTitle = Uri.encodeComponent(cat.title);
                    final encodedId = Uri.encodeComponent(cat.id);
                    context.go(
                      '/education/topics?id=$encodedId&title=$encodedTitle',
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

/// Simple language toggle: English | বাংলা
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
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(true),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isEnglish
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'English',
                    style: TextStyle(
                      color: isEnglish
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(false),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: !isEnglish
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'বাংলা',
                    style: TextStyle(
                      color: !isEnglish
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
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

/// Reusable category card widget (static version).
class _CategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 30, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Very small internal model just for the static UI phase.
class _CategoryItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  const _CategoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

// ===== Dummy static data (still static, but better icons) =====

const _englishCategories = <_CategoryItem>[
  _CategoryItem(
    id: 'what-is-diabetes',
    title: 'What is diabetes?',
    subtitle:
        'Learn the basics of diabetes, its types, and how it affects your body.',
    icon: Icons.medical_information,
  ),
  _CategoryItem(
    id: 'food-nutrition',
    title: 'Food & nutrition',
    subtitle: 'Healthy eating habits and dietary guidelines for diabetes.',
    icon: Icons.restaurant_menu,
  ),
  _CategoryItem(
    id: 'exercise',
    title: 'Exercise',
    subtitle: 'Benefits of physical activity and staying active.',
    icon: Icons.directions_run,
  ),
  _CategoryItem(
    id: 'medication-insulin',
    title: 'Medication & insulin',
    subtitle: 'Medications, insulin types, and safe usage.',
    icon: Icons.vaccines,
  ),
  _CategoryItem(
    id: 'monitoring',
    title: 'Monitoring',
    subtitle: 'Blood glucose monitoring devices and result tracking.',
    icon: Icons.monitor_heart,
  ),
  _CategoryItem(
    id: 'complications',
    title: 'Complications',
    subtitle: 'Long-term complications and how to prevent them.',
    icon: Icons.health_and_safety,
  ),
  _CategoryItem(
    id: 'foot-eye-care',
    title: 'Foot/Eye care',
    subtitle: 'Proper foot and eye care to prevent problems.',
    icon: Icons.visibility,
  ),
  _CategoryItem(
    id: 'mental-health',
    title: 'Coping & mental health',
    subtitle: 'Emotional well-being and mental health support.',
    icon: Icons.psychology_alt,
  ),
];

const _banglaCategories = <_CategoryItem>[
  _CategoryItem(
    id: 'what-is-diabetes',
    title: 'ডায়াবেটিস কী?',
    subtitle:
        'ডায়াবেটিসের মূল বিষয়, প্রকারভেদ এবং শরীরের উপর এর প্রভাব সম্পর্কে জানুন।',
    icon: Icons.medical_information,
  ),
  _CategoryItem(
    id: 'food-nutrition',
    title: 'খাবার ও পুষ্টি',
    subtitle: 'স্বাস্থ্যকর খাদ্যাভ্যাস ও ডায়াবেটিস খাদ্য পরিকল্পনা।',
    icon: Icons.restaurant_menu,
  ),
  _CategoryItem(
    id: 'exercise',
    title: 'ব্যায়াম',
    subtitle: 'শারীরিক কার্যকলাপের উপকারিতা এবং সক্রিয় থাকার টিপস।',
    icon: Icons.directions_run,
  ),
  _CategoryItem(
    id: 'medication-insulin',
    title: 'ওষুধ ও ইনসুলিন',
    subtitle: 'বিভিন্ন ওষুধ, ইনসুলিনের ধরন এবং নিরাপদ ব্যবহার।',
    icon: Icons.vaccines,
  ),
  _CategoryItem(
    id: 'monitoring',
    title: 'পর্যবেক্ষণ',
    subtitle: 'রক্তে গ্লুকোজ পর্যবেক্ষণ ও ফলাফল অনুসরণ।',
    icon: Icons.monitor_heart,
  ),
  _CategoryItem(
    id: 'complications',
    title: 'জটিলতা',
    subtitle: 'দীর্ঘমেয়াদি জটিলতা এবং প্রতিরোধের উপায়।',
    icon: Icons.health_and_safety,
  ),
  _CategoryItem(
    id: 'foot-eye-care',
    title: 'পা/চোখের যত্ন',
    subtitle: 'পা ও চোখের সঠিক যত্ন সম্পর্কে জানুন।',
    icon: Icons.visibility,
  ),
  _CategoryItem(
    id: 'mental-health',
    title: 'মানসিক স্বাস্থ্য',
    subtitle: 'ডায়াবেটিসের মানসিক দিক পরিচালনার সহায়তা।',
    icon: Icons.psychology_alt,
  ),
];
