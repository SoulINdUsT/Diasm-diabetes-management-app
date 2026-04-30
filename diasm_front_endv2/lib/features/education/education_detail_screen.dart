// lib/features/education/education_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/education_repository.dart';
import '../../core/education_models.dart';

class EducationDetailScreen extends StatefulWidget {
  final int contentId;
  final String title;

  const EducationDetailScreen({
    super.key,
    required this.contentId,
    required this.title,
  });

  @override
  State<EducationDetailScreen> createState() => _EducationDetailScreenState();
}

class _EducationDetailScreenState extends State<EducationDetailScreen> {
  bool _isEnglish = true;

  final EducationRepository _repo = EducationRepository();
  late Future<EducationContent> _futureContent;

  @override
  void initState() {
    super.initState();
    _futureContent = _loadContent();
  }

  Future<EducationContent> _loadContent() {
    return _repo.getContentById(
      id: widget.contentId,
      lang: _isEnglish ? 'en' : 'bn',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // We keep the original title passed from the list for now.
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // ===== Language switcher (same style as topic screen) =====
          _LanguageSwitcher(
            isEnglish: _isEnglish,
            onChanged: (value) {
              if (_isEnglish == value) return;
              setState(() {
                _isEnglish = value;
                _futureContent = _loadContent();
              });
            },
          ),

          const SizedBox(height: 12),

          // ===== Content area =====
          Expanded(
            child: FutureBuilder<EducationContent>(
              future: _futureContent,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load detail\n${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!snap.hasData) {
                  return const Center(
                    child: Text('No content found'),
                  );
                }

                final item = snap.data!;
                final mediaUrl = item.mediaUrl;
                final body = item.body;
                final title = item.title.isNotEmpty
                    ? item.title
                    : (_isEnglish
                        ? item.titleEn
                        : (item.titleBn ?? item.titleEn));

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== Title =====
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ===== Image from DB (if any) =====
                      if (mediaUrl != null && mediaUrl.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                mediaUrl,
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                                errorBuilder: (context, error, stack) {
                                  return const Center(
                                    child: Icon(Icons.broken_image, size: 48),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // ===== Body text =====
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Same visual language switcher used on topic screen.
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
