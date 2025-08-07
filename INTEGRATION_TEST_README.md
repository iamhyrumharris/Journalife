# WebDAV Integration Tests

This directory contains comprehensive integration tests that verify the WebDAV sync functionality works end-to-end with a real WebDAV server.

## What the Tests Do

### Test 1: Complete Journal Entry Sync
- ✅ Creates a test journal in the local database
- ✅ Creates a journal entry with multiple attachment types:
  - 📷 Photo attachment (fake JPEG with metadata)
  - 🎵 Audio attachment (fake M4A with duration info)  
  - 📄 File attachment (fake PDF with page count)
  - 📍 Location attachment (GPS coordinates)
- ✅ Configures WebDAV sync and performs full sync
- ✅ Verifies all data exists on the WebDAV server:
  - Journal metadata in correct JSON format
  - Entry data with all fields preserved
  - All attachment files uploaded to organized directory structure
  - File sizes and content integrity verified

### Test 2: Bidirectional Sync Verification  
- ✅ Modifies an entry directly on the WebDAV server
- ✅ Performs sync to pull changes back to local app
- ✅ Verifies local database was updated with server changes
- ✅ Confirms bidirectional sync is working correctly

## Directory Structure Verified

The tests verify this complete directory structure is created on your WebDAV server:

```
/journal_app/{username}_data/
├── 📄 journals_metadata.json          (Journal definitions)
├── 📁 journals/
├── 📁 entries/
│   └── 📁 2024/12/
│       └── 📄 entries.json             (Entry data by month)
├── 📁 attachments/
│   └── 📁 2024/12/07/
│       └── 📁 {entry-id}/
│           └── 📄 test-document.pdf    (File attachments)
├── 📁 photos/
│   └── 📁 2024/12/07/
│       └── 📁 {entry-id}/
│           └── 📄 test-photo.jpg       (Photo attachments)
├── 📁 audio/
│   └── 📁 2024/12/07/
│       └── 📁 {entry-id}/
│           └── 📄 test-recording.m4a   (Audio attachments)
└── 📁 temp/
    └── 📄 verification_test.json       (Temp files)
```

## Setup Instructions

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Configure WebDAV Server Details
Edit `integration_test/webdav_sync_integration_test.dart` and update these constants:

```dart
// Test configuration - UPDATE THESE VALUES
const testServerUrl = 'https://your-webdav-server.com/webdav';
const testUsername = 'your-username';  
const testPassword = 'your-password';
```

**Important:** Use a test server or test account, as the tests will create and delete files.

### 3. WebDAV Server Requirements
Your WebDAV server must support:
- ✅ Directory creation (`MKCOL`)
- ✅ File upload/download (`PUT`/`GET`) 
- ✅ File deletion (`DELETE`)
- ✅ Directory listing (`PROPFIND`)
- ✅ Basic authentication

Popular compatible servers:
- Nextcloud/ownCloud
- Apache WebDAV
- nginx WebDAV
- Synology NAS
- QNAP NAS

## Running the Tests

### Option 1: Using the Test Runner (Recommended)
```bash
dart run_integration_test.dart
```

The runner will:
- Check your configuration
- Guide you through setup
- Run tests with proper device selection
- Provide detailed success/failure feedback

### Option 2: Direct Flutter Command
```bash
# macOS
flutter test integration_test/webdav_sync_integration_test.dart -d macos

# Windows  
flutter test integration_test/webdav_sync_integration_test.dart -d windows

# Linux
flutter test integration_test/webdav_sync_integration_test.dart -d linux
```

## Expected Output

### Successful Test Run
```
🧪 WebDAV Integration Test Runner
==================================================
✅ Test files found

🚀 Running integration tests...

📓 Created test journal: Test Journal for WebDAV Sync
📝 Created test entry: Integration Test Entry  
📎 Entry has 4 attachments
⚙️ Created WebDAV sync configuration
🔄 Performing WebDAV sync...
Sync status: uploading - Uploading entry data...
Sync status: completed - Sync completed successfully
✅ WebDAV sync completed
🔍 Verifying entry on WebDAV server...
✅ Entry verified on server
🔍 Verifying 4 attachments on server...
📁 Created test file: test-photo.jpg (51200 bytes)
📁 Created test file: test-recording.m4a (204800 bytes)  
📁 Created test file: test-document.pdf (102400 bytes)
✅ Attachment verified: test-photo.jpg (51200 bytes)
✅ Attachment verified: test-recording.m4a (204800 bytes)
✅ Attachment verified: test-document.pdf (102400 bytes)
✅ All attachments verified on server
🔍 Verifying journal metadata on server...
✅ Journal metadata verified on server
🎉 Integration test passed - entry verified on WebDAV server!

🎉 Integration tests completed successfully!

Your WebDAV sync is working correctly:
✅ Journal entries can be created and synced
✅ Attachments are properly uploaded  
✅ Bidirectional sync is functional
✅ Server directory structure is correct
```

## Troubleshooting

### Common Issues

**Authentication Failed (401)**
- Verify username and password are correct
- Check if account is locked or expired
- Some servers require app-specific passwords

**Permission Denied (403)**  
- User account needs WebDAV write permissions
- Check folder creation permissions on server
- Verify user can create files in WebDAV root

**Server Not Found (404)**
- Check server URL is correct and accessible
- Verify WebDAV is enabled on the server  
- Test server URL in a web browser first

**Network Timeout**
- Check internet connectivity
- Server may be slow or overloaded
- Try increasing timeout values in test

**Directory Creation Failed**
- User may need admin privileges
- Check available disk space on server
- Some servers have restricted folder creation

### Debug Mode
Add `debug: true` to WebDAV client configuration in test for detailed HTTP logs:

```dart
webdavClient = webdav.newClient(
  testServerUrl,
  user: testUsername,
  password: testPassword,
  debug: true, // Enable detailed logging
);
```

### Manual Verification
After tests run, you can manually check your WebDAV server to see:
1. Directory structure was created correctly
2. Files were uploaded with proper sizes
3. JSON files contain correct entry data

## Cleanup

The tests automatically clean up all created data, but if interrupted you may need to manually delete:
- `/journal_app/{username}_data/` directory on your WebDAV server

## Security Notes

- ⚠️ Never commit real WebDAV credentials to version control
- ⚠️ Use test servers/accounts for integration testing  
- ⚠️ Tests create and delete data - don't use production servers
- ⚠️ Consider using environment variables for credentials

## Next Steps

Once integration tests pass:
1. Your WebDAV sync is fully functional
2. You can safely use the app with your WebDAV server
3. All journal entries and attachments will sync properly
4. The app handles bidirectional sync correctly