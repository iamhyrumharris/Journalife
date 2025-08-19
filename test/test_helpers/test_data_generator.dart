import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:journal_new/models/attachment.dart';
import 'package:journal_new/models/entry.dart';
import 'package:journal_new/models/journal.dart';

/// Utility class for generating test data for migration and sharing tests
class TestDataGenerator {
  static const Uuid _uuid = Uuid();


  /// Creates a test journal
  static Journal createTestJournal({
    String? id,
    String? name,
    String? description,
  }) {
    return Journal(
      id: id ?? _uuid.v4(),
      name: name ?? 'Test Journal ${DateTime.now().millisecondsSinceEpoch}',
      description: description ?? 'A test journal for testing purposes',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Creates a test entry
  static Entry createTestEntry({
    String? id,
    String? journalId,
    String? title,
    String? content,
    List<String>? tags,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? createdAt,
    List<Attachment>? attachments,
  }) {
    return Entry(
      id: id ?? _uuid.v4(),
      journalId: journalId ?? _uuid.v4(),
      title: title ?? 'Test Entry ${DateTime.now().millisecondsSinceEpoch}',
      content: content ?? 'This is a test entry content for testing purposes.',
      tags: tags ?? ['test', 'sample', 'generated'],
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      attachments: attachments ?? [],
    );
  }

  /// Creates a test attachment with legacy absolute path
  static Attachment createLegacyAttachment({
    String? id,
    String? entryId,
    AttachmentType? type,
    String? name,
    String? absolutePath,
    int? size,
    String? mimeType,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    final attachmentId = id ?? _uuid.v4();
    final attachmentType = type ?? AttachmentType.photo;
    final fileName = name ?? 'test_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    // Generate a realistic absolute path based on platform
    String legacyPath;
    if (Platform.isMacOS) {
      legacyPath = absolutePath ?? '/Users/testuser/Pictures/$fileName';
    } else if (Platform.isWindows) {
      legacyPath = absolutePath ?? 'C:\\Users\\testuser\\Pictures\\$fileName';
    } else {
      legacyPath = absolutePath ?? '/home/testuser/Pictures/$fileName';
    }

    return Attachment(
      id: attachmentId,
      entryId: entryId ?? _uuid.v4(),
      type: attachmentType,
      name: fileName,
      path: legacyPath, // This is the legacy absolute path
      size: size ?? 1024 * 500, // 500KB default
      mimeType: mimeType ?? _getMimeTypeForType(attachmentType),
      createdAt: createdAt ?? DateTime.now(),
      metadata: metadata ?? {
        'legacy': true,
        'platform': Platform.operatingSystem,
        'originalPath': legacyPath,
      },
    );
  }

  /// Creates a test attachment with modern relative path
  static Attachment createModernAttachment({
    String? id,
    String? entryId,
    AttachmentType? type,
    String? name,
    String? relativePath,
    int? size,
    String? mimeType,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    final attachmentId = id ?? _uuid.v4();
    final attachmentType = type ?? AttachmentType.photo;
    final fileName = name ?? 'test_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final entryDate = createdAt ?? DateTime.now();
    final effectiveEntryId = entryId ?? _uuid.v4();
    
    // Generate modern relative path structure
    final typeDir = _getTypeDirName(attachmentType);
    final dateDir = '${entryDate.year}/${entryDate.month.toString().padLeft(2, '0')}/${entryDate.day.toString().padLeft(2, '0')}';
    final modernPath = relativePath ?? '$typeDir/$dateDir/$effectiveEntryId/$fileName';

    return Attachment(
      id: attachmentId,
      entryId: effectiveEntryId,
      type: attachmentType,
      name: fileName,
      path: modernPath, // This is the modern relative path
      size: size ?? 1024 * 500, // 500KB default
      mimeType: mimeType ?? _getMimeTypeForType(attachmentType),
      createdAt: entryDate,
      metadata: metadata ?? {
        'storageType': 'organized',
        'platform': Platform.operatingSystem,
        'migrated': true,
      },
    );
  }

  /// Creates a physical test file at the specified path
  static Future<File> createTestFile(String filePath, {
    int sizeBytes = 1024,
    String? content,
  }) async {
    final file = File(filePath);
    
    // Ensure parent directory exists
    await file.parent.create(recursive: true);
    
    if (content != null) {
      await file.writeAsString(content);
    } else {
      // Create dummy binary data
      final bytes = Uint8List(sizeBytes);
      for (int i = 0; i < sizeBytes; i++) {
        bytes[i] = i % 256;
      }
      await file.writeAsBytes(bytes);
    }
    
    return file;
  }

  /// Creates a test image file with fake JPEG header
  static Future<File> createTestImageFile(String filePath, {
    int width = 100,
    int height = 100,
  }) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    
    // Create a minimal JPEG file with basic headers
    final jpegHeader = [
      0xFF, 0xD8, 0xFF, 0xE0, // JPEG SOI and APP0 marker
      0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, // JFIF header
      0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, // Resolution info
    ];
    
    // Add some dummy image data
    final imageData = <int>[];
    imageData.addAll(jpegHeader);
    
    // Add dummy scan data
    for (int i = 0; i < 1000; i++) {
      imageData.add(i % 256);
    }
    
    // End of image marker
    imageData.addAll([0xFF, 0xD9]);
    
    await file.writeAsBytes(imageData);
    return file;
  }

  /// Creates multiple test entries with various attachment scenarios
  static List<Entry> createMigrationTestDataset({
    int entryCount = 10,
    int attachmentsPerEntry = 2,
    double legacyRatio = 0.7, // 70% legacy, 30% modern
  }) {
    final entries = <Entry>[];
    
    for (int i = 0; i < entryCount; i++) {
      final entry = createTestEntry(
        title: 'Migration Test Entry $i',
        content: 'Entry $i with test attachments for migration testing.',
        createdAt: DateTime.now().subtract(Duration(days: i)),
      );
      
      final attachments = <Attachment>[];
      for (int j = 0; j < attachmentsPerEntry; j++) {
        final isLegacy = (i * attachmentsPerEntry + j) / (entryCount * attachmentsPerEntry) < legacyRatio;
        
        if (isLegacy) {
          attachments.add(createLegacyAttachment(
            entryId: entry.id,
            name: 'legacy_attachment_${i}_$j.jpg',
            createdAt: entry.createdAt,
          ));
        } else {
          attachments.add(createModernAttachment(
            entryId: entry.id,
            name: 'modern_attachment_${i}_$j.jpg',
            createdAt: entry.createdAt,
          ));
        }
      }
      
      // Update entry with attachments
      entry.attachments.addAll(attachments);
      entries.add(entry);
    }
    
    return entries;
  }

  /// Creates test data for performance benchmarking
  static List<Entry> createPerformanceTestDataset({
    int entryCount = 1000,
    int maxAttachmentsPerEntry = 10,
  }) {
    final entries = <Entry>[];
    
    for (int i = 0; i < entryCount; i++) {
      final attachmentCount = (i % maxAttachmentsPerEntry) + 1;
      final entry = createTestEntry(
        title: 'Performance Test Entry $i',
        content: 'Large dataset entry $i for performance testing with $attachmentCount attachments.',
        createdAt: DateTime.now().subtract(Duration(hours: i)),
      );
      
      final attachments = <Attachment>[];
      for (int j = 0; j < attachmentCount; j++) {
        // Mix of attachment types
        final type = AttachmentType.values[j % AttachmentType.values.length];
        attachments.add(createLegacyAttachment(
          entryId: entry.id,
          type: type,
          name: 'perf_attachment_${i}_$j.${_getExtensionForType(type)}',
          size: (j + 1) * 1024 * 100, // Varying sizes
          createdAt: entry.createdAt,
        ));
      }
      
      entry.attachments.addAll(attachments);
      entries.add(entry);
    }
    
    return entries;
  }

  /// Helper: Get MIME type for attachment type
  static String _getMimeTypeForType(AttachmentType type) {
    switch (type) {
      case AttachmentType.photo:
        return 'image/jpeg';
      case AttachmentType.audio:
        return 'audio/mpeg';
      case AttachmentType.file:
        return 'application/pdf';
      case AttachmentType.location:
        return 'application/json';
    }
  }

  /// Helper: Get file extension for attachment type
  static String _getExtensionForType(AttachmentType type) {
    switch (type) {
      case AttachmentType.photo:
        return 'jpg';
      case AttachmentType.audio:
        return 'mp3';
      case AttachmentType.file:
        return 'pdf';
      case AttachmentType.location:
        return 'json';
    }
  }

  /// Helper: Get directory name for attachment type
  static String _getTypeDirName(AttachmentType type) {
    switch (type) {
      case AttachmentType.photo:
        return 'images';
      case AttachmentType.audio:
        return 'audio';
      case AttachmentType.file:
        return 'documents';
      case AttachmentType.location:
        return 'documents';
    }
  }
}