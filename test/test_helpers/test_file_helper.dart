import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../lib/models/attachment.dart';
import 'test_data_generator.dart';

/// Helper class for managing test files and directories
class TestFileHelper {
  static String? _testRootDir;
  static final List<String> _createdPaths = [];

  /// Gets or creates the test root directory
  static Future<String> getTestRootDir() async {
    if (_testRootDir == null) {
      final tempDir = await getTemporaryDirectory();
      _testRootDir = path.join(tempDir.path, 'journal_test_${DateTime.now().millisecondsSinceEpoch}');
      await Directory(_testRootDir!).create(recursive: true);
      _createdPaths.add(_testRootDir!);
    }
    return _testRootDir!;
  }

  /// Creates a test directory structure
  static Future<String> createTestDirectory(String relativePath) async {
    final rootDir = await getTestRootDir();
    final fullPath = path.join(rootDir, relativePath);
    await Directory(fullPath).create(recursive: true);
    _createdPaths.add(fullPath);
    return fullPath;
  }

  /// Creates test files for legacy attachment scenarios
  static Future<List<File>> createLegacyTestFiles(List<Attachment> attachments) async {
    final files = <File>[];
    
    for (final attachment in attachments) {
      if (attachment.path.startsWith('/') || attachment.path.contains(':')) {
        // Create the directory structure for the absolute path
        final file = File(attachment.path);
        await file.parent.create(recursive: true);
        
        // Create test file content based on type
        switch (attachment.type) {
          case AttachmentType.photo:
            await TestDataGenerator.createTestImageFile(attachment.path);
            break;
          case AttachmentType.audio:
            await _createTestAudioFile(attachment.path);
            break;
          case AttachmentType.file:
            await _createTestDocumentFile(attachment.path);
            break;
          case AttachmentType.location:
            await _createTestLocationFile(attachment.path);
            break;
        }
        
        files.add(file);
        _createdPaths.add(attachment.path);
      }
    }
    
    return files;
  }

  /// Creates organized storage directory structure
  static Future<String> createOrganizedStorageStructure() async {
    final rootDir = await getTestRootDir();
    final storageDir = path.join(rootDir, 'journal_data');
    
    // Create type-specific directories
    final directories = ['images', 'audio', 'documents'];
    for (final dir in directories) {
      await createTestDirectory(path.join('journal_data', dir));
    }
    
    return storageDir;
  }

  /// Simulates the file structure after migration
  static Future<void> createMigratedFileStructure(List<Attachment> attachments) async {
    final storageDir = await createOrganizedStorageStructure();
    
    for (final attachment in attachments) {
      if (!attachment.path.startsWith('/') && !attachment.path.contains(':')) {
        // This is a relative path - create the file
        final fullPath = path.join(storageDir, attachment.path);
        await File(fullPath).parent.create(recursive: true);
        
        // Create test file content
        switch (attachment.type) {
          case AttachmentType.photo:
            await TestDataGenerator.createTestImageFile(fullPath);
            break;
          case AttachmentType.audio:
            await _createTestAudioFile(fullPath);
            break;
          case AttachmentType.file:
            await _createTestDocumentFile(fullPath);
            break;
          case AttachmentType.location:
            await _createTestLocationFile(fullPath);
            break;
        }
        
        _createdPaths.add(fullPath);
      }
    }
  }

  /// Creates a test audio file with basic header
  static Future<File> _createTestAudioFile(String filePath) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    
    // Create a minimal MP3 header
    final mp3Header = [
      0xFF, 0xFB, 0x90, 0x00, // MP3 sync word and header
      0x00, 0x00, 0x00, 0x00, // Dummy data
    ];
    
    final audioData = <int>[];
    audioData.addAll(mp3Header);
    
    // Add dummy audio data
    for (int i = 0; i < 1000; i++) {
      audioData.add(i % 256);
    }
    
