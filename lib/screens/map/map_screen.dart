import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  bool _hasInitiallyFitToMarkers = false;
  List<Entry>? _lastProcessedEntries;
  
  // Default to a generic location (San Francisco)
  static const LatLng _initialCenter = LatLng(37.7749, -122.4194);
  static const double _initialZoom = 10.0;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
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
        
        // Only update markers when entries actually change
        if (_lastProcessedEntries == null || 
            !_entriesEqual(_lastProcessedEntries!, entriesWithLocation)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateMarkers(entriesWithLocation);
            _lastProcessedEntries = List.from(entriesWithLocation);
            
            // Only fit to markers on initial load, not on every rebuild
            if (entriesWithLocation.isNotEmpty && !_hasInitiallyFitToMarkers) {
              _fitMapToMarkers(entriesWithLocation);
              _hasInitiallyFitToMarkers = true;
            }
          });
        }

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _initialZoom,
            onTap: (tapPosition, point) => _showCreateEntryDialog(point),
            // Remove problematic onMapReady workaround that could interfere with zooming
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.journalapp.journal_new',
            ),
            if (_markers.isNotEmpty)
              MarkerLayer(
                markers: _markers,
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
          width: 40,
          height: 40,
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
              decoration: BoxDecoration(
                color: _getMarkerColor(i),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 20,
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
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }

  void _fitMapToMarkers(List<Entry> entries) {
    if (entries.isEmpty) return;

    double minLat = entries.first.latitude!;
    double maxLat = entries.first.latitude!;
    double minLng = entries.first.longitude!;
    double maxLng = entries.first.longitude!;

    for (final entry in entries) {
      if (entry.hasLocation) {
        minLat = minLat < entry.latitude! ? minLat : entry.latitude!;
        maxLat = maxLat > entry.latitude! ? maxLat : entry.latitude!;
        minLng = minLng < entry.longitude! ? minLng : entry.longitude!;
        maxLng = maxLng > entry.longitude! ? maxLng : entry.longitude!;
      }
    }

    // Add padding
    const padding = 0.01;
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    // Calculate bounds and fit map
    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
    
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
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
        _mapController.move(
          LatLng(latitude, longitude),
          15.0, // Zoom level for current location
        );
        
        // Add a marker for current location
        setState(() {
          // Remove any existing current location marker
          _markers.removeWhere((marker) => 
              marker.point == LatLng(latitude, longitude) && 
              marker.child is Container &&
              (marker.child as Container).decoration is BoxDecoration &&
              ((marker.child as Container).decoration as BoxDecoration).color == Colors.blue);
          
          _markers.add(
            Marker(
              point: LatLng(latitude, longitude),
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location,
                  color: Colors.white,
                  size: 20,
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

  bool _entriesEqual(List<Entry> a, List<Entry> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || 
          a[i].latitude != b[i].latitude || 
          a[i].longitude != b[i].longitude) {
        return false;
      }
    }
    return true;
  }
}