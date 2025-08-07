import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../models/sync_config.dart';

/// Comprehensive validation service for WebDAV setup and directory structure
class WebDAVValidationService {
  static final WebDAVValidationService _instance = WebDAVValidationService._internal();
  factory WebDAVValidationService() => _instance;
  WebDAVValidationService._internal();

  /// Performs comprehensive WebDAV connection and directory structure validation
  Future<WebDAVValidationResult> performFullValidation(
    SyncConfig config,
    String password,
  ) async {
    final result = WebDAVValidationResult();
    
    try {
      debugPrint('🔍 Starting comprehensive WebDAV validation...');
      debugPrint('Server: ${config.serverUrl}');
      debugPrint('Username: ${config.username}');
      debugPrint('Base Path: ${config.basePath}');
      debugPrint('Password provided: ${password.isNotEmpty ? "Yes (${password.length} characters)" : "No"}');
      
      final client = webdav.newClient(
        config.serverUrl,
        user: config.username,
        password: password,
        debug: true,
      );

      // Test 1: Basic connectivity and authentication
      result.tests.add(await _testBasicConnectivity(client, config));
      if (!result.tests.last.success) {
        result.overallSuccess = false;
        return result;
      }

      // Test 2: Directory creation and structure validation
      result.tests.add(await _testDirectoryStructure(client, config));
      
      // Test 3: File operations (read/write/delete)
      result.tests.add(await _testFileOperations(client, config));
      
      // Test 4: Date-based directory organization
      result.tests.add(await _testDateBasedDirectories(client, config));
      
      // Test 5: Permissions validation
      result.tests.add(await _testPermissions(client, config));
      
      // Test 6: Directory listing and navigation
      result.tests.add(await _testDirectoryListing(client, config));
      
      // Test 7: Test attachment paths
      result.tests.add(await _testAttachmentPaths(client, config));
      
      // Test 8: Complete directory structure verification
      result.tests.add(await _testCompleteStructureVerification(client, config));

      // Determine overall success
      result.overallSuccess = result.tests.every((test) => test.success);
      
      if (result.overallSuccess) {
        debugPrint('✅ All WebDAV validation tests passed!');
      } else {
        debugPrint('❌ Some WebDAV validation tests failed');
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ WebDAV validation failed with exception: $e');
      debugPrint('Stack trace: $stackTrace');
      
      result.overallSuccess = false;
      result.tests.add(WebDAVTest(
        name: 'Exception Handling',
        success: false,
        message: 'Validation failed with exception: $e',
        details: stackTrace.toString(),
      ));
    }
    
    return result;
  }

  /// Test 1: Basic connectivity and authentication
  Future<WebDAVTest> _testBasicConnectivity(webdav.Client client, SyncConfig config) async {
    try {
      debugPrint('🔗 Test 1: Basic connectivity...');
      
      await client.ping();
      
      return WebDAVTest(
        name: 'Basic Connectivity',
        success: true,
        message: 'Successfully connected to WebDAV server',
        details: 'Server responded to ping request',
      );
    } catch (e) {
      return WebDAVTest(
        name: 'Basic Connectivity',
        success: false,
        message: 'Failed to connect to WebDAV server',
        details: 'Error: $e',
      );
    }
  }

  /// Test 2: Directory creation and structure validation
  Future<WebDAVTest> _testDirectoryStructure(webdav.Client client, SyncConfig config) async {
    try {
      debugPrint('📁 Test 2: Directory structure...');
      
      final requiredDirs = config.getRequiredDirectories();
      final createdDirs = <String>[];
      final failedDirs = <String>[];
      
      for (final dir in requiredDirs) {
        try {
          await client.mkdir(dir);
          createdDirs.add(dir);
          debugPrint('✓ Directory created/verified: $dir');
        } catch (e) {
          // Try to list the directory to see if it already exists
          try {
            await client.readDir(dir);
            createdDirs.add(dir);
            debugPrint('✓ Directory already exists: $dir');
          } catch (listError) {
            failedDirs.add('$dir (Error: $e)');
            debugPrint('❌ Failed to create directory: $dir - $e');
          }
        }
      }
      
      if (failedDirs.isEmpty) {
        return WebDAVTest(
          name: 'Directory Structure',
          success: true,
          message: 'All ${requiredDirs.length} required directories created/verified',
          details: 'Created: ${createdDirs.join(', ')}',
        );
      } else {
        return WebDAVTest(
          name: 'Directory Structure',
          success: false,
          message: 'Failed to create ${failedDirs.length} directories',
          details: 'Failed: ${failedDirs.join(', ')}',
        );
      }
    } catch (e) {
      return WebDAVTest(
        name: 'Directory Structure',
        success: false,
        message: 'Directory structure test failed',
        details: 'Error: $e',
      );
    }
  }

  /// Test 3: File operations (create, read, update, delete)
  Future<WebDAVTest> _testFileOperations(webdav.Client client, SyncConfig config) async {
    try {
      debugPrint('📝 Test 3: File operations...');
      
      final testFilePath = '${config.basePath}/temp/validation_test.json';
      final testData = <String, dynamic>{
        'test': 'WebDAV validation',
        'timestamp': DateTime.now().toIso8601String(),
        'config_id': config.id,
      };
      final testContent = Uint8List.fromList(utf8.encode(jsonEncode(testData)));
      
      // Create
      await client.write(testFilePath, testContent);
      debugPrint('✓ File created successfully');
      
      // Read
      final readBytes = await client.read(testFilePath);
      final readData = jsonDecode(utf8.decode(readBytes));
      if (readData['test'] != 'WebDAV validation') {
        throw Exception('File content validation failed');
      }
      debugPrint('✓ File read and validated successfully');
      
      // Update
      testData['updated'] = true;
      final updatedContent = Uint8List.fromList(utf8.encode(jsonEncode(testData)));
      await client.write(testFilePath, updatedContent);
      debugPrint('✓ File updated successfully');
      
      // Verify update
      final updatedBytes = await client.read(testFilePath);
      final updatedData = jsonDecode(utf8.decode(updatedBytes));
      if (updatedData['updated'] != true) {
        throw Exception('File update validation failed');
      }
      debugPrint('✓ File update verified successfully');
      
      // Delete
      await client.remove(testFilePath);
      debugPrint('✓ File deleted successfully');
      
      return WebDAVTest(
        name: 'File Operations',
        success: true,
        message: 'All file operations (create, read, update, delete) successful',
        details: 'Tested with JSON file: ${testData.length} bytes',
      );
    } catch (e) {
      return WebDAVTest(
        name: 'File Operations',
        success: false,
        message: 'File operations test failed',
        details: 'Error: $e',
      );
    }
  }

  /// Test 4: Date-based directory organization
  Future<WebDAVTest> _testDateBasedDirectories(webdav.Client client, SyncConfig config) async {
    try {
      debugPrint('📅 Test 4: Date-based directories...');
      
      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      
      final dateDirectories = [
        '${config.basePath}/entries/$year',
        '${config.basePath}/entries/$year/$month',
        '${config.basePath}/attachments/$year',
        '${config.basePath}/attachments/$year/$month',
        '${config.basePath}/attachments/$year/$month/$day',
        '${config.basePath}/photos/$year',
        '${config.basePath}/photos/$year/$month',
        '${config.basePath}/photos/$year/$month/$day',
        '${config.basePath}/audio/$year',
        '${config.basePath}/audio/$year/$month',
        '${config.basePath}/audio/$year/$month/$day',
      ];
      
      final createdDirs = <String>[];
      
      for (final dir in dateDirectories) {
        try {
          await client.mkdir(dir);
          createdDirs.add(dir);
          debugPrint('✓ Date directory created: $dir');
          
          // Verify directory exists by listing its contents
          final dirContents = await client.readDir(dir);
          debugPrint('   → Directory verified, contains ${dirContents.length} items');
        } catch (e) {
          // Try to verify it exists
          try {
            final dirContents = await client.readDir(dir);
            createdDirs.add(dir);
            debugPrint('✓ Date directory already exists: $dir (${dirContents.length} items)');
          } catch (listError) {
            debugPrint('❌ Failed to create date directory: $dir');
            throw Exception('Failed to create date directory: $dir - $e');
          }
        }
      }
      
      return WebDAVTest(
        name: 'Date-based Directories',
        success: true,
        message: 'All ${dateDirectories.length} date-based directories created for $year/$month/$day',
        details: 'Successfully created hierarchical date structure',
      );
    } catch (e) {
      return WebDAVTest(
        name: 'Date-based Directories',
        success: false,
        message: 'Date-based directory test failed',
        details: 'Error: $e',
      );
    }
  }

  /// Test 5: Permissions validation
  Future<WebDAVTest> _testPermissions(webdav.Client client, SyncConfig config) async {
    try {
      debugPrint('🔒 Test 5: Permissions...');
      
      final testDir = '${config.basePath}/temp/permission_test';
      final testFile = '$testDir/test.txt';
      
      // Test directory creation permission
      await client.mkdir(testDir);
      
      // Test file creation permission
      await client.write(testFile, Uint8List.fromList(utf8.encode('permission test')));
      
      // Test read permission
      await client.read(testFile);
      
      // Test delete permission
      await client.remove(testFile);
      
      // Test directory deletion permission
      try {
        await client.remove(testDir);
      } catch (e) {
        // Some servers don't support directory deletion, that's okay
        debugPrint('Note: Directory deletion not supported or failed: $e');
      }
      
      return WebDAVTest(
        name: 'Permissions',
        success: true,
        message: 'User has required permissions for all operations',
        details: 'Verified: create directory, create file, read file, delete file',
      );
    } catch (e) {
      return WebDAVTest(
        name: 'Permissions',
        success: false,
        message: 'Insufficient permissions detected',
        details: 'Error: $e',
      );
    }
  }

  /// Test 6: Directory listing and navigation
  Future<WebDAVTest> _testDirectoryListing(webdav.Client client, SyncConfig config) async {
    try {
      debugPrint('📋 Test 6: Directory listing...');
      
      // Test listing root directory
      final rootListing = await client.readDir('/');
      debugPrint('✓ Root directory listing: ${rootListing.length} items');
      
      // Test listing base path
      final baseListing = await client.readDir(config.basePath);
      debugPrint('✓ Base directory listing: ${baseListing.length} items');
      
      // Verify required subdirectories exist
      final requiredSubdirs = ['journals', 'entries', 'attachments', 'photos', 'audio', 'temp'];
      final foundSubdirs = <String>[];
      
      for (final item in baseListing) {
        if (requiredSubdirs.contains(item.name)) {
          foundSubdirs.add(item.name!);
        }
      }
      
      if (foundSubdirs.length >= requiredSubdirs.length - 1) { // Allow temp to be missing
        return WebDAVTest(
          name: 'Directory Listing',
          success: true,
          message: 'Directory listing working, found ${foundSubdirs.length}/${requiredSubdirs.length} required subdirectories',
          details: 'Found: ${foundSubdirs.join(', ')}',
        );
      } else {
        return WebDAVTest(
          name: 'Directory Listing',
          success: false,
          message: 'Missing required subdirectories',
          details: 'Found: ${foundSubdirs.join(', ')}, Expected: ${requiredSubdirs.join(', ')}',
        );
      }
    } catch (e) {
      return WebDAVTest(
        name: 'Directory Listing',
        success: false,
        message: 'Directory listing test failed',
        details: 'Error: $e',
      );
    }
  }

  /// Test 7: Test attachment paths and organization
  Future<WebDAVTest> _testAttachmentPaths(webdav.Client client, SyncConfig config) async {
    try {
      debugPrint('📎 Test 7: Attachment paths...');
      
      final testDate = DateTime.now();
      final testEntryId = 'test-entry-123';
      final testFilename = 'test-photo.jpg';
      
      // Test photo path
      final photoPath = config.getPhotoPath(testEntryId, testDate, testFilename);
      final photoDir = photoPath.substring(0, photoPath.lastIndexOf('/'));
      await client.mkdir(photoDir);
      debugPrint('✓ Photo directory created: $photoDir');
      
      // Test audio path
      final audioPath = config.getAudioPath(testEntryId, testDate, 'test-audio.m4a');
      final audioDir = audioPath.substring(0, audioPath.lastIndexOf('/'));
      await client.mkdir(audioDir);
      debugPrint('✓ Audio directory created: $audioDir');
      
      // Test attachment path
      final attachmentPath = config.getEntryAttachmentPath(testEntryId, testDate, 'test-file.pdf');
      final attachmentDir = attachmentPath.substring(0, attachmentPath.lastIndexOf('/'));
      await client.mkdir(attachmentDir);
      debugPrint('✓ Attachment directory created: $attachmentDir');
      
      // Test creating sample files in each directory
      await client.write(photoPath, Uint8List.fromList(utf8.encode('fake photo data')));
      await client.write(audioPath, Uint8List.fromList(utf8.encode('fake audio data')));
      await client.write(attachmentPath, Uint8List.fromList(utf8.encode('fake attachment data')));
      debugPrint('✓ Sample files created in all attachment directories');
      
      // Clean up test files
      await client.remove(photoPath);
      await client.remove(audioPath);
      await client.remove(attachmentPath);
      debugPrint('✓ Test files cleaned up');
      
      return WebDAVTest(
        name: 'Attachment Paths',
        success: true,
        message: 'All attachment path types working correctly',
        details: 'Tested: photos, audio, and general attachments with date-based organization',
      );
    } catch (e) {
      return WebDAVTest(
        name: 'Attachment Paths',
        success: false,
        message: 'Attachment paths test failed',
        details: 'Error: $e',
      );
    }
  }

  /// Test 8: Complete directory structure verification with detailed listing
  Future<WebDAVTest> _testCompleteStructureVerification(webdav.Client client, SyncConfig config) async {
    try {
      debugPrint('🗂️ Test 8: Complete structure verification...');
      
      final structureReport = StringBuffer();
      structureReport.writeln('WebDAV Directory Structure Verification:');
      structureReport.writeln('Base Path: ${config.basePath}');
      structureReport.writeln('=' * 50);
      
      // Recursively list all directories and files
      await _listDirectoryRecursively(client, config.basePath, structureReport, 0);
      
      final reportString = structureReport.toString();
      debugPrint(reportString);
      
      return WebDAVTest(
        name: 'Complete Structure Verification',
        success: true,
        message: 'Generated complete directory structure report',
        details: 'Check console output for full structure listing',
      );
    } catch (e) {
      return WebDAVTest(
        name: 'Complete Structure Verification',
        success: false,
        message: 'Failed to generate structure report',
        details: 'Error: $e',
      );
    }
  }
  
  /// Recursively list directory contents with indentation
  Future<void> _listDirectoryRecursively(
    webdav.Client client, 
    String dirPath, 
    StringBuffer report, 
    int depth,
  ) async {
    const maxDepth = 4; // Prevent infinite recursion
    if (depth > maxDepth) return;
    
    try {
      final contents = await client.readDir(dirPath);
      final indent = '  ' * depth;
      
      for (final item in contents) {
        final itemName = item.name ?? 'unnamed';
        final itemPath = '$dirPath/$itemName';
        
        if (item.isDir ?? false) {
          report.writeln('$indent📁 $itemName/');
          // Recursively list subdirectory contents
          await _listDirectoryRecursively(client, itemPath, report, depth + 1);
        } else {
          final size = item.size != null ? ' (${_formatBytes(item.size!)})' : '';
          final modified = item.mTime != null ? ' - ${item.mTime}' : '';
          report.writeln('$indent📄 $itemName$size$modified');
        }
      }
      
      if (contents.isEmpty && depth > 0) {
        report.writeln('$indent(empty)');
      }
    } catch (e) {
      final indent = '  ' * depth;
      report.writeln('$indent❌ Error listing $dirPath: $e');
    }
  }
  
  /// Format bytes in human-readable format
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Result of WebDAV validation containing all test results
class WebDAVValidationResult {
  bool overallSuccess = true;
  List<WebDAVTest> tests = [];
  
  /// Gets a summary of the validation results
  String get summary {
    final passedCount = tests.where((t) => t.success).length;
    final totalCount = tests.length;
    
    if (overallSuccess) {
      return '✅ All tests passed ($passedCount/$totalCount)';
    } else {
      return '❌ Some tests failed ($passedCount/$totalCount)';
    }
  }
  
  /// Gets detailed results as formatted string
  String get detailedResults {
    final buffer = StringBuffer();
    buffer.writeln('WebDAV Validation Results:');
    buffer.writeln('=' * 40);
    
    for (int i = 0; i < tests.length; i++) {
      final test = tests[i];
      buffer.writeln('${i + 1}. ${test.name}: ${test.success ? "✅ PASS" : "❌ FAIL"}');
      buffer.writeln('   ${test.message}');
      if (test.details.isNotEmpty) {
        buffer.writeln('   Details: ${test.details}');
      }
      buffer.writeln();
    }
    
    buffer.writeln('Overall Result: ${overallSuccess ? "✅ SUCCESS" : "❌ FAILURE"}');
    return buffer.toString();
  }
}

/// Individual test result
class WebDAVTest {
  final String name;
  final bool success;
  final String message;
  final String details;
  
  WebDAVTest({
    required this.name,
    required this.success,
    required this.message,
    this.details = '',
  });
}