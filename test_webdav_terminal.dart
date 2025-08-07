import 'dart:io';
import 'lib/services/webdav_sync_service.dart';
import 'lib/models/sync_config.dart';

/// Terminal-based WebDAV connection test
void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart test_webdav_terminal.dart <password>');
    print('This will test the WebDAV connection to your Nextcloud server.');
    exit(1);
  }

  final password = args[0];

  print('🔍 Testing WebDAV Connection...');
  print('================================');

  // Test configuration from your error logs
  final now = DateTime.now();
  final config = SyncConfig(
    id: 'terminal_test',
    displayName: 'Terminal Test',
    serverUrl:
        'https://nextcloud.promiselan.com/remote.php/dav/files/iamhyrumharris@gmail.com/',
    username: 'iamhyrumharris@gmail.com',
    lastSyncAt: now,
    createdAt: now,
    updatedAt: now,
  );

  print('📋 Configuration:');
  print('  Server URL: ${config.serverUrl}');
  print('  Username: ${config.username}');
  print('  Base Path: ${config.basePath}');
  print('');

  final webdavService = WebDAVSyncService();

  try {
    print('🚀 Starting connection test...');
    final success = await webdavService.testConnection(config, password);

    print('');
    if (success) {
      print('✅ WebDAV connection test PASSED!');
      print('🎉 Your connection is working properly.');
      print('You can now use WebDAV sync in your app.');
    } else {
      print('❌ WebDAV connection test FAILED!');
      print('Check the error messages above for details.');
      print('');
      print('💡 Common issues:');
      print('  - Incorrect password');
      print('  - Network connectivity issues');
      print('  - Server configuration problems');
    }
  } catch (e) {
    print('');
    print('💥 Unexpected error during test: $e');
    print('');
    print('💡 This might indicate:');
    print('  - Network permission issues (check macOS entitlements)');
    print('  - Flutter dependencies not properly installed');
    print('  - Invalid server configuration');
  }

  print('');
  print('🏁 Test completed.');
}
