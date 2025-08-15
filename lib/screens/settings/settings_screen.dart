import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sync/sync_management_screen.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSettingsSection(
            context,
            'Sync & Backup',
            [
              _buildSettingsTile(
                context,
                icon: Icons.sync,
                title: 'WebDAV Sync',
                subtitle: 'Configure cloud synchronization',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SyncManagementScreen(),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                context,
                icon: Icons.backup,
                title: 'Export Data',
                subtitle: 'Export your journal data',
                onTap: () {
                  _showExportDialog(context);
                },
              ),
              _buildSettingsTile(
                context,
                icon: Icons.restore,
                title: 'Import Data',
                subtitle: 'Import journal data from file',
                onTap: () {
                  _showImportDialog(context);
                },
              ),
            ],
          ),
          const Divider(),
          _buildSettingsSection(
            context,
            'Appearance',
            [
              _buildThemeSettingsTile(context, ref),
              _buildSettingsTile(
                context,
                icon: Icons.text_fields,
                title: 'Font Size',
                subtitle: 'Adjust text size for entries',
                onTap: () {
                  _showFontSizeDialog(context);
                },
              ),
            ],
          ),
          const Divider(),
          _buildSettingsSection(
            context,
            'Privacy & Security',
            [
              _buildSettingsTile(
                context,
                icon: Icons.lock,
                title: 'App Lock',
                subtitle: 'Require authentication to open app',
                onTap: () {
                  _showAppLockDialog(context);
                },
              ),
              _buildSettingsTile(
                context,
                icon: Icons.visibility_off,
                title: 'Hide Sensitive Content',
                subtitle: 'Blur entry previews in app switcher',
                onTap: () {
                  _showPrivacyDialog(context);
                },
              ),
            ],
          ),
          const Divider(),
          _buildSettingsSection(
            context,
            'Notifications',
            [
              _buildSettingsTile(
                context,
                icon: Icons.notifications,
                title: 'Daily Reminders',
                subtitle: 'Get reminded to write in your journal',
                onTap: () {
                  _showReminderDialog(context);
                },
              ),
            ],
          ),
          const Divider(),
          _buildSettingsSection(
            context,
            'About',
            [
              _buildSettingsTile(
                context,
                icon: Icons.info,
                title: 'App Version',
                subtitle: '1.0.0 (Build 1)',
                onTap: () {
                  _showAboutDialog(context);
                },
              ),
              _buildSettingsTile(
                context,
                icon: Icons.description,
                title: 'Privacy Policy',
                subtitle: 'View our privacy policy',
                onTap: () {
                  _showPrivacyPolicy(context);
                },
              ),
              _buildSettingsTile(
                context,
                icon: Icons.gavel,
                title: 'Terms of Service',
                subtitle: 'View terms and conditions',
                onTap: () {
                  _showTermsOfService(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildThemeSettingsTile(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    String themeName;
    switch (themeMode) {
      case ThemeMode.light:
        themeName = 'Light';
        break;
      case ThemeMode.dark:
        themeName = 'Dark';
        break;
      case ThemeMode.system:
        themeName = 'System Default';
        break;
    }
    
    return ListTile(
      leading: const Icon(Icons.palette),
      title: const Text('Theme'),
      subtitle: Text(themeName),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        _showThemeDialog(context, ref);
      },
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('Export functionality will be implemented soon. This will allow you to backup your journal data to a file.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text('Import functionality will be implemented soon. This will allow you to restore journal data from a backup file.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.read(themeModeProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: StatefulBuilder(
          builder: (context, setState) {
            ThemeMode selectedMode = currentThemeMode;
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('Light'),
                  value: ThemeMode.light,
                  groupValue: selectedMode,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedMode = value);
                      ref.read(themeModeProvider.notifier).setThemeMode(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark'),
                  value: ThemeMode.dark,
                  groupValue: selectedMode,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedMode = value);
                      ref.read(themeModeProvider.notifier).setThemeMode(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('System Default'),
                  value: ThemeMode.system,
                  groupValue: selectedMode,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedMode = value);
                      ref.read(themeModeProvider.notifier).setThemeMode(value);
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Font Size'),
        content: const Text('Font size adjustment will be implemented soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAppLockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Lock'),
        content: const Text('App lock functionality will be implemented soon. This will require biometric or PIN authentication to open the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Settings'),
        content: const Text('Privacy settings will be implemented soon. This will allow you to hide sensitive content in app previews.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showReminderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily Reminders'),
        content: const Text('Reminder functionality will be implemented soon. You will be able to set up daily notifications to write in your journal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Journal',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2024 Journal App. All rights reserved.',
      children: [
        const Text('A personal journaling app with multi-user support, WebDAV sync, and rich media capabilities.'),
      ],
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Your privacy is important to us. This app stores your journal data locally on your device. '
            'When you enable WebDAV sync, your data is transmitted securely to your chosen server. '
            'We do not collect or store any personal information on our servers.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'By using this app, you agree to use it responsibly and in accordance with applicable laws. '
            'The app is provided "as is" without warranties. You are responsible for backing up your data.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}