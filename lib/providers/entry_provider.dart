import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/entry.dart';
import '../models/attachment.dart';
import '../services/database_service.dart';
import 'database_provider.dart';

final entryProvider = StateNotifierProvider.family<EntryNotifier, AsyncValue<List<Entry>>, String>((ref, journalId) {
  final databaseService = ref.watch(databaseServiceProvider);
  return EntryNotifier(databaseService, journalId);
});

final currentEntryProvider = StateProvider<Entry?>((ref) => null);

class EntryNotifier extends StateNotifier<AsyncValue<List<Entry>>> {
  final DatabaseService _databaseService;
  final String _journalId;
  final _uuid = const Uuid();

  EntryNotifier(this._databaseService, this._journalId) : super(const AsyncValue.loading()) {
    loadEntries();
  }

  Future<void> loadEntries() async {
    try {
      state = const AsyncValue.loading();
      final entries = await _databaseService.getEntriesForJournal(_journalId);
      state = AsyncValue.data(entries);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> createEntry({
    String? id,
    required String title,
    required String content,
    List<String>? tags,
    int? rating,
    double? latitude,
    double? longitude,
    String? locationName,
    List<Attachment>? attachments,
  }) async {
    try {
      final entry = Entry(
        id: id ?? _uuid.v4(),
        journalId: _journalId,
        title: title,
        content: content,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tags: tags ?? [],
        rating: rating,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        attachments: attachments ?? [],
      );

      await _databaseService.insertEntry(entry);
      await loadEntries();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateEntry(Entry entry) async {
    try {
      final updatedEntry = entry.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateEntry(updatedEntry);
      await loadEntries();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteEntry(String entryId) async {
    try {
      await _databaseService.deleteEntry(entryId);
      await loadEntries();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<List<Entry>> getEntriesForDateRange(DateTime startDate, DateTime endDate) async {
    return await _databaseService.getEntriesForDateRange(
      journalId: _journalId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<Entry>> searchEntries(String query) async {
    return await _databaseService.searchEntries(
      journalId: _journalId,
      query: query,
    );
  }

  Future<Entry?> getEntry(String entryId) async {
    return await _databaseService.getEntry(entryId);
  }

  Future<void> addAttachmentToEntry(String entryId, Attachment attachment) async {
    try {
      final entry = await _databaseService.getEntry(entryId);
      if (entry != null) {
        final updatedAttachments = [...entry.attachments, attachment];
        final updatedEntry = entry.copyWith(
          attachments: updatedAttachments,
          updatedAt: DateTime.now(),
        );
        await _databaseService.updateEntry(updatedEntry);
        await loadEntries();
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> removeAttachmentFromEntry(String entryId, String attachmentId) async {
    try {
      final entry = await _databaseService.getEntry(entryId);
      if (entry != null) {
        final updatedAttachments = entry.attachments
            .where((a) => a.id != attachmentId)
            .toList();
        final updatedEntry = entry.copyWith(
          attachments: updatedAttachments,
          updatedAt: DateTime.now(),
        );
        await _databaseService.updateEntry(updatedEntry);
        await loadEntries();
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}