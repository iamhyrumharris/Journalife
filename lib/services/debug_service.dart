import 'dart:io';
import 'package:flutter/material.dart';

enum DebugLevel { INFO, WARNING, ERROR, CRITICAL }

class DebugLog {
  final DateTime timestamp;
  final DebugLevel level;
  final String category;
  final String message;
  final Map<String, dynamic>? data;

  DebugLog({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.data,
  });

  @override
  String toString() {
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
    final dataStr = data != null ? ' | Data: $data' : '';
    return '[$timeStr] [${level.name}] [$category] $message$dataStr';
  }
}

class DebugService {
  static final List<DebugLog> _logs = [];
  static const int maxLogs = 100;
  
  /// Debug mode can be enabled for development/testing
  static bool isDebugMode = false;

  /// Log an info message
  static void info(String category, String message, [Map<String, dynamic>? data]) {
    _addLog(DebugLevel.INFO, category, message, data);
  }

  /// Log a warning message
  static void warning(String category, String message, [Map<String, dynamic>? data]) {
    _addLog(DebugLevel.WARNING, category, message, data);
  }

  /// Log an error message
  static void error(String category, String message, [Map<String, dynamic>? data]) {
    _addLog(DebugLevel.ERROR, category, message, data);
  }

  /// Log a critical error message
  static void critical(String category, String message, [Map<String, dynamic>? data]) {
    _addLog(DebugLevel.CRITICAL, category, message, data);
  }

  /// Add a log entry
  static void _addLog(DebugLevel level, String category, String message, Map<String, dynamic>? data) {
    if (!isDebugMode) return; // Skip logging when debug mode is off
    
    final log = DebugLog(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      data: data,
    );

    _logs.add(log);
    
    // Keep only recent logs
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }

    // Print to console for development
    debugPrint('[DEBUG] ${log.toString()}');
  }

  /// Get all logs
  static List<DebugLog> get logs => List.unmodifiable(_logs);

  /// Get logs by level
  static List<DebugLog> getLogsByLevel(DebugLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  /// Get logs by category
  static List<DebugLog> getLogsByCategory(String category) {
    return _logs.where((log) => log.category == category).toList();
  }

  /// Clear all logs
  static void clearLogs() {
    _logs.clear();
    info('DebugService', 'Logs cleared');
  }

  /// Get system information
  static Map<String, dynamic> getSystemInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'environment': Platform.environment,
      'isMacOS': Platform.isMacOS,
      'isAndroid': Platform.isAndroid,
      'isIOS': Platform.isIOS,
      'isWindows': Platform.isWindows,
      'isLinux': Platform.isLinux,
      'dartVersion': Platform.version,
    };
  }

  /// Log system information
  static void logSystemInfo() {
    final info = getSystemInfo();
    DebugService.info('System', 'Platform information', info);
  }

  /// Show debug info in a snackbar (only when debug mode is enabled)
  static void showDebugSnackbar(BuildContext context, String message, {DebugLevel level = DebugLevel.INFO}) {
    if (!isDebugMode) return; // Skip showing debug UI when debug mode is off
    
    Color backgroundColor;
    switch (level) {
      case DebugLevel.INFO:
        backgroundColor = Colors.blue;
        break;
      case DebugLevel.WARNING:
        backgroundColor = Colors.orange;
        break;
      case DebugLevel.ERROR:
        backgroundColor = Colors.red;
        break;
      case DebugLevel.CRITICAL:
        backgroundColor = Colors.purple;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('[DEBUG] $message'),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'LOGS',
          textColor: Colors.white,
          onPressed: () => showDebugDialog(context),
        ),
      ),
    );
  }

  /// Show debug dialog with recent logs (only when debug mode is enabled)
  static void showDebugDialog(BuildContext context) {
    if (!isDebugMode) return; // Skip showing debug UI when debug mode is off
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform: ${Platform.operatingSystem}'),
              Text('Logs: ${_logs.length}'),
              const SizedBox(height: 16),
              const Text('Recent Logs:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _logs.length,
                  reverse: true, // Show newest first
                  itemBuilder: (context, index) {
                    final log = _logs[_logs.length - 1 - index];
                    Color textColor;
                    switch (log.level) {
                      case DebugLevel.INFO:
                        textColor = Colors.blue;
                        break;
                      case DebugLevel.WARNING:
                        textColor = Colors.orange;
                        break;
                      case DebugLevel.ERROR:
                        textColor = Colors.red;
                        break;
                      case DebugLevel.CRITICAL:
                        textColor = Colors.purple;
                        break;
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        log.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => clearLogs(),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}