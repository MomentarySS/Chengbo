import 'package:flutter/material.dart';

import '../../core/privacy.dart';
import '../../core/theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(PrivacyCopy.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, ChengboTheme.listBottomPadding),
        children: [
          Text(
            PrivacyCopy.summary,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          for (final paragraph in PrivacyCopy.paragraphs) ...[
            Text(paragraph, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
