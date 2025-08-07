#!/usr/bin/env dart

/// Standalone WebDAV verification script
/// Run this to independently verify your WebDAV server structure
/// 
/// Usage: dart webdav_verification_script.dart <server_url> <username> <password>

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:webdav_client/webdav_client.dart' as webdav;

void main(List<String> args) async {
  if (args.length != 3) {
    print('Usage: dart webdav_verification_script.dart <server_url> <username> <password>');
    print('Example: dart webdav_verification_script.dart https://myserver.com/webdav myuser mypass');
    exit(1);
  }

  final serverUrl = args[0];
  final username = args[1];
  final password = args[2];
  
  print('🔍 WebDAV Server Verification');
  print('=' * 50);
  print('Server: $serverUrl');
  print('Username: $username');
  print('Password: ${'*' * password.length}');
  print('');

  try {
    final client = webdav.newClient(
      serverUrl,
      user: username,
      password: password,
      debug: true,
    );

    // Test connection
    print('1. Testing connection...');
    await client.ping();
    print('✅ Connection successful');
    print('');

    // Define expected structure
    final basePath = '/journal_app/${username}_data';
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');

    final expectedDirs = [
      basePath,
      '$basePath/journals',
      '$basePath/entries',
      '$basePath/entries/$year',
      '$basePath/entries/$year/$month',
      '$basePath/attachments',
      '$basePath/attachments/$year',
      '$basePath/attachments/$year/$month',
      '$basePath/attachments/$year/$month/$day',
      '$basePath/photos',
      '$basePath/photos/$year',
      '$basePath/photos/$year/$month',
      '$basePath/photos/$year/$month/$day',
      '$basePath/audio',
      '$basePath/audio/$year',
      '$basePath/audio/$year/$month',
      '$basePath/audio/$year/$month/$day',
      '$basePath/temp',
    ];

    // Verify directory structure
    print('2. Verifying directory structure...');
    final missingDirs = <String>[];
    final existingDirs = <String>[];

    for (final dir in expectedDirs) {
      try {
        await client.readDir(dir);
        existingDirs.add(dir);
        print('✅ $dir');
      } catch (e) {
        missingDirs.add(dir);
        print('❌ $dir (missing)');
      }
    }

    print('');
    print('📊 Summary:');
    print('✅ Existing directories: ${existingDirs.length}');
    print('❌ Missing directories: ${missingDirs.length}');
    print('');

    if (missingDirs.isNotEmpty) {
      print('🔧 Creating missing directories...');
      for (final dir in missingDirs) {
        try {
          await client.mkdir(dir);
          print('✅ Created: $dir');
        } catch (e) {
          print('❌ Failed to create $dir: $e');
        }
      }
      print('');
    }

    // Generate complete structure report
    print('3. Complete directory structure:');
    print('=' * 30);
    await _listDirectoryRecursively(client, basePath, 0);
    print('');

    // Test file operations
    print('4. Testing file operations...');
    final testFile = '$basePath/temp/verification_test.json';
    final testData = {
      'test': 'WebDAV verification',
      'timestamp': DateTime.now().toIso8601String(),
      'username': username,
    };
    
    try {
      // Write test file
      await client.write(testFile, Uint8List.fromList(utf8.encode(jsonEncode(testData))));
      print('✅ File write successful');
      
      // Read test file
      final readBytes = await client.read(testFile);
      final readData = jsonDecode(utf8.decode(readBytes));
      print('✅ File read successful');
      
      // Verify content
      if (readData['test'] == 'WebDAV verification') {
        print('✅ File content verified');
      } else {
        print('❌ File content verification failed');
      }
      
      // Clean up
      await client.remove(testFile);
      print('✅ File cleanup successful');
      
    } catch (e) {
      print('❌ File operations failed: $e');
    }

    print('');
    print('🎉 WebDAV verification complete!');

  } catch (e) {
    print('❌ Verification failed: $e');
    exit(1);
  }
}

/// Recursively list directory contents
Future<void> _listDirectoryRecursively(webdav.Client client, String dirPath, int depth) async {
  const maxDepth = 3;
  if (depth > maxDepth) return;
  
  try {
    final contents = await client.readDir(dirPath);
    final indent = '  ' * depth;
    
    for (final item in contents) {
      final itemName = item.name ?? 'unnamed';
      final itemPath = '$dirPath/$itemName';
      
      if (item.isDir ?? false) {
        print('$indent📁 $itemName/');
        await _listDirectoryRecursively(client, itemPath, depth + 1);
      } else {
        final size = item.size != null ? ' (${_formatBytes(item.size!)})' : '';
        print('$indent📄 $itemName$size');
      }
    }
    
    if (contents.isEmpty && depth > 0) {
      print('$indent(empty)');
    }
  } catch (e) {
    final indent = '  ' * depth;
    print('$indent❌ Error: $e');
  }
}

/// Format bytes in human-readable format
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}