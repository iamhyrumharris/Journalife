import 'package:flutter/material.dart';
import '../services/file_migration_service.dart';

/// Dialog widget for file migration with progress tracking and user control
class FileMigrationDialog extends StatefulWidget {
  const FileMigrationDialog({super.key});

  @override
  State<FileMigrationDialog> createState() => _FileMigrationDialogState();
}

class _FileMigrationDialogState extends State<FileMigrationDialog> {
  final FileMigrationService _migrationService = FileMigrationService();
  
  bool _isMigrating = false;
  bool _migrationComplete = false;
  int _currentProgress = 0;
  int _totalFiles = 0;
  String _currentStatus = '';
  MigrationResult? _result;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadMigrationStats();
  }

  Future<void> _loadMigrationStats() async {
    final stats = await _migrationService.getMigrationStats();
    setState(() {
      _stats = stats;
    });
  }

  Future<void> _startMigration({bool dryRun = false}) async {
    setState(() {
      _isMigrating = true;
      _migrationComplete = false;
      _currentProgress = 0;
      _totalFiles = 0;
      _currentStatus = 'Preparing migration...';
    });

    final result = await _migrationService.migrateAllFiles(
      dryRun: dryRun,
      onProgress: (current, total, status) {
        setState(() {
          _currentProgress = current;
          _totalFiles = total;
          _currentStatus = status;
        });
      },
    );

    setState(() {
      _isMigrating = false;
      _migrationComplete = true;
      _result = result;
    });

    // Reload stats after migration
    await _loadMigrationStats();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.drive_file_move, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('File Migration'),
          if (_stats?['migration_needed'] == false) ...[ 
            const Spacer(),
            Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_stats != null) _buildStatsSection(),
            const SizedBox(height: 16),
            
            if (_isMigrating) _buildMigrationProgress(),
            if (_migrationComplete && _result != null) _buildMigrationResult(),
            if (!_isMigrating && !_migrationComplete) _buildMigrationPrompt(),
          ],
        ),
      ),
      actions: _buildActionButtons(),
    );
  }

  Widget _buildStatsSection() {
    final stats = _stats!;
    final needsMigration = stats['migration_needed'] as bool;
    final legacyCount = stats['legacy_count'] as int;
    final migratedCount = stats['migrated_count'] as int;
    final totalCount = stats['total_count'] as int;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Migration Status',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          if (needsMigration) ...[ 
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text('$legacyCount files need migration'),
              ],
            ),
            const SizedBox(height: 4),
          ],
          
          Row(
            children: [
              Icon(
                needsMigration ? Icons.pending : Icons.check_circle,
                color: needsMigration ? Colors.blue : Colors.green,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text('$migratedCount files already migrated'),
            ],
          ),
          const SizedBox(height: 4),
          
          Text(
            'Total attachments: $totalCount',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationPrompt() {
    final needsMigration = _stats?['migration_needed'] as bool? ?? false;
    
    if (!needsMigration) {
      return Column(
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text('All files are already using the new storage system.'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'No migration is needed. Your files are organized and ready for cloud sync.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This will migrate your existing images to the new organized storage system. This ensures:',
        ),
        const SizedBox(height: 8),
        
        ...[
          '• Better organization with date-based folders',
          '• Cloud sync compatibility',
          '• Improved performance and reliability',
          '• Future-proof file management',
        ].map((benefit) => Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Text(
            benefit,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        )),
        
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your original files will be copied to the new location and remain safe.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMigrationProgress() {
    final progress = _totalFiles > 0 ? _currentProgress / _totalFiles : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentStatus,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
        const SizedBox(height: 8),
        
        Text(
          '$_currentProgress of $_totalFiles files',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMigrationResult() {
    final result = _result!;
    final isSuccess = result.failed == 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.warning,
              color: isSuccess ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(
              isSuccess ? 'Migration Completed Successfully!' : 'Migration Completed with Issues',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isSuccess ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        _buildResultStat('Total files', result.totalAttachments.toString()),
        _buildResultStat('Successfully migrated', result.migratedSuccessfully.toString()),
        _buildResultStat('Already migrated', result.alreadyMigrated.toString()),
        if (result.failed > 0)
          _buildResultStat('Failed', result.failed.toString(), isError: true),
        _buildResultStat('Duration', '${result.duration.inSeconds}s'),
        
        if (result.hasErrors) ...[ 
          const SizedBox(height: 12),
          Text(
            'Errors:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 100),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: result.errors.map((error) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• $error',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red[700],
                    ),
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultStat(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isError ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    if (_isMigrating) {
      return [
        TextButton(
          onPressed: null,
          child: const Text('Migrating...'),
        ),
      ];
    }

    if (_migrationComplete) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (_result?.failed != 0)
          TextButton(
            onPressed: () => _startMigration(),
            child: const Text('Retry Failed'),
          ),
      ];
    }

    final needsMigration = _stats?['migration_needed'] as bool? ?? false;
    
    if (!needsMigration) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => _startMigration(dryRun: true),
        child: const Text('Preview'),
      ),
      ElevatedButton(
        onPressed: () => _startMigration(),
        child: const Text('Start Migration'),
      ),
    ];
  }
}