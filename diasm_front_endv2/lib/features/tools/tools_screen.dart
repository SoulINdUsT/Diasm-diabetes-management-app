import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'calc/calc_screen.dart';
import 'lifestyle/lifestyle_snapshot_screen.dart';
import 'chatbot/chatbot_screen.dart';
import 'foods/food_list_screen.dart'; // ⭐ Foods module (separate)

class ToolsScreen extends StatelessWidget {
  final bool isEnglish;

  // Palette aligned with Home quick action cards
  static const Color _calcBgColor = Color(0xFFAECBF0 ); // darker soft blue
static const Color _lifeBgColor = Color(0xFFF7D9B8); // darker soft orange
static const Color _foodBgColor = Color(0xFFCFEBCB); // darker soft green
static const Color _chatBgColor = Color(0xFFD9B8F2); // darker soft purple


  // Backward compatible: router can still call const ToolsScreen()
  const ToolsScreen({super.key, this.isEnglish = true});

  @override
  Widget build(BuildContext context) {
    final isEn = isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Tools' : 'টুলস'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CalcMainCard(
            isEnglish: isEn,
            backgroundColor: _calcBgColor,
            onTap: () {
              context.push(CalcScreen.routeName, extra: isEn);
            },
          ),

          const SizedBox(height: 12),

          _LifestyleMainCard(
            isEnglish: isEn,
            backgroundColor: _lifeBgColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LifestyleSnapshotScreen(isEnglish: isEn),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // ⭐ New, separate Foods card OUTSIDE Lifestyle
          _FoodMainCard(
            isEnglish: isEn,
            backgroundColor: _foodBgColor,
          ),

          const SizedBox(height: 12),

          _ChatbotMainCard(
            isEnglish: isEn,
            backgroundColor: _chatBgColor,
            onTap: () {
              context.push(ChatbotScreen.routeName, extra: isEn);
            },
          ),
        ],
      ),
    );
  }
}

class _CalcMainCard extends StatelessWidget {
  final bool isEnglish;
  final VoidCallback onTap;
  final Color backgroundColor;

  const _CalcMainCard({
    required this.isEnglish,
    required this.onTap,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEn = isEnglish;
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.calculate_outlined,
                  color: cs.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Calculation' : 'ক্যালকুলেশন',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MiniPill(text: 'BMI'),
                        _MiniPill(text: 'BMR'),
                        _MiniPill(text: 'Calories'),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: cs.onSurface.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LifestyleMainCard extends StatelessWidget {
  final bool isEnglish;
  final VoidCallback onTap;
  final Color backgroundColor;

  const _LifestyleMainCard({
    required this.isEnglish,
    required this.onTap,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEn = isEnglish;
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.self_improvement_outlined,
                  color: cs.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Lifestyle' : 'লাইফস্টাইল',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MiniPill(text: isEn ? 'Activity' : 'অ্যাক্টিভিটি'),
                        _MiniPill(text: isEn ? 'Hydration' : 'পানি'),
                        _MiniPill(text: isEn ? 'Fasting' : 'উপবাস'),
                        _MiniPill(text: isEn ? 'Meal Plan' : 'মিল প্ল্যান'),
                        // If you no longer want Foods pill inside Lifestyle, just delete this line:
                        _MiniPill(text: isEn ? 'Foods' : 'খাদ্য'),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: cs.onSurface.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodMainCard extends StatelessWidget {
  final bool isEnglish;
  final Color backgroundColor;

  const _FoodMainCard({
    required this.isEnglish,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEn = isEnglish;
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FoodListScreen(isEnglish: isEn),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.restaurant_menu_outlined,
                  color: cs.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Foods' : 'খাদ্য',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEn
                          ? 'Look up calories and portions for Bangladeshi foods.'
                          : 'বাংলাদেশি খাবারের ক্যালরি ও পরিমাণ দেখুন।',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: cs.onSurface.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatbotMainCard extends StatelessWidget {
  final bool isEnglish;
  final VoidCallback onTap;
  final Color backgroundColor;

  const _ChatbotMainCard({
    required this.isEnglish,
    required this.onTap,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEn = isEnglish;
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  color: cs.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn
                          ? 'Talk to DIAsm Assistant'
                          : 'ডায়াসম সহায়কের সাথে কথা বলুন',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEn
                          ? 'Get quick answers about food, exercise, insulin and complications.'
                          : 'খাবার, ব্যায়াম, ইনসুলিন ও জটিলতা নিয়ে দ্রুত উত্তর পান।',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEn
                          ? 'Educational only · May make mistakes'
                          : 'শুধু শিক্ষা সহায়ক · ভুলও করতে পারে',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: cs.onSurface.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String text;
  const _MiniPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
