import 'package:flutter/material.dart';

/// 居中短句空状态。可带一句说明和一个主操作，不做插画英雄区。
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String message;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
              if (onSecondaryAction != null && secondaryActionLabel != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: onSecondaryAction, child: Text(secondaryActionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
