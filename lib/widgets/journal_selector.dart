import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/journal.dart';
import '../providers/journal_provider.dart';
import '../screens/journals/journal_list_screen.dart';
import '../screens/journals/journal_edit_screen.dart';
import '../screens/journals/journal_settings_screen.dart';

class JournalSelector extends ConsumerWidget {
  final bool showAllJournals;
  final bool isAppBarTitle;

  const JournalSelector({
    super.key,
    this.showAllJournals = false,
    this.isAppBarTitle = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalsAsync = ref.watch(journalProvider);
    final currentJournal = ref.watch(currentJournalProvider);

    return journalsAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Loading journals...'),
          ],
        ),
      ),
      error: (error, stack) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.error, size: 16, color: Colors.red),
            const SizedBox(width: 8),
            const Expanded(child: Text('Error loading journals')),
            TextButton(
              onPressed: () => ref.read(journalProvider.notifier).loadJournals(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (journals) {
        if (journals.isEmpty) {
          return _buildEmptySelector(context);
        }

        if (showAllJournals) {
          return _buildJournalGrid(context, ref, journals, currentJournal);
        } else if (isAppBarTitle) {
          return _buildAppBarTitle(context, ref, journals, currentJournal);
        } else {
          return _buildCompactSelector(context, ref, journals, currentJournal);
        }
      },
    );
  }

  Widget _buildEmptySelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.book, color: Colors.grey),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'No journals yet',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton.icon(
            onPressed: () => _navigateToJournalManagement(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle(
    BuildContext context,
    WidgetRef ref,
    List<Journal> journals,
    Journal? currentJournal,
  ) {
    final effectiveJournal = currentJournal ?? journals.first;
    
    // Auto-select first journal if none selected
    if (currentJournal == null && journals.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currentJournalProvider.notifier).state = effectiveJournal;
      });
    }

    return GestureDetector(
      onTap: () => _showJournalSwitchModal(context, ref, journals, effectiveJournal),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildJournalIcon(effectiveJournal, size: 24),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              effectiveJournal.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSelector(
    BuildContext context,
    WidgetRef ref,
    List<Journal> journals,
    Journal? currentJournal,
  ) {
    final effectiveJournal = currentJournal ?? journals.first;
    
    // Auto-select first journal if none selected
    if (currentJournal == null && journals.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currentJournalProvider.notifier).state = effectiveJournal;
      });
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildJournalIcon(effectiveJournal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  effectiveJournal.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (journals.length > 1)
                  Text(
                    '${journals.length} journals',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, ref, value, effectiveJournal),
            itemBuilder: (context) => [
              if (journals.length > 1)
                const PopupMenuItem(
                  value: 'switch',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz),
                      SizedBox(width: 8),
                      Text('Switch Journal'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'manage',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Manage Journals'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'create',
                child: Row(
                  children: [
                    Icon(Icons.add),
                    SizedBox(width: 8),
                    Text('Create Journal'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJournalGrid(
    BuildContext context,
    WidgetRef ref,
    List<Journal> journals,
    Journal? currentJournal,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Journal',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () => _navigateToJournalManagement(context),
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: journals.length,
            itemBuilder: (context, index) {
              final journal = journals[index];
              final isSelected = currentJournal?.id == journal.id;
              
              return _buildJournalTile(context, ref, journal, isSelected);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildJournalTile(
    BuildContext context,
    WidgetRef ref,
    Journal journal,
    bool isSelected,
  ) {
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: () => _selectJournal(ref, journal),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildJournalIcon(journal, size: 24),
                  const Spacer(),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                journal.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected 
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (journal.description.isNotEmpty)
                Text(
                  journal.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                        : Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJournalIcon(Journal journal, {double size = 32}) {
    if (journal.icon != null) {
      return Text(
        journal.icon!,
        style: TextStyle(fontSize: size),
      );
    } else {
      final color = journal.color != null
          ? Color(int.parse(journal.color!, radix: 16))
          : Colors.blue;
      
      return Container(
        width: size + 8,
        height: size + 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          Icons.book,
          color: Colors.white,
          size: size * 0.6,
        ),
      );
    }
  }

  void _selectJournal(WidgetRef ref, Journal journal) {
    ref.read(currentJournalProvider.notifier).state = journal;
  }

  void _navigateToJournalManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JournalListScreen(),
      ),
    );
  }

  void _navigateToJournalCreation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JournalEditScreen(), // null journal = create new
      ),
    );
  }

  void _navigateToJournalSettings(BuildContext context, Journal journal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalSettingsScreen(journal: journal),
      ),
    );
  }

  void _showJournalSwitchModal(BuildContext context, WidgetRef ref, List<Journal> journals, Journal currentJournal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Journal',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: journals.map((journal) {
                  final isSelected = currentJournal.id == journal.id;
                  
                  return ListTile(
                    leading: _buildJournalIcon(journal, size: 24),
                    title: Text(journal.name),
                    subtitle: journal.description.isNotEmpty ? Text(journal.description) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.settings, size: 20),
                          onPressed: () {
                            Navigator.pop(context);
                            _navigateToJournalSettings(context, journal);
                          },
                          tooltip: 'Journal Settings',
                        ),
                        const SizedBox(width: 8),
                        if (isSelected) const Icon(Icons.check, color: Colors.blue),
                      ],
                    ),
                    onTap: () {
                      if (!isSelected) {
                        _selectJournal(ref, journal);
                      }
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
              title: const Text('Create New Journal', style: TextStyle(color: Colors.blue)),
              onTap: () {
                Navigator.pop(context);
                _navigateToJournalCreation(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    Journal currentJournal,
  ) {
    switch (action) {
      case 'switch':
        _showJournalSwitcher(context, ref);
        break;
      case 'manage':
        _navigateToJournalManagement(context);
        break;
      case 'create':
        // Navigate to create journal - will be handled by JournalListScreen
        _navigateToJournalManagement(context);
        break;
    }
  }

  void _showJournalSwitcher(BuildContext context, WidgetRef ref) {
    final journalsAsync = ref.read(journalProvider);
    
    journalsAsync.whenData((journals) {
      showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Switch Journal',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...journals.map((journal) {
                final isSelected = ref.read(currentJournalProvider)?.id == journal.id;
                
                return ListTile(
                  leading: _buildJournalIcon(journal, size: 24),
                  title: Text(journal.name),
                  subtitle: journal.description.isNotEmpty ? Text(journal.description) : null,
                  trailing: isSelected ? const Icon(Icons.check) : null,
                  onTap: () {
                    _selectJournal(ref, journal);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      );
    });
  }
}