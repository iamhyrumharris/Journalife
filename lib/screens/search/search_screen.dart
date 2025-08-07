import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/entry.dart';
import '../../models/journal.dart';
import '../../providers/journal_provider.dart';
import '../../providers/entry_provider.dart';
import '../../widgets/journal_selector.dart';
import '../entry/entry_view_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<Entry> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journalsAsync = ref.watch(journalProvider);
    final currentJournal = ref.watch(currentJournalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          if (_searchResults.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSearch,
              tooltip: 'Clear search',
            ),
        ],
      ),
      body: journalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(journalProvider.notifier).loadJournals(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (journals) {
          if (journals.isEmpty) {
            return _buildEmptyState(ref);
          }

          // Use first journal if no current journal selected
          final effectiveJournal = currentJournal ?? journals.first;
          
          // Set current journal if not set
          if (currentJournal == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(currentJournalProvider.notifier).state = effectiveJournal;
            });
          }

          return Column(
            children: [
              const JournalSelector(),
              
              // Search bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search entries, tags, locations...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _clearSearch();
                              _focusNode.requestFocus();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (query) {
                    if (query.isNotEmpty) {
                      _performSearch(effectiveJournal.id, query);
                    } else {
                      _clearSearch();
                    }
                  },
                  onSubmitted: (query) {
                    if (query.isNotEmpty) {
                      _performSearch(effectiveJournal.id, query);
                    }
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              Expanded(
                child: _buildSearchContent(effectiveJournal),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.book, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No journals yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first journal to get started',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateJournalDialog(ref),
            icon: const Icon(Icons.add),
            label: const Text('Create Journal'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchContent(Journal journal) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return _buildSearchSuggestions(journal);
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or check your spelling',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                _clearSearch();
                _focusNode.requestFocus();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Clear Search'),
            ),
          ],
        ),
      );
    }

    return _buildSearchResultsList();
  }

  Widget _buildSearchSuggestions(Journal journal) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.search, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Search in ${journal.name}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find entries by title, content, tags, or location',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          
          Text(
            'Search Tips',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildSearchTip(
            Icons.title,
            'Title Search',
            'Search entry titles and content',
          ),
          _buildSearchTip(
            Icons.tag,
            'Tag Search',
            'Find entries by tags (e.g., #work, #family)',
          ),
          _buildSearchTip(
            Icons.location_on,
            'Location Search',
            'Search by location names',
          ),
          _buildSearchTip(
            Icons.date_range,
            'Advanced',
            'Use quotes for exact phrases',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTip(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[300]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '${_searchResults.length} result${_searchResults.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          );
        }

        final entry = _searchResults[index - 1];
        return _buildSearchResultCard(entry);
      },
    );
  }

  Widget _buildSearchResultCard(Entry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EntryViewScreen(entry: entry),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with date and metadata
              Row(
                children: [
                  Text(
                    DateFormat('MMM d, yyyy').format(entry.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (entry.hasAttachments) ...[
                    Icon(
                      Icons.attachment,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.attachments.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (entry.hasLocation)
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  if (entry.hasRating) ...[
                    const SizedBox(width: 8),
                    Row(
                      children: List.generate(
                        entry.rating!,
                        (i) => const Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 12),

              // Title
              if (entry.title.isNotEmpty) ...[
                Text(
                  _highlightSearchTerm(entry.title),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Content preview
              if (entry.content.isNotEmpty) ...[
                Text(
                  _highlightSearchTerm(entry.content),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
              ],

              // Tags
              if (entry.hasTags) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: entry.tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tag,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue[700],
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 8),
              ],

              // Location
              if (entry.hasLocation && entry.locationName != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _highlightSearchTerm(entry.locationName!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _highlightSearchTerm(String text) {
    // For now, just return the text as-is
    // In a real implementation, you might highlight the search terms
    return text;
  }

  void _performSearch(String journalId, String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await ref
          .read(entryProvider(journalId).notifier)
          .searchEntries(query);
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _hasSearched = true;
      });
    } catch (error) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _hasSearched = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $error')),
        );
      }
    }
  }

  void _clearSearch() {
    setState(() {
      _searchResults = [];
      _hasSearched = false;
      _isSearching = false;
    });
  }

  void _showCreateJournalDialog(WidgetRef ref) {
    // This would show the same dialog as in CalendarScreen
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create journal functionality will be added'),
      ),
    );
  }
}