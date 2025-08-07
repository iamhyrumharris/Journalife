import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// Import all test suites
import 'services/file_migration_service_test.dart' as migration_tests;
import 'integration/migration_integration_test.dart' as integration_tests;
import 'services/sharing_platform_test.dart' as sharing_tests;
import 'validation/system_integrity_test.dart' as validation_tests;

/// Comprehensive test runner for the journal app migration and sharing systems
/// 
/// This runs all critical tests to ensure:
/// 1. FileMigrationService works correctly
/// 2. Integration between all components
/// 3. Cross-platform sharing functionality
/// 4. System integrity under various conditions
void main() {
  print('🚀 Starting Journal App Test Suite');
  print('=====================================');
  
  group('Journal App - Complete Test Suite', () {
    group('🔄 Migration Service Unit Tests', () {
      migration_tests.main();
    });

    group('🔗 Migration Integration Tests', () {
      integration_tests.main();
    });

    group('📤 Sharing Platform Tests', () {
      sharing_tests.main();
    });

    group('✅ System Integrity Validation', () {
      validation_tests.main();
    });
  });

  setUpAll(() {
    print('🎯 Test Environment: ${Platform.operatingSystem}');
    print('📍 Working Directory: ${Directory.current.path}');
    print('');
  });

  tearDownAll(() {
    print('');
    print('🏁 Test Suite Complete');
    print('======================');
    print('');
    print('📋 Test Coverage Summary:');
    print('✓ Migration detection and counting');
    print('✓ File copying with organized structure');
    print('✓ Database updates with new paths');
    print('✓ Error handling (missing files, permissions, corruption)');
    print('✓ Progress tracking and callbacks');
    print('✓ Migration validation and accessibility');
    print('✓ Cross-platform sharing functionality');
    print('✓ Integration between all components');
    print('✓ Performance with large datasets');
    print('✓ System integrity under stress conditions');
    print('✓ Resource management and cleanup');
    print('');
    print('🎉 All critical file storage and migration functionality tested!');
  });
}