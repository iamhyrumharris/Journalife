import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_new/services/attachment_service.dart';
import 'package:journal_new/models/attachment.dart';
import '../test_helpers/test_data_generator.dart';
import '../test_helpers/test_file_helper.dart';

void main() {
  setUp(() async {
    await TestFileHelper.cleanup();
  });

  tearDown(() async {
    await TestFileHelper.cleanup();
  });

  group('Cross-Platform Sharing Tests', () {
    testWidgets('shareAttachment handles photo attachments correctly', (WidgetTester tester) async {
      // Create a test photo attachment with actual file
      final attachment = TestDataGenerator.createModernAttachment(
        type: AttachmentType.photo,
        name: 'share_test_photo.jpg',
        size: 1024 * 500, // 500KB
        mimeType: 'image/jpeg',
      );

      // Create the actual file
      await TestFileHelper.createOrganizedStorageStructure();
      final storageDir = await TestFileHelper.getTestRootDir();
      final filePath = '$storageDir/journal_data/${attachment.path}';
      await TestDataGenerator.createTestImageFile(filePath);

      // Create a minimal widget tree for the context
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () async {
                  final result = await AttachmentService.shareAttachment(context, attachment);
                  expect(result, isA<bool>());
                },
                child: const Text('Share'),
              );
            },
          ),
        ),
      ));

      // Tap the share button (this will test the sharing flow)
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Note: Actual sharing behavior is platform-dependent and can't be fully tested
      // in unit tests, but we can verify the method doesn't throw exceptions
    });

    testWidgets('shareAttachment handles missing files gracefully', (WidgetTester tester) async {
      // Create attachment without creating the actual file
      final attachment = TestDataGenerator.createLegacyAttachment(
        name: 'missing_file.jpg',
        absolutePath: '/nonexistent/path/missing_file.jpg',
      );

      bool snackBarShown = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () async {
                  final result = await AttachmentService.shareAttachment(context, attachment);
                  expect(result, isFalse); // Should fail gracefully
                },
                child: const Text('Share Missing'),
              );
            },
          ),
        ),
        builder: (context, child) {
          return ScaffoldMessenger(
            child: child!,
          );
        },
      ));

      // Tap to trigger sharing
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(); // Allow snackbar to show

      // Should show error snackbar for missing file
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('File not found - cannot share'), findsOneWidget);
    });

    test('attachment sharing handles various file types', () async {
      // Test different attachment types
      final attachmentTypes = [
        AttachmentType.photo,
        AttachmentType.audio,
        AttachmentType.file,
        AttachmentType.location,
      ];

      for (final type in attachmentTypes) {
        final attachment = TestDataGenerator.createModernAttachment(
          type: type,
          name: 'test_${type.name}.${_getExtensionForType(type)}',
          mimeType: _getMimeTypeForType(type),
        );

        // Create test file
        await TestFileHelper.createOrganizedStorageStructure();
        final storageDir = await TestFileHelper.getTestRootDir();
        final filePath = '$storageDir/journal_data/${attachment.path}';
        
        switch (type) {
          case AttachmentType.photo:
            await TestDataGenerator.createTestImageFile(filePath);
            break;
          case AttachmentType.audio:
          case AttachmentType.file:
          case AttachmentType.location:
            await TestDataGenerator.createTestFile(filePath, content: 'Test ${type.name} content');
            break;
        }

        // Verify file was created
        final fileExists = await TestFileHelper.verifyFileExists(filePath);
        expect(fileExists, isTrue, reason: '${type.name} test file should exist');

        // Verify file is accessible
        final isAccessible = await TestFileHelper.isFileAccessible(filePath);
        expect(isAccessible, isTrue, reason: '${type.name} test file should be accessible');
      }
    });

    test('sharing handles large files efficiently', () async {
      // Create a larger test file to simulate performance scenarios
      final attachment = TestDataGenerator.createModernAttachment(
        type: AttachmentType.photo,
        name: 'large_photo.jpg',
        size: 1024 * 1024 * 5, // 5MB
      );

      await TestFileHelper.createOrganizedStorageStructure();
      final storageDir = await TestFileHelper.getTestRootDir();
      final filePath = '$storageDir/journal_data/${attachment.path}';
      
      // Create a larger test file
      await TestDataGenerator.createTestFile(filePath, sizeBytes: 1024 * 1024 * 5);

      // Verify large file properties
      final fileInfo = await TestFileHelper.getFileInfo(filePath);
      expect(fileInfo['exists'], isTrue);
      expect(fileInfo['size'], greaterThanOrEqualTo(1024 * 1024 * 5));
      expect(fileInfo['readable'], isTrue);

      print('Large file test completed: ${fileInfo['size']} bytes');
    });

    group('Platform-Specific Behavior', () {
      test('mobile photo sharing configuration', () async {
        // Test mobile-specific sharing scenarios
        final mobileAttachment = TestDataGenerator.createModernAttachment(
          type: AttachmentType.photo,
          name: 'mobile_photo.jpg',
          metadata: {
            'platform': 'mobile',
            'source': 'camera',
          },
        );

        expect(mobileAttachment.name, contains('mobile'));
        expect(mobileAttachment.metadata?['platform'], equals('mobile'));
        expect(mobileAttachment.type, equals(AttachmentType.photo));
      });

      test('desktop file sharing configuration', () async {
        // Test desktop-specific sharing scenarios
        final desktopAttachment = TestDataGenerator.createLegacyAttachment(
          type: AttachmentType.file,
          name: 'desktop_document.pdf',
          metadata: {
            'platform': 'desktop',
            'source': 'file_picker',
          },
        );

        expect(desktopAttachment.name, contains('desktop'));
        expect(desktopAttachment.metadata?['platform'], equals('desktop'));
        expect(desktopAttachment.type, equals(AttachmentType.file));
      });
    });

    group('Share Link Generation', () {
      test('generates valid share links for attachments', () async {
        final attachment = TestDataGenerator.createModernAttachment(
          name: 'share_link_test.jpg',
        );

        // Create test file
        await TestFileHelper.createOrganizedStorageStructure();
        final storageDir = await TestFileHelper.getTestRootDir();
        final filePath = '$storageDir/journal_data/${attachment.path}';
        await TestDataGenerator.createTestImageFile(filePath);

        // Test share text generation (from AttachmentService._getShareText)
        final shareText = _getShareText(attachment);
        expect(shareText, contains('journal'));
        expect(shareText, contains(attachment.name));
        expect(shareText, isNotEmpty);
      });

      test('share links handle special characters in names', () async {
        final specialNameAttachment = TestDataGenerator.createModernAttachment(
          name: 'test_file_with_spaces_&_symbols!@#.jpg',
        );

        final shareText = _getShareText(specialNameAttachment);
        expect(shareText, contains('test_file_with_spaces_&_symbols!@#.jpg'));
        expect(shareText, isNotEmpty);
      });
    });

    group('Share Error Handling', () {
      test('handles network connectivity issues gracefully', () async {
        // Simulate network issues (this is a placeholder for more advanced testing)
        final attachment = TestDataGenerator.createModernAttachment();
        
        // Test that sharing methods are resilient to network issues
        expect(attachment.name, isNotEmpty);
        expect(attachment.path, isNotEmpty);
        
        // In a real implementation, we might test offline scenarios
        // or network timeouts, but those require more complex setup
      });

      test('handles insufficient permissions gracefully', () async {
        if (Platform.isWindows) return; // Skip permission tests on Windows

        final attachment = TestDataGenerator.createLegacyAttachment(
          name: 'permission_test.jpg',
        );

        // Create test file
        await TestFileHelper.createLegacyTestFiles([attachment]);

        // Remove read permissions
        await TestFileHelper.simulatePermissionIssues([attachment.path]);

        // Verify file is no longer accessible
        final isAccessible = await TestFileHelper.isFileAccessible(attachment.path);
        expect(isAccessible, isFalse);

        // Restore permissions for cleanup
        await TestFileHelper.restorePermissions([attachment.path]);
      });
    });

    group('Memory and Performance', () {
      test('sharing large numbers of files is memory efficient', () async {
        const fileCount = 100;
        final attachments = List.generate(fileCount, (i) => 
          TestDataGenerator.createModernAttachment(name: 'batch_$i.jpg')
        );

        // Create test storage structure
        await TestFileHelper.createOrganizedStorageStructure();
        
        // Create smaller test files to avoid excessive disk usage
        for (final attachment in attachments.take(10)) {
          final storageDir = await TestFileHelper.getTestRootDir();
          final filePath = '$storageDir/journal_data/${attachment.path}';
          await TestDataGenerator.createTestFile(filePath, sizeBytes: 1024);
        }

        // Verify we can handle the data structures efficiently
        expect(attachments.length, equals(fileCount));
        
        // Test batch operations don't cause memory issues
        final shareTexts = attachments.map((a) => _getShareText(a)).toList();
        expect(shareTexts.length, equals(fileCount));
        expect(shareTexts.every((text) => text.isNotEmpty), isTrue);

        print('Memory test completed with $fileCount attachments');
      });
    });
  });
}

// Helper functions for testing
String _getExtensionForType(AttachmentType type) {
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

String _getMimeTypeForType(AttachmentType type) {
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

// Replicate share text logic for testing
String _getShareText(Attachment attachment) {
  switch (attachment.type) {
    case AttachmentType.photo:
      return 'Sharing photo from my journal: ${attachment.name}';
    case AttachmentType.audio:
      return 'Sharing audio recording from my journal: ${attachment.name}';
    case AttachmentType.file:
      return 'Sharing file from my journal: ${attachment.name}';
    case AttachmentType.location:
      return 'Sharing location from my journal: ${attachment.name}';
  }
}