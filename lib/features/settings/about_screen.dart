import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../../core/privacy.dart';
import 'privacy_screen.dart';

/// 关于：版本号、隐私说明。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于'),
            subtitle: Text('${AppBrand.displayName} · ${AppBrand.tagline} v${AppBrand.version}'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text(PrivacyCopy.title),
            subtitle: const Text(PrivacyCopy.summary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
            ),
          ),
        ],
      ),
    );
  }
}