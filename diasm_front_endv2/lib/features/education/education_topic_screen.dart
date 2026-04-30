import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/education_repository.dart';
import '../../core/education_models.dart';

class EducationTopicScreen extends StatefulWidget {
  final String categoryId; // local id from UI (e.g., what-is-diabetes)
  final String categoryTitle; // display title

  const EducationTopicScreen({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
  });

  @override
  State<EducationTopicScreen> createState() => _EducationTopicScreenState();
}

class _EducationTopicScreenState extends State<EducationTopicScreen> {
  bool _isEnglish = true;

  final EducationRepository _repo = EducationRepository();

  late Future<List<EducationContent>> _futureContents;

  @override
  void initState() {
    super.initState();
    _futureContents = _loadContents();
  }

  Future<List<EducationContent>> _loadContents() {
    // Map local Flutter IDs -> backend category codes (from your CSV / DB)
    const Map<String, String> idToCode = {
      'what-is-diabetes': 'DIABETES_BASICS',
      'food-nutrition': 'NUTRITION',
      'exercise': 'EXERCISE',
      'medication-insulin': 'MEDS_INSULIN',
      'monitoring': 'MONITORING',
      'complications': 'COMPLICATIONS',
      'foot-eye-care': 'FOOT_EYE',
      'mental-health': 'COPING_MH',
    };

    final categoryCode = idToCode[widget.categoryId] ?? '';

    return _repo.getContentsByCategory(
      categoryCode: categoryCode,
      lang: _isEnglish ? 'en' : 'bn',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryTitle),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          _LanguageSwitcher(
            isEnglish: _isEnglish,
            onChanged: (value) {
              setState(() {
                _isEnglish = value;
                _futureContents = _loadContents();
              });
            },
          ),

          const SizedBox(height: 12),

          Expanded(
            child: FutureBuilder<List<EducationContent>>(
              future: _futureContents,
              builder: (context, snapshot) {
                // LOADING
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // ERROR
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load topics.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final items = snapshot.data ?? [];

                // EMPTY
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'No contents available for this category.',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                // SUCCESS
                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final topic = items[index];

                    return _TopicCard(
                      index: index + 1,
                      title: topic.title,
                      onTap: () {
                        final encodedTitle =
                            Uri.encodeComponent(topic.title);
                        final encodedId =
                            Uri.encodeComponent(topic.id.toString());

                        (
                          context.push('/education/detail?id=${topic.id}&title=$encodedTitle')
                        );

                      },
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

class _TopicCard extends StatelessWidget {
  final int index;
  final String title;
  final VoidCallback onTap;

  const _TopicCard({
    required this.index,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Text(
                  index.toString(),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
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
