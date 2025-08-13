import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/entry.dart';
import '../../models/journal.dart';
import '../../providers/journal_provider.dart';
import '../../providers/entry_provider.dart';
import '../../services/media_service.dart';
import '../../widgets/journal_selector.dart';
import '../entry/entry_edit_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  
  // Default to a generic location (San Francisco)
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 10,
  );

  @override
  Widget build(BuildContext context) {
    final journalsAsync = ref.watch(journalProvider);
    final currentJournal = ref.watch(currentJournalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const JournalSelector(isAppBarTitle: true),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
            tooltip: 'Go to current location',
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              ref.read(journalProvider.notifier).loadJournals();
            },
            tooltip: 'Refresh',
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
        
        if (entriesWithLocation.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No entries with location in ${journal.name}',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add location to your entries to see them on the map',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/entry/create');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Entry'),
                ),
              ],
            ),
          );
        }

        // Update markers when entries change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateMarkers(entriesWithLocation);
        });

        return GoogleMap(
          initialCameraPosition: _initialCameraPosition,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            _fitMapToMarkers(entriesWithLocation);
          },
          markers: _markers,
          onTap: (LatLng position) {
            _showCreateEntryDialog(position);
          },
        );
      },
    );
  }

  void _updateMarkers(List<Entry> entries) {
    final newMarkers = <Marker>{};

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.hasLocation) {
        final marker = Marker(
          markerId: MarkerId(entry.id),
          position: LatLng(entry.latitude!, entry.longitude!),
          infoWindow: InfoWindow(
            title: entry.title.isNotEmpty ? entry.title : 'Entry',
            snippet: entry.locationName ?? 'Tap to view details',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EntryEditScreen(entry: entry),
                ),
              );
            },
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(i),
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

  double _getMarkerHue(int index) {
    // Cycle through different colors for markers
    final hues = [
      BitmapDescriptor.hueRed,
      BitmapDescriptor.hueBlue,
      BitmapDescriptor.hueGreen,
      BitmapDescriptor.hueYellow,
      BitmapDescriptor.hueOrange,
      BitmapDescriptor.hueMagenta,
      BitmapDescriptor.hueCyan,
    ];
    return hues[index % hues.length];
  }

  void _fitMapToMarkers(List<Entry> entries) {
    if (entries.isEmpty || _mapController == null) return;

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

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100.0, // padding
      ),
    );
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
        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(latitude, longitude),
              15.0, // Zoom level for current location
            ),
          );
          
          // Add a marker for current location
          setState(() {
            _markers.add(
              Marker(
                markerId: const MarkerId('current_location'),
                position: LatLng(latitude, longitude),
                infoWindow: InfoWindow(
                  title: 'Current Location',
                  snippet: locationName,
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
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