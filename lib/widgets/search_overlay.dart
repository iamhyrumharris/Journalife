import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../models/journal.dart';
import '../providers/journal_provider.dart';
import '../providers/entry_provider.dart';
import '../screens/entry/entry_edit_screen.dart';

class SearchOverlay extends ConsumerStatefulWidget {
  const SearchOverlay({super.key});

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<Entry> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentJournal = ref.watch(currentJournalProvider);

    return Scaffold(
      backgroundColor: Colors.black54,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent dismissal when tapping inside
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).appBarTheme.backgroundColor ?? 
                             Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _focusNode,
                            decoration: const InputDecoration(
                              hintText: 'Search entries...',
                              border: InputBorder.none,
                            ),
                            onChanged: _onSearchChanged,
                            onSubmitted: _performSearch,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  
                  // Search Results
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: _buildSearchContent(currentJournal),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchContent(Journal? currentJournal) {
    if (currentJournal == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Please select a journal to search',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return _buildSearchPrompt();
    }

    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      );
    }

    if (_searchResults.isEmpty) {
      return _buildNoResults();
    }

    return _buildSearchResults();
  }

  Widget _buildSearchPrompt() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Search your journal entries',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Enter keywords to find entries by title, content, or tags',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No entries found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching for different keywords or check your spelling',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final entry = _searchResults[index];
        return _buildSearchResultCard(entry);
      },
    );
  }

  Widget _buildSearchResultCard(Entry entry) {
    final query = _searchController.text.toLowerCase();
    
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          Navigator.pop(context); // Close search overlay
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EntryEditScreen(entry: entry),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(entry.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),

              // Title (with highlighting)
              if (entry.title.isNotEmpty) ...[
                RichText(
                  text: _highlightText(
                    entry.title,
                    query,
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ) ?? const TextStyle(),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],

              // Content preview (with highlighting)
              if (entry.content.isNotEmpty) ...[
                RichText(
                  text: _highlightText(
                    entry.content,
                    query,
                    Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],

              // Entry metadata
              Row(
                children: [

                  // Attachments indicator
                  if (entry.hasAttachments) ...[
                    const Icon(Icons.attachment, size: 16, color: Colors.blue),
                    Text(
                      '${entry.attachments.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Location indicator
                  if (entry.hasLocation) ...[
                    const Icon(Icons.location_on, size: 16, color: Colors.red),
                    const SizedBox(width: 12),
                  ],

                  const Spacer(),

                  // Time
                  Text(
                    DateFormat.jm().format(entry.createdAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              // Tags (with highlighting)
              if (entry.hasTags) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: entry.tags.map((tag) {
                    final isHighlighted = tag.toLowerCase().contains(query);
                    return Chip(
                      label: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isHighlighted ? FontWeight.bold : null,
                        ),
                      ),
                      backgroundColor: isHighlighted 
                        ? Colors.yellow.withValues(alpha: 0.3)
                        : Colors.blue.withValues(alpha: 0.1),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _highlightText(String text, String query, TextStyle baseStyle) {
    if (query.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    
    int start = 0;
    int index = lowerText.indexOf(lowerQuery);
    
    while (index != -1) {
      // Add non-highlighted text before the match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: baseStyle,
        ));
      }
      
      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: baseStyle.copyWith(
          backgroundColor: Colors.yellow.withValues(alpha: 0.3),
          fontWeight: FontWeight.bold,
        ),
      ));
      
      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }
    
    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: baseStyle,
      ));
    }
    
    return TextSpan(children: spans);
  }

  void _onSearchChanged(String query) {
    // Debounce search as user types
    if (query.length >= 2) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (query == _searchController.text) {
          _performSearch(query);
        }
      });
    } else if (query.isEmpty) {
      _clearSearch();
    }
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      _clearSearch();
      return;
    }

    final currentJournal = ref.read(currentJournalProvider);
    if (currentJournal == null) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final entriesAsync = ref.read(entryProvider(currentJournal.id));
      final entries = entriesAsync.value ?? [];
      
      final results = _filterEntries(entries, query);
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  List<Entry> _filterEntries(List<Entry> entries, String query) {
    final lowerQuery = query.toLowerCase();
    
    return entries.where((entry) {
      // Search in title
      if (entry.title.toLowerCase().contains(lowerQuery)) {
        return true;
      }
      
      // Search in content
      if (entry.content.toLowerCase().contains(lowerQuery)) {
        return true;
      }
      
      // Search in tags
      if (entry.hasTags) {
        for (final tag in entry.tags) {
          if (tag.toLowerCase().contains(lowerQuery)) {
            return true;
          }
        }
      }
      
      // Search in location name
      if (entry.hasLocation && entry.locationName != null) {
        if (entry.locationName!.toLowerCase().contains(lowerQuery)) {
          return true;
        }
      }
      
      return false;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by date descending
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _hasSearched = false;
      _isSearching = false;
    });
  }

}

void showSearchOverlay(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => const SearchOverlay(),
  );
}