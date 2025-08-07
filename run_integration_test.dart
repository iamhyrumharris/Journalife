#!/usr/bin/env dart

/// Integration Test Runner Script
/// 
/// This script helps you run the WebDAV integration tests with your server configuration.
/// 
/// Before running:
/// 1. Update the WebDAV server configuration in the integration test file
/// 2. Make sure your WebDAV server is accessible
/// 3. Run: flutter pub get
/// 4. Run: dart run_integration_test.dart

import 'dart:io';

void main(List<String> args) async {
  print('🧪 WebDAV Integration Test Runner');
  print('=' * 50);
  
  // Check if integration_test directory exists
  final integrationTestDir = Directory('integration_test');
  if (!await integrationTestDir.exists()) {
    print('❌ integration_test directory not found!');
    print('   Make sure you\'re running this from the project root.');
    exit(1);
  }
  
  // Check if the test file exists
  final testFile = File('integration_test/webdav_sync_integration_test.dart');
  if (!await testFile.exists()) {
    print('❌ Integration test file not found!');
    print('   Expected: integration_test/webdav_sync_integration_test.dart');
    exit(1);
  }
  
  print('✅ Test files found');
  print('');
  
  // Show configuration instructions
  print('📋 Before running the tests, make sure to:');
  print('');
  print('1. Update WebDAV server configuration in the test file:');
  print('   - Open: integration_test/webdav_sync_integration_test.dart');
  print('   - Update these constants:');
  print('     const testServerUrl = \'https://your-webdav-server.com/webdav\';');
  print('     const testUsername = \'your-username\';');  
  print('     const testPassword = \'your-password\';');
  print('');
  print('2. Ensure your WebDAV server is accessible');
  print('3. Run: flutter pub get (if not done already)');
  print('');
  
  // Ask user if they want to continue
  print('Have you updated the configuration? (y/N): ');
  final input = stdin.readLineSync()?.toLowerCase();
  if (input != 'y' && input != 'yes') {
    print('Please update the configuration and run again.');
    exit(0);
  }
  
  print('');
  print('🚀 Running integration tests...');
  print('');
  
  // Determine platform and run appropriate command
  String device;
  if (Platform.isMacOS) {
    device = 'macos';
  } else if (Platform.isLinux) {
    device = 'linux';  
  } else if (Platform.isWindows) {
    device = 'windows';
  } else {
    print('❌ Unsupported platform for desktop integration tests');
    exit(1);
  }
  
  // Run the integration test
  final process = await Process.start(
    'flutter',
    [
      'test',
      'integration_test/webdav_sync_integration_test.dart',
      '-d',
      device,
      '--verbose'
    ],
  );
  
  // Forward output to console
  process.stdout.listen((data) => stdout.add(data));
  process.stderr.listen((data) => stderr.add(data));
  
  final exitCode = await process.exitCode;
  
  if (exitCode == 0) {
    print('');
    print('🎉 Integration tests completed successfully!');
    print('');
    print('Your WebDAV sync is working correctly:');
    print('✅ Journal entries can be created and synced');  
    print('✅ Attachments are properly uploaded');
    print('✅ Bidirectional sync is functional');
    print('✅ Server directory structure is correct');
  } else {
    print('');
    print('❌ Integration tests failed');
    print('');
    print('Common issues:');
    print('• Check WebDAV server URL, username, and password');
    print('• Verify server is accessible from your machine');
    print('• Ensure WebDAV permissions allow file/folder creation');
    print('• Check network connectivity');
    print('');
    print('For detailed logs, check the test output above.');
  }
  
  exit(exitCode);
}