    await file.writeAsBytes(audioData);
    return file;
  }

  /// Creates a test document file
  static Future<File> _createTestDocumentFile(String filePath) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    
    final content = '''%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj
2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj
3 0 obj
<<
/Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
>>
endobj
xref
0 4
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
trailer
<<
/Size 4
/Root 1 0 R
>>
startxref
174
%%EOF''';
    
    await file.writeAsString(content);
    return file;
  }

  /// Creates a test location file
  static Future<File> _createTestLocationFile(String filePath) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    
    final locationData = {
      'latitude': 37.7749,
      'longitude': -122.4194,
      'address': 'San Francisco, CA, USA',
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await file.writeAsString(locationData.toString());
    return file;
  }

  /// Verifies that a file exists and has expected properties
  static Future<bool> verifyFileExists(String filePath, {
    int? expectedMinSize,
    int? expectedMaxSize,
  }) async {
    final file = File(filePath);
    
    if (!await file.exists()) {
      return false;
    }
    
    if (expectedMinSize != null || expectedMaxSize != null) {
      final size = await file.length();
      
      if (expectedMinSize != null && size < expectedMinSize) {
        return false;
      }
      
      if (expectedMaxSize != null && size > expectedMaxSize) {
        return false;
      }
    }
    
    return true;
  }

  /// Checks if a file is accessible (readable)
  static Future<bool> isFileAccessible(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      return bytes.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Gets file info for testing
  static Future<Map<String, dynamic>> getFileInfo(String filePath) async {
    final file = File(filePath);
    
    if (!await file.exists()) {
      return {'exists': false};
    }
    
    final stat = await file.stat();
    
    return {
      'exists': true,
      'size': stat.size,
      'modified': stat.modified.toIso8601String(),
      'type': stat.type.toString(),
      'readable': await isFileAccessible(filePath),
    };
  }

  /// Simulates missing files (for error testing)
  static Future<void> simulateMissingFiles(List<String> filePaths) async {
    for (final filePath in filePaths) {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Simulates permission issues (Unix-like systems)
  static Future<void> simulatePermissionIssues(List<String> filePaths) async {
    if (!Platform.isLinux && !Platform.isMacOS) {
      return; // Skip on Windows
    }
    
    for (final filePath in filePaths) {
      final file = File(filePath);
      if (await file.exists()) {
        // Remove read permissions
        await Process.run('chmod', ['000', filePath]);
        _createdPaths.add(filePath); // Track for cleanup
      }
    }
  }

  /// Restores permissions (Unix-like systems)
  static Future<void> restorePermissions(List<String> filePaths) async {
    if (!Platform.isLinux && !Platform.isMacOS) {
      return; // Skip on Windows
    }
    
    for (final filePath in filePaths) {
      final file = File(filePath);
      if (await file.exists()) {
        // Restore read/write permissions
        await Process.run('chmod', ['644', filePath]);
      }
    }
  }

  /// Creates files with various corruption scenarios
  static Future<void> createCorruptedFiles(List<String> filePaths) async {
    for (final filePath in filePaths) {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      
      // Create file with invalid/corrupted content
      await file.writeAsBytes([0x00, 0xFF, 0x00, 0xFF]); // Invalid header
      _createdPaths.add(filePath);
    }
  }

  /// Measures directory size for performance tests
  static Future<int> getDirectorySize(String dirPath) async {
    final dir = Directory(dirPath);
    
    if (!await dir.exists()) {
      return 0;
    }
    
    int totalSize = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final stat = await entity.stat();
        totalSize += stat.size;
      }
    }
    
    return totalSize;
  }

  /// Counts files in directory structure
  static Future<Map<String, int>> countFiles(String dirPath) async {
    final dir = Directory(dirPath);
    final counts = <String, int>{
      'total': 0,
      'images': 0,
      'audio': 0,
      'documents': 0,
    };
    
    if (!await dir.exists()) {
      return counts;
    }
    
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        counts['total'] = (counts['total'] ?? 0) + 1;
        
        final fileName = path.basename(entity.path);
        final extension = path.extension(fileName).toLowerCase();
        
        if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(extension)) {
          counts['images'] = (counts['images'] ?? 0) + 1;
        } else if (['.mp3', '.wav', '.m4a', '.aac'].contains(extension)) {
          counts['audio'] = (counts['audio'] ?? 0) + 1;
        } else {
          counts['documents'] = (counts['documents'] ?? 0) + 1;
        }
      }
    }
    
    return counts;
  }

  /// Cleans up all test files and directories
  static Future<void> cleanup() async {
    for (final createdPath in _createdPaths.reversed) {
      try {
        final entity = FileSystemEntity.typeSync(createdPath);
        
        if (entity == FileSystemEntityType.directory) {
          final dir = Directory(createdPath);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        } else if (entity == FileSystemEntityType.file) {
          final file = File(createdPath);
          if (await file.exists()) {
            // Restore permissions before deletion (Unix systems)
            if (Platform.isLinux || Platform.isMacOS) {
              try {
                await Process.run('chmod', ['644', createdPath]);
              } catch (e) {
                // Ignore permission errors during cleanup
              }
            }
            await file.delete();
          }
        }
      } catch (e) {
        // Ignore cleanup errors - best effort
        print('Warning: Failed to cleanup $createdPath: $e');
      }
    }
    
    _createdPaths.clear();
    _testRootDir = null;
  }

  /// Creates a performance test file set
  static Future<List<File>> createPerformanceTestFiles(int fileCount, {
    int averageFileSizeKB = 500,
    int maxFileSizeKB = 2000,
  }) async {
    final files = <File>[];
    final testDir = await createTestDirectory('performance_test');
    
    for (int i = 0; i < fileCount; i++) {
      final fileName = 'perf_test_$i.jpg';
      final filePath = path.join(testDir, fileName);
      
      // Vary file sizes
      final sizeKB = averageFileSizeKB + (i % (maxFileSizeKB - averageFileSizeKB));
      final file = await TestDataGenerator.createTestImageFile(filePath);
      
      // Resize file to approximate target size
      final targetBytes = sizeKB * 1024;
      final currentBytes = await file.length();
      
      if (currentBytes < targetBytes) {
        final additionalData = Uint8List(targetBytes - currentBytes);
        for (int j = 0; j < additionalData.length; j++) {
          additionalData[j] = j % 256;
        }
        await file.writeAsBytes([...await file.readAsBytes(), ...additionalData]);
      }
      
      files.add(file);
    }
    
    return files;
  }
}