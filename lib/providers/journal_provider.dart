import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/journal.dart';
import '../services/database_service.dart';
import 'database_provider.dart';

final journalProvider = StateNotifierProvider<JournalNotifier, AsyncValue<List<Journal>>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return JournalNotifier(databaseService);
});

final currentJournalProvider = StateProvider<Journal?>((ref) => null);

class JournalNotifier extends StateNotifier<AsyncValue<List<Journal>>> {
  final DatabaseService _databaseService;
  final _uuid = const Uuid();

  JournalNotifier(this._databaseService) : super(const AsyncValue.loading()) {
    loadJournals();
  }

  Future<void> loadJournals([String? userId]) async {
    try {
      state = const AsyncValue.loading();
      // For now, use a default user ID - this will be replaced with actual auth
      final effectiveUserId = userId ?? 'default-user';
      final journals = await _databaseService.getJournalsForUser(effectiveUserId);
      state = AsyncValue.data(journals);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> createJournal({
    required String name,
    required String description,
    String? color,
    String? icon,
  }) async {
    try {
      final journal = Journal(
        id: _uuid.v4(),
        name: name,
        description: description,
        ownerId: 'default-user', // Replace with actual user ID
        sharedWithUserIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        color: color,
        icon: icon,
      );

      await _databaseService.insertJournal(journal);
      await loadJournals();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateJournal(Journal journal) async {
    try {
      final updatedJournal = journal.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateJournal(updatedJournal);
      await loadJournals();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteJournal(String journalId) async {
    try {
      await _databaseService.deleteJournal(journalId);
      await loadJournals();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> shareJournal(String journalId, String userId) async {
    try {
      final journal = await _databaseService.getJournal(journalId);
      if (journal != null) {
        final updatedSharedUsers = [...journal.sharedWithUserIds];
        if (!updatedSharedUsers.contains(userId)) {
          updatedSharedUsers.add(userId);
          final updatedJournal = journal.copyWith(
            sharedWithUserIds: updatedSharedUsers,
            updatedAt: DateTime.now(),
          );
          await _databaseService.updateJournal(updatedJournal);
          await loadJournals();
        }
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> unshareJournal(String journalId, String userId) async {
    try {
      final journal = await _databaseService.getJournal(journalId);
      if (journal != null) {
        final updatedSharedUsers = [...journal.sharedWithUserIds];
        updatedSharedUsers.remove(userId);
        final updatedJournal = journal.copyWith(
          sharedWithUserIds: updatedSharedUsers,
          updatedAt: DateTime.now(),
        );
        await _databaseService.updateJournal(updatedJournal);
        await loadJournals();
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}