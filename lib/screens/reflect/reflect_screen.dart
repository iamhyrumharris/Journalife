import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import '../../models/entry.dart';
import '../../models/journal.dart';
import '../../providers/journal_provider.dart';
import '../../providers/entry_provider.dart';
import '../../widgets/journal_selector.dart';
import '../entry/entry_edit_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/search_overlay.dart';

class ReflectScreen extends ConsumerStatefulWidget {
  const ReflectScreen({super.key});

  @override
  ConsumerState<ReflectScreen> createState() => _ReflectScreenState();
}

class _ReflectScreenState extends ConsumerState<ReflectScreen> {
  @override
  Widget build(BuildContext context) {
    final journalsAsync = ref.watch(journalProvider);
    final currentJournal = ref.watch(currentJournalProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: JournalSelector(isAppBarTitle: true),
        ),
        leadingWidth: 200,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearchOverlay(context);
            },
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: journalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading journals: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(journalProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (journals) {
          if (journals.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No journals found'),
                  Text('Create a journal to start reflecting'),
                ],
              ),
            );
          }

          if (currentJournal == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info, size: 64, color: Colors.blue),
                  SizedBox(height: 16),
                  Text('Please select a journal to view reflection data'),
                ],
              ),
            );
          }

          return _buildReflectContent(currentJournal);
        },
      ),
    );
  }

  Widget _buildReflectContent(Journal journal) {
    final entriesAsync = ref.watch(entryProvider(journal.id));

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading entries: $error'),
      ),
      data: (entries) {
        return AnimationLimiter(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(child: widget),
                ),
                children: [
                  _buildStatsSection(entries),
                  const SizedBox(height: 24),
                  _buildOnThisDaySection(entries),
                  const SizedBox(height: 24),
                  _buildRecentTrendsSection(entries),
                  const SizedBox(height: 24),
                  _buildWritingInsightsSection(entries),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _calculateCurrentStreak(List<Entry> entries) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    // Group entries by date (ignoring time)
    final entriesByDate = <DateTime, List<Entry>>{};
    for (final entry in entries) {
      final entryDate = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
      entriesByDate.putIfAbsent(entryDate, () => []).add(entry);
    }
    
    int streak = 0;
    DateTime currentDate = todayDate;
    
    // Go backward from today, counting consecutive days with entries
    while (entriesByDate.containsKey(currentDate)) {
      streak++;
      currentDate = currentDate.subtract(const Duration(days: 1));
    }
    
    return streak;
  }
  
  int _calculateLongestStreak(List<Entry> entries) {
    if (entries.isEmpty) return 0;
    
    // Group entries by date (ignoring time)
    final entriesByDate = <DateTime, List<Entry>>{};
    for (final entry in entries) {
      final entryDate = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
      entriesByDate.putIfAbsent(entryDate, () => []).add(entry);
    }
    
    // Get all unique dates and sort them
    final dates = entriesByDate.keys.toList()..sort();
    if (dates.isEmpty) return 0;
    
    int longestStreak = 1;
    int currentStreak = 1;
    
    // Find longest consecutive sequence
    for (int i = 1; i < dates.length; i++) {
      final previousDate = dates[i - 1];
      final currentDate = dates[i];
      
      // Check if dates are consecutive
      if (currentDate.difference(previousDate).inDays == 1) {
        currentStreak++;
        longestStreak = currentStreak > longestStreak ? currentStreak : longestStreak;
      } else {
        currentStreak = 1;
      }
    }
    
    return longestStreak;
  }

  Widget _buildStatsSection(List<Entry> entries) {
    final today = DateTime.now();
    final thisWeekEntries = entries.where((entry) {
      final daysDiff = today.difference(entry.createdAt).inDays;
      return daysDiff <= 7;
    }).length;

    final thisMonthEntries = entries.where((entry) {
      return entry.createdAt.month == today.month && 
             entry.createdAt.year == today.year;
    }).length;

    
    final currentStreak = _calculateCurrentStreak(entries);
    final longestStreak = _calculateLongestStreak(entries);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Journal Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Entries',
                    entries.length.toString(),
                    Icons.edit_note,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatItem(
                    'This Week',
                    thisWeekEntries.toString(),
                    Icons.calendar_today,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'This Month',
                    thisMonthEntries.toString(),
                    Icons.calendar_month,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatItem(
                    'Words Total',
                    _calculateTotalWords(entries).toString(),
                    Icons.text_fields,
                    Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Current Streak',
                    '$currentStreak day${currentStreak == 1 ? '' : 's'}',
                    Icons.local_fire_department,
                    Colors.deepOrange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatItem(
                    'Longest Streak',
                    '$longestStreak day${longestStreak == 1 ? '' : 's'}',
                    Icons.emoji_events,
                    const Color(0xFFFFD700), // Gold color
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOnThisDaySection(List<Entry> entries) {
    final today = DateTime.now();
    final onThisDayEntries = entries.where((entry) {
      return entry.createdAt.month == today.month && 
             entry.createdAt.day == today.day &&
             entry.createdAt.year != today.year;
    }).toList();

    onThisDayEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'On This Day',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMMM d').format(today),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            if (onThisDayEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No entries from previous years on this day',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...onThisDayEntries.take(3).map((entry) => _buildOnThisDayEntry(entry)),
            if (onThisDayEntries.length > 3)
              TextButton(
                onPressed: () {
                  // TODO: Show all entries from this day
                },
                child: Text('View all ${onThisDayEntries.length} entries'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnThisDayEntry(Entry entry) {
    final yearsAgo = DateTime.now().year - entry.createdAt.year;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
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
              Row(
                children: [
                  Text(
                    '$yearsAgo year${yearsAgo == 1 ? '' : 's'} ago',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('yyyy').format(entry.createdAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (entry.title.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (entry.content.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  entry.content,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTrendsSection(List<Entry> entries) {
    final last30Days = entries.where((entry) {
      final daysDiff = DateTime.now().difference(entry.createdAt).inDays;
      return daysDiff <= 30;
    }).toList();

    final weeklyEntries = <int, int>{};
    for (int week = 0; week < 4; week++) {
      final weekEntries = last30Days.where((entry) {
        final daysDiff = DateTime.now().difference(entry.createdAt).inDays;
        return daysDiff >= week * 7 && daysDiff < (week + 1) * 7;
      }).length;
      weeklyEntries[week] = weekEntries;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Recent Trends',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Entries per week (last 4 weeks)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int week = 3; week >= 0; week--)
                  _buildWeekBar(
                    'W${week + 1}',
                    weeklyEntries[week] ?? 0,
                    weeklyEntries.values.fold(0, (a, b) => a > b ? a : b),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekBar(String label, int count, int maxCount) {
    final height = maxCount > 0 ? (count / maxCount * 60).clamp(8.0, 60.0) : 8.0;
    
    return Column(
      children: [
        Container(
          width: 24,
          height: 60,
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 24,
            height: height,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  int _calculateTotalWords(List<Entry> entries) {
    return entries.fold<int>(0, (sum, entry) {
      return sum + entry.title.split(' ').length + entry.content.split(' ').length;
    });
  }

  Widget _buildWritingInsightsSection(List<Entry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();

    // Calculate writing insights
    final totalWords = entries.fold<int>(0, (sum, entry) {
      return sum + entry.title.split(' ').length + entry.content.split(' ').length;
    });

    final averageWordsPerEntry = totalWords / entries.length;
    
    final longestEntry = entries.reduce((a, b) =>
        (a.title.length + a.content.length) > (b.title.length + b.content.length) ? a : b);
    
    final shortestEntry = entries.reduce((a, b) =>
        (a.title.length + a.content.length) < (b.title.length + b.content.length) ? a : b);

    // Calculate entries with attachments
    final entriesWithAttachments = entries.where((e) => e.attachments.isNotEmpty).length;
    final attachmentPercentage = entries.isNotEmpty ? (entriesWithAttachments / entries.length * 100) : 0.0;

    // Calculate entries with location
    final entriesWithLocation = entries.where((e) => e.latitude != null && e.longitude != null).length;
    final locationPercentage = entries.isNotEmpty ? (entriesWithLocation / entries.length * 100) : 0.0;

    // Most productive time
    final hourCounts = <int, int>{};
    for (final entry in entries) {
      final hour = entry.createdAt.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }
    
    final mostProductiveHour = hourCounts.entries.isNotEmpty
        ? hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'Writing Insights',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Words',
                    NumberFormat('#,###').format(totalWords),
                    Icons.text_fields,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatItem(
                    'Avg Words',
                    averageWordsPerEntry.toStringAsFixed(0),
                    Icons.speed,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'With Media',
                    '${attachmentPercentage.toStringAsFixed(0)}%',
                    Icons.attach_file,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatItem(
                    'With Location',
                    '${locationPercentage.toStringAsFixed(0)}%',
                    Icons.location_on,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatItem(
              'Most Productive Hour',
              '${mostProductiveHour.toString().padLeft(2, '0')}:00 - ${(mostProductiveHour + 1).toString().padLeft(2, '0')}:00',
              Icons.schedule,
              Colors.purple,
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              leading: const Icon(Icons.auto_stories, color: Colors.indigo),
              title: const Text('Entry Records'),
              children: [
                ListTile(
                  leading: const Icon(Icons.trending_up, color: Colors.green),
                  title: const Text('Longest Entry'),
                  subtitle: Text(longestEntry.title.isNotEmpty ? longestEntry.title : 'Untitled'),
                  trailing: Text(
                    '${longestEntry.title.length + longestEntry.content.length} chars',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.trending_down, color: Colors.orange),
                  title: const Text('Shortest Entry'),
                  subtitle: Text(shortestEntry.title.isNotEmpty ? shortestEntry.title : 'Untitled'),
                  trailing: Text(
                    '${shortestEntry.title.length + shortestEntry.content.length} chars',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}