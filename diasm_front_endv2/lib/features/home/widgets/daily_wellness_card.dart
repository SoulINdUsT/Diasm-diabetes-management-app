import 'package:flutter/material.dart';
import 'package:diasm_front_endv2/core/rightpath_models.dart';

class DailyWellnessCard extends StatelessWidget {
  final RightPathTodayStatus? today;
  final RightPathWeeklySummary? weekly;

  final double? glucoseMgdl; // <-- NEW
  final bool isEnglish;
  final VoidCallback? onTap;

  const DailyWellnessCard({
    super.key,
    required this.today,
    required this.weekly,
    required this.isEnglish,
    this.glucoseMgdl,            // <-- NEW
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = today;
    final w = weekly;

    final Widget cardChild;

    if (t == null && w == null) {
      cardChild = _buildEmptyState(theme);
    } else {
      final status = t?.status ?? RightPathStatus.unknown;
      final score = t?.dailyScore ?? 0;
      final scoreText = '$score%';

      final weeklyAvg = w?.averageScore ?? 0;
      final weeklyText = '$weeklyAvg%';

      final title =
          isEnglish ? 'Daily Wellness Score' : 'দৈনিক সুস্থতার স্কোর';

      final statusLabel = isEnglish
          ? rightPathStatusToLabelEn(status)
          : rightPathStatusToLabelBn(status);

      final message = isEnglish
          ? (t?.messageEn ??
              'Keep building your healthy routine step by step.')
          : (t?.messageBn ??
              'ধীরে ধীরে স্বাস্থ্যকর অভ্যাস গড়ে তুলুন।');

      final statusColor = _statusColor(theme, status);

      // --------- NEW GLUCOSE ADVICE LOGIC ---------
      String? glucoseAdvice;
      if (glucoseMgdl != null) {
        final g = glucoseMgdl!;

        if (g < 70) {
          glucoseAdvice = isEnglish
              ? 'Your last glucose reading today was low. If you feel shaky, sweaty or weak, take fast-acting carbohydrates and follow your doctor’s advice.'
              : 'আজ আপনার শেষ গ্লুকোজ রিডিং কম ছিল। কাঁপুনি, ঘাম বা দুর্বল লাগলে দ্রুত শর্করা জাতীয় খাবার নিন এবং ডাক্তারের পরামর্শ অনুসরণ করুন।';
        } else if (g > 180) {
          glucoseAdvice = isEnglish
              ? 'Your last glucose reading today was high. Drink water, walk lightly if possible, and follow your doctor’s plan for high sugar.'
              : 'আজ আপনার শেষ গ্লুকোজ রিডিং বেশি ছিল। পানি পান করুন, হালকা হাঁটুন এবং উচ্চ সুগারের জন্য ডাক্তারের নির্দেশনা অনুসরণ করুন।';
        }
      }
      // --------------------------------------------

      cardChild = Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _StatusChip(
                    label: statusLabel,
                    color: statusColor,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Score + weekly avg
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ScoreCircle(
                    score: score,
                    color: statusColor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEnglish ? 'Today' : 'আজ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          scoreText,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          isEnglish ? 'Weekly average' : 'সাপ্তাহিক গড়',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          weeklyText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        if (w != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _buildWeeklySummaryLine(w, isEnglish),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Main wellness message
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),

              // --------- NEW GLUCOSE ADVICE UI ---------
              if (glucoseAdvice != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          glucoseAdvice,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade800,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // ------------------------------------------

              if (onTap != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    isEnglish ? 'View details' : 'বিস্তারিত দেখুন',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: cardChild,
    );
  }

  // ---------------- Empty state ----------------
  Widget _buildEmptyState(ThemeData theme) {
    final title = isEnglish ? 'Daily Wellness Score' : 'দৈনিক সুস্থতার স্কোর';
    final text = isEnglish
        ? 'No wellness data for today yet. Log your walking, water, meals and sleep to see your score.'
        : 'আজকের জন্য কোনো সুস্থতার ডাটা নেই। হাঁটা, পানি পান, খাবার ও ঘুম লগ করলে স্কোর দেখতে পারবেন।';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.favorite_outline, color: theme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Utilities ----------------
 String _buildWeeklySummaryLine(
  RightPathWeeklySummary w,
  bool isEn,
) {
  return isEn
      ? 'Tracked ${w.daysTracked} day(s), ${w.onTrackDays} on track, ${w.needsCareDays} days needed extra care'
      : 'মোট ${w.daysTracked} দিন ট্র্যাকড, ${w.onTrackDays} দিন ভালো, ${w.needsCareDays} দিন অতিরিক্ত যত্ন দরকার';
}


  Color _statusColor(ThemeData theme, RightPathStatus s) {
    switch (s) {
      case RightPathStatus.onTrack:
        return Colors.green;
      case RightPathStatus.almost:
        return Colors.orange;
      case RightPathStatus.needsCare:
        return Colors.red;
      default:
        return theme.primaryColor;
    }
  }
}

// ---------------- Sub-widgets ----------------

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  final int score;
  final Color color;

  const _ScoreCircle({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 100);

    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: clamped / 100,
            strokeWidth: 6,
            valueColor: AlwaysStoppedAnimation(color),
            backgroundColor: Colors.grey.shade300.withOpacity(0.4),
          ),
          Text(
            '$clamped%',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
