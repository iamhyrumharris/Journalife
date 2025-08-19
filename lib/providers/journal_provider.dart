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

  Future<void> loadJournals() async {
    try {
      state = const AsyncValue.loading();
      final journals = await _databaseService.getAllJournals();
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

}