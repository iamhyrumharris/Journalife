import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sync_config.dart';
import '../../providers/sync_config_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/database_provider.dart';
import '../../services/webdav_validation_service.dart';

class WebDAVSetupScreen extends ConsumerStatefulWidget {
  final SyncConfig? config; // null for new config, existing config for editing

  const WebDAVSetupScreen({super.key, this.config});

  @override
  ConsumerState<WebDAVSetupScreen> createState() => _WebDAVSetupScreenState();
}

class _WebDAVSetupScreenState extends ConsumerState<WebDAVSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();

  SyncFrequency _syncFrequency = SyncFrequency.manual;
  bool _syncOnWifiOnly = true;
  bool _syncAttachments = true;
  bool _encryptData = false;
  bool _passwordVisible = false;
  bool _isTestingConnection = false;
  bool _isSaving = false;
  bool _isRunningValidation = false;

  @override
  void initState() {
    super.initState();

    // If editing existing config, populate fields
    if (widget.config != null) {
      _serverUrlController.text = widget.config!.serverUrl;
      _usernameController.text = widget.config!.username;
      _displayNameController.text = widget.config!.displayName;
      _syncFrequency = widget.config!.syncFrequency;
      _syncOnWifiOnly = widget.config!.syncOnWifiOnly;
      _syncAttachments = widget.config!.syncAttachments;
      _encryptData = widget.config!.encryptData;
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.config != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit WebDAV Config' : 'WebDAV Setup'),
        actions: [
          if (isEditing)
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'test',
                  child: Row(
                    children: [
                      Icon(Icons.wifi_protected_setup),
                      SizedBox(width: 8),
                      Text('Test Connection'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Delete Config',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildServerSection(),
              const SizedBox(height: 24),
              _buildAuthenticationSection(),
              const SizedBox(height: 24),
              _buildSyncSettingsSection(),
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud),
                const SizedBox(width: 8),
                Text(
                  'Server Configuration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'My WebDAV Server',
                prefixIcon: Icon(Icons.label),
              ),
              validator: (value) {
                if (value?.trim().isEmpty == true) {
                  return 'Display name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://cloud.example.com/remote.php/dav',
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value?.trim().isEmpty == true) {
                  return 'Server URL is required';
                }

                try {
                  final uri = Uri.parse(value!.trim());
                  if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
                    return 'URL must start with http:// or https://';
                  }
                } catch (e) {
                  return 'Invalid URL format';
                }

                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security),
                const SizedBox(width: 8),
                Text(
                  'Authentication',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'your-username',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value?.trim().isEmpty == true) {
                  return 'Username is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: widget.config != null
                    ? 'Password (leave empty to keep current)'
                    : 'Password',
                hintText: widget.config != null
                    ? 'Current password will be kept if empty'
                    : 'your-password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_passwordVisible,
              validator: (value) {
                // For new configs, password is required
                // For existing configs, password is optional (keeps existing if empty)
                if (widget.config == null && (value?.trim().isEmpty == true)) {
                  return 'Password is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),
            Card(
              color: Colors.blue.withValues(alpha: 0.1),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Passwords are stored securely on your device and never transmitted in plain text.',
                        style: TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync),
                const SizedBox(width: 8),
                Text(
                  'Sync Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Sync Frequency
            DropdownButtonFormField<SyncFrequency>(
              value: _syncFrequency,
              decoration: const InputDecoration(
                labelText: 'Sync Frequency',
                prefixIcon: Icon(Icons.schedule),
              ),
              items: SyncFrequency.values.map((frequency) {
                return DropdownMenuItem(
                  value: frequency,
                  child: Text(_getSyncFrequencyLabel(frequency)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _syncFrequency = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Sync Settings Switches
            SwitchListTile(
              title: const Text('WiFi Only'),
              subtitle: const Text('Only sync when connected to WiFi'),
              value: _syncOnWifiOnly,
              onChanged: (value) {
                setState(() {
                  _syncOnWifiOnly = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text('Sync Attachments'),
              subtitle: const Text(
                'Include photos, audio, and file attachments',
              ),
              value: _syncAttachments,
              onChanged: (value) {
                setState(() {
                  _syncAttachments = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text('Encrypt Data'),
              subtitle: const Text(
                'Encrypt journal data before uploading (experimental)',
              ),
              value: _encryptData,
              onChanged: (value) {
                setState(() {
                  _encryptData = value;
                });
              },
            ),

            if (_encryptData) ...[
              const SizedBox(height: 8),
              Card(
                color: Colors.orange.withValues(alpha: 0.1),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Data encryption is experimental. Make sure you have local backups.',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _isTestingConnection ? null : _testConnection,
          icon: _isTestingConnection
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_protected_setup),
          label: Text(_isTestingConnection ? 'Testing...' : 'Test Connection'),
        ),
        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: _isRunningValidation ? null : _runFullValidation,
          icon: _isRunningValidation
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.checklist),
          label: Text(_isRunningValidation ? 'Validating...' : 'Run Full Validation'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).primaryColor,
            side: BorderSide(color: Theme.of(context).primaryColor),
          ),
        ),
        const SizedBox(height: 12),

        ElevatedButton.icon(
          onPressed: (_isSaving || _isTestingConnection || _isRunningValidation)
              ? null
              : _saveConfiguration,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
        ),
      ],
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'test':
        _testConnection();
        break;
      case 'delete':
        _deleteConfiguration();
        break;
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    // Need password for testing
    if (_passwordController.text.trim().isEmpty && widget.config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password is required for connection test'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isTestingConnection = true;
    });

    try {
      // Create a temporary config for testing
      final testConfig = SyncConfig(
        id: 'test',
        serverUrl: _serverUrlController.text.trim(),
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        lastSyncAt: DateTime.now(),
        syncFrequency: _syncFrequency,
        syncOnWifiOnly: _syncOnWifiOnly,
        syncAttachments: _syncAttachments,
        encryptData: _encryptData,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      String password = _passwordController.text.trim();

      // If editing and no new password provided, try to get existing password
      if (widget.config != null && password.isEmpty) {
        final storedPassword = await ref.read(
          syncPasswordProvider(widget.config!.id).future,
        );
        if (storedPassword != null) {
          password = storedPassword;
        } else {
          throw Exception('No password available for testing');
        }
      }

      final success = await ref
          .read(syncProvider.notifier)
          .testConnection(testConfig, password);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Connection successful! Your WebDAV server is working correctly.'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Connection failed')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Check your server URL, username, and password. See console for details.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Troubleshoot',
                textColor: Colors.white,
                onPressed: () => _showTroubleshootingDialog(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text('Connection test error'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  e.toString().length > 100 
                    ? '${e.toString().substring(0, 97)}...'
                    : e.toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  /// Runs comprehensive WebDAV validation with detailed results
  Future<void> _runFullValidation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isRunningValidation = true;
    });

    try {
      // Get password - either from form or stored password for existing config
      String password;
      if (_passwordController.text.trim().isNotEmpty) {
        // Use password from form
        password = _passwordController.text.trim();
      } else if (widget.config != null) {
        // Try to get stored password for existing config
        try {
          final storedPassword = await ref
              .read(databaseServiceProvider)
              .getSyncPassword(widget.config!.id);
          if (storedPassword == null || storedPassword.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password is required for validation. Please enter your password in the password field.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          password = storedPassword;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to retrieve stored password: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } else {
        // New config and no password provided
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password is required for validation'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Create a temporary config for validation
      final testConfig = SyncConfig(
        id: widget.config?.id ?? 'validation',
        serverUrl: _serverUrlController.text.trim(),
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        lastSyncAt: DateTime.now(),
        syncFrequency: _syncFrequency,
        syncOnWifiOnly: _syncOnWifiOnly,
        syncAttachments: _syncAttachments,
        encryptData: _encryptData,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      debugPrint('🔍 Running full validation with:');
      debugPrint('Server URL: ${testConfig.serverUrl}');
      debugPrint('Username: ${testConfig.username}');
      debugPrint('Using stored password: ${_passwordController.text.trim().isEmpty && widget.config != null}');

      final validationService = WebDAVValidationService();
      final result = await validationService.performFullValidation(
        testConfig,
        password,
      );

      if (mounted) {
        _showValidationResults(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Validation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunningValidation = false;
        });
      }
    }
  }

  /// Shows detailed validation results in a dialog
  void _showValidationResults(WebDAVValidationResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.overallSuccess ? Icons.check_circle : Icons.error,
              color: result.overallSuccess ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              'Validation Results',
              style: TextStyle(
                color: result.overallSuccess ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.summary,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Test Results:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: result.tests.map((test) => Card(
                      color: test.success
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      child: ListTile(
                        leading: Icon(
                          test.success ? Icons.check : Icons.close,
                          color: test.success ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          test.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(test.message),
                            if (test.details.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                test.details,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                        isThreeLine: test.details.isNotEmpty,
                      ),
                    )).toList(),
                  ),
                ),
              ),
              if (result.overallSuccess) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All tests passed! Your WebDAV server is properly configured and all required directories have been created.',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Some tests failed. Please check your configuration and server settings.',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!result.overallSuccess)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showValidationTroubleshooting();
              },
              child: const Text('Troubleshooting'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Shows troubleshooting dialog for validation failures
  void _showValidationTroubleshooting() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Troubleshooting'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Common Issues and Solutions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('• Authentication Failed (401)'),
              Text('  → Check username and password'),
              Text('  → Verify account is not locked'),
              SizedBox(height: 8),
              Text('• Permission Denied (403)'),
              Text('  → Check user has WebDAV access'),
              Text('  → Verify folder creation permissions'),
              SizedBox(height: 8),
              Text('• Server Not Found (404)'),
              Text('  → Check server URL is correct'),
              Text('  → Verify WebDAV is enabled on server'),
              SizedBox(height: 8),
              Text('• Network Timeout'),
              Text('  → Check internet connection'),
              Text('  → Try connecting to server from browser'),
              SizedBox(height: 8),
              Text('• Directory Creation Failed'),
              Text('  → User may need admin privileges'),
              Text('  → Check available disk space'),
              SizedBox(height: 8),
              Text('• File Operations Failed'),
              Text('  → Check read/write permissions'),
              Text('  → Verify server supports WebDAV operations'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final syncNotifier = ref.read(syncConfigProvider.notifier);

      if (widget.config == null) {
        // Create new configuration
        await syncNotifier.createConfiguration(
          serverUrl: _serverUrlController.text.trim(),
          username: _usernameController.text.trim(),
          displayName: _displayNameController.text.trim(),
          password: _passwordController.text.trim(),
          syncFrequency: _syncFrequency,
          syncOnWifiOnly: _syncOnWifiOnly,
          syncAttachments: _syncAttachments,
          encryptData: _encryptData,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WebDAV configuration created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Update existing configuration
        final updatedConfig = widget.config!.copyWith(
          serverUrl: _serverUrlController.text.trim(),
          username: _usernameController.text.trim(),
          displayName: _displayNameController.text.trim(),
          syncFrequency: _syncFrequency,
          syncOnWifiOnly: _syncOnWifiOnly,
          syncAttachments: _syncAttachments,
          encryptData: _encryptData,
        );

        await syncNotifier.updateConfiguration(updatedConfig);

        // Update password if provided
        if (_passwordController.text.trim().isNotEmpty) {
          await ref
              .read(databaseServiceProvider)
              .storeSyncPassword(
                widget.config!.id,
                _passwordController.text.trim(),
              );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WebDAV configuration updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteConfiguration() async {
    if (widget.config == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Configuration'),
        content: Text(
          'Are you sure you want to delete "${widget.config!.displayName}"?\n\nThis will stop all sync operations for this configuration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await ref
            .read(syncConfigProvider.notifier)
            .deleteConfiguration(widget.config!.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configuration deleted successfully'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete configuration: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getSyncFrequencyLabel(SyncFrequency frequency) {
    switch (frequency) {
      case SyncFrequency.manual:
        return 'Manual';
      case SyncFrequency.onAppStart:
        return 'On App Start';
      case SyncFrequency.hourly:
        return 'Every Hour';
      case SyncFrequency.daily:
        return 'Daily';
      case SyncFrequency.weekly:
        return 'Weekly';
    }
  }

  void _showTroubleshootingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WebDAV Connection Troubleshooting'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Common issues and solutions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              _buildTroubleshootItem(
                icon: Icons.link_off,
                title: 'Server URL Issues',
                solutions: [
                  'Ensure URL starts with https:// or http://',
                  'Include full path (e.g., /remote.php/dav for Nextcloud)',
                  'Remove trailing slash from URL',
                  'Try accessing URL in web browser first',
                ],
              ),
              
              _buildTroubleshootItem(
                icon: Icons.person_off,
                title: 'Authentication Issues', 
                solutions: [
                  'Verify username and password are correct',
                  'Try logging into web interface first',
                  'Check if 2FA is enabled (may need app password)',
                  'Ensure WebDAV access is enabled for your account',
                ],
              ),
              
              _buildTroubleshootItem(
                icon: Icons.wifi_off,
                title: 'Network Issues',
                solutions: [
                  'Check internet connectivity',
                  'Try from different network if behind firewall',
                  'Verify server is accessible externally',
                  'Check if VPN is required',
                ],
              ),
              
              _buildTroubleshootItem(
                icon: Icons.security,
                title: 'SSL/TLS Issues',
                solutions: [
                  'Try http:// instead of https:// for testing',
                  'Check if server has valid SSL certificate',
                  'Ensure device trusts server certificate',
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _testConnection();
            },
            child: const Text('Test Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootItem({
    required IconData icon,
    required String title,
    required List<String> solutions,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...solutions.map((solution) => Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Colors.grey)),
                Expanded(
                  child: Text(
                    solution,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
