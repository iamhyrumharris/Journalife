#!/usr/bin/env dart

/// Simple WebDAV connection test
/// Verifies the WebDAV server configured in the integration test can be reached

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:webdav_client/webdav_client.dart' as webdav;

void main() async {
  // Configuration from integration test
  const serverUrl = 'https://nextcloud.promiselan.com/remote.php/dav/files/iamhyrumharris@gmail.com';
  const username = 'iamhyrumharris@gmail.com';
  const password = r'broJoe123@#$';

  print('🔍 Testing WebDAV Connection');
  print('=' * 50);
  print('Server: $serverUrl');
  print('Username: $username');
  print('Password: ${'*' * password.length}');
  print('');

  try {
    // Create WebDAV client
    final client = webdav.newClient(
      serverUrl,
      user: username,
      password: password,
      debug: false,
    );

    print('1. Testing basic connection...');
    await client.ping();
    print('✅ Connection successful');
    print('');

    print('2. Testing directory operations...');
    final testDir = '/test_directory_${DateTime.now().millisecondsSinceEpoch}';
    
    // Create test directory
    await client.mkdir(testDir);
    print('✅ Directory creation successful');
    
    // List directory contents to verify it exists
    final contents = await client.readDir('/');
    final testDirExists = contents.any((item) => item.name?.contains('test_directory') == true);
    if (testDirExists) {
      print('✅ Directory listing successful');
    } else {
      print('⚠️ Directory created but not visible in listing');
    }

    print('');
    print('3. Testing file operations...');
    final testFile = '$testDir/test_file.txt';
    final testContent = 'This is a test file created at ${DateTime.now()}';
    
    // Create test file
    await client.write(testFile, Uint8List.fromList(utf8.encode(testContent)));
    print('✅ File write successful');
    
    // Read test file
    final readBytes = await client.read(testFile);
    final readContent = utf8.decode(readBytes);
    if (readContent == testContent) {
      print('✅ File read and verification successful');
    } else {
      print('❌ File content mismatch');
    }

    print('');
    print('4. Cleanup...');
    // Clean up test directory
    await client.remove(testDir);
    print('✅ Cleanup successful');

    print('');
    print('🎉 WebDAV connection test completed successfully!');
    print('Your server is ready for integration testing.');

  } catch (e, stackTrace) {
    print('❌ WebDAV connection test failed:');
    print('Error: $e');
    print('Stack trace:');
    print(stackTrace);
    exit(1);
  }
}