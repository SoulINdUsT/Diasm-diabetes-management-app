
import 'package:flutter/material.dart';

/// Simple two–segment language switch:
/// - isEnglish == true  → "English" selected
/// - isEnglish == false → "বাংলা" selected
///
/// Parent passes [isEnglish] and handles [onChanged] to update state.
class LanguageToggle extends StatelessWidget {
  final bool isEnglish;
  final ValueChanged<bool> onChanged;

  const LanguageToggle({
    super.key,
    required this.isEnglish,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          _buildSegment(
            context,
            label: 'English',
            selected: isEnglish,
            onTap: () => onChanged(true),
          ),
          _buildSegment(
            context,
            label: 'বাংলা',
            selected: !isEnglish,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected
                ? theme.colorScheme.primary
                : Colors.transparent,
          ),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
