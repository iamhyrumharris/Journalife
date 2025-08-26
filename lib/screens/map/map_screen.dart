import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/entry.dart';
import '../../models/journal.dart';
import '../../providers/journal_provider.dart';
import '../../providers/entry_provider.dart';
import '../../services/media_service.dart';
import '../../widgets/journal_selector.dart';
import '../entry/entry_edit_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/search_overlay.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  bool _hasInitializedLocation = false;
  
  // Default to a generic location (San Francisco)
  static const LatLng _initialCenter = LatLng(37.7749, -122.4194);
  static const double _initialZoom = 10.0;

  @override
  void initState() {
    super.initState();
    // Try to get user's location on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeToUserLocation();
    });
  }

  Future<void> _initializeToUserLocation() async {
    if (_hasInitializedLocation) return;
    
    try {
      final locationData = await MediaService.getCurrentLocation();
      
      if (!mounted) return;
      
      if (locationData != null && !locationData.containsKey('error')) {
        final latitude = locationData['latitude'] as double;
        final longitude = locationData['longitude'] as double;
        
        // Move camera to current location only on first load
        _mapController.move(LatLng(latitude, longitude), 13.0);
        _hasInitializedLocation = true;
      }
    } catch (e) {
      // Silently fail - will use default location
    }
  }

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
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
            tooltip: 'Go to current location',
          ),
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

          return _buildMapView(ref, effectiveJournal);
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

  Widget _buildMapView(WidgetRef ref, Journal journal) {
    final entriesAsync = ref.watch(entryProvider(journal.id));

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading entries: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(entryProvider(journal.id).notifier).loadEntries(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (entries) {
        final entriesWithLocation = entries.where((e) => e.hasLocation).toList();
        
        // Update markers when entries change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateMarkers(entriesWithLocation);
        });

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _initialZoom,
            minZoom: 3.0,
            maxZoom: 18.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
              enableMultiFingerGestureRace: true,
            ),
            onTap: (tapPosition, point) {
              _showCreateEntryDialog(point);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.journal_new',
            ),
            MarkerLayer(
              markers: _markers,
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _updateMarkers(List<Entry> entries) {
    final newMarkers = <Marker>[];

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.hasLocation) {
        final marker = Marker(
          point: LatLng(entry.latitude!, entry.longitude!),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EntryEditScreen(entry: entry),
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getMarkerColor(i),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.place,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        );
        newMarkers.add(marker);
      }
    }

    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
      });
    }
  }

  Color _getMarkerColor(int index) {
    // Cycle through different colors for markers
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
    ];
    return colors[index % colors.length];
  }


  void _showCreateEntryDialog(LatLng position) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Entry Here?'),
        content: Text(
          'Create a new journal entry at this location?\n\nLat: ${position.latitude.toStringAsFixed(4)}\nLng: ${position.longitude.toStringAsFixed(4)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/entry/create',
                arguments: {
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                  'locationName': 'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})',
                },
              );
            },
            child: const Text('Create Entry'),
          ),
        ],
      ),
    );
  }

  void _goToCurrentLocation() async {
    try {
      final locationData = await MediaService.getCurrentLocation();
      
      if (!mounted) return;
      
      if (locationData != null && !locationData.containsKey('error')) {
        final latitude = locationData['latitude'] as double;
        final longitude = locationData['longitude'] as double;
        final locationName = locationData['locationName'] as String;
        
        // Move camera to current location
        _mapController.move(LatLng(latitude, longitude), 15.0);
        
        // Add a marker for current location
        setState(() {
          _markers.add(
            Marker(
              point: LatLng(latitude, longitude),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.my_location,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          );
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Located at: $locationName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Handle error
        final errorMessage = locationData?['error'] ?? 'Failed to get current location';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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