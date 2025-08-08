import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/entry.dart';
import '../../models/attachment.dart';
import '../../providers/entry_provider.dart';
import '../../providers/journal_provider.dart';
import '../../services/media_service.dart';
import '../../widgets/audio_recorder_widget.dart';
import '../../widgets/attachment_preview.dart';

class EntryEditScreen extends ConsumerStatefulWidget {
  final Entry? entry;
  final DateTime? initialDate;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialLocationName;

  const EntryEditScreen({
    super.key, 
    this.entry,
    this.initialDate,
    this.initialLatitude,
    this.initialLongitude, 
    this.initialLocationName,
  });

  @override
  ConsumerState<EntryEditScreen> createState() => _EntryEditScreenState();
}

class _EntryEditScreenState extends ConsumerState<EntryEditScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _locationController = TextEditingController();
  
  int? _rating;
  double? _latitude;
  double? _longitude;
  List<Attachment> _attachments = [];
  
  bool get _isEditing => widget.entry != null;
  final _uuid = const Uuid();
  
  // Consistent entry ID used throughout the editing session
  late final String _entryId;

  @override
  void initState() {
    super.initState();
    
    // Initialize consistent entry ID for this editing session
    _entryId = widget.entry?.id ?? _uuid.v4();
    
    if (_isEditing) {
      final entry = widget.entry!;
      _titleController.text = entry.title;
      _contentController.text = entry.content;
      _tagsController.text = entry.tags.join(', ');
      _locationController.text = entry.locationName ?? '';
      _rating = entry.rating;
      _latitude = entry.latitude;
      _longitude = entry.longitude;
      _attachments = List.from(entry.attachments);
    } else {
      // Set initial location data for new entries if provided
      _latitude = widget.initialLatitude;
      _longitude = widget.initialLongitude;
      _locationController.text = widget.initialLocationName ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentJournal = ref.watch(currentJournalProvider);
    
    if (currentJournal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('No Journal Selected')),
        body: const Center(
          child: Text('Please select a journal first'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Entry' : 'New Entry'),
        actions: [
          TextButton(
            onPressed: _saveEntry,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter a title for your entry',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Content
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'What\'s on your mind?',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
            ),
            const SizedBox(height: 24),

            // Rating
            Text(
              'Rating',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ...List.generate(5, (index) => GestureDetector(
                  onTap: () => setState(() {
                    _rating = _rating == index + 1 ? null : index + 1;
                  }),
                  child: Icon(
                    index < (_rating ?? 0) ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                )),
                if (_rating != null) ...[
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () => setState(() => _rating = null),
                    child: const Text('Clear'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Tags
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'Separate tags with commas',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Location
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      hintText: 'Add a location',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Get current location',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Attachments
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attachments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _addPhoto,
                      icon: const Icon(Icons.photo_camera),
                      tooltip: 'Add photo',
                    ),
                    IconButton(
                      onPressed: _addAudio,
                      icon: const Icon(Icons.mic),
                      tooltip: 'Record audio',
                    ),
                    IconButton(
                      onPressed: _addFile,
                      icon: const Icon(Icons.attach_file),
                      tooltip: 'Add file',
                    ),
                  ],
                ),
              ],
            ),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._attachments.map((attachment) => AttachmentPreview(
                attachment: attachment,
                onDelete: () => _removeAttachment(attachment),
              )),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }


  void _saveEntry() {
    final currentJournal = ref.read(currentJournalProvider);
    if (currentJournal == null) return;

    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    if (_isEditing) {
      final updatedEntry = widget.entry!.copyWith(
        title: _titleController.text,
        content: _contentController.text,
        tags: tags,
        rating: _rating,
        latitude: _latitude,
        longitude: _longitude,
        locationName: _locationController.text.isEmpty ? null : _locationController.text,
        attachments: _attachments,
      );
      
      ref.read(entryProvider(currentJournal.id).notifier).updateEntry(updatedEntry);
    } else {
      ref.read(entryProvider(currentJournal.id).notifier).createEntry(
        id: _entryId,
        title: _titleController.text,
        content: _contentController.text,
        createdAt: widget.initialDate,
        tags: tags,
        rating: _rating,
        latitude: _latitude,
        longitude: _longitude,
        locationName: _locationController.text.isEmpty ? null : _locationController.text,
        attachments: _attachments,
      );
    }

    Navigator.pop(context);
  }

  void _getCurrentLocation() async {
    final locationData = await MediaService.getCurrentLocation();
    
    if (locationData != null && mounted) {
      if (locationData.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(locationData['error'])),
        );
      } else {
        setState(() {
          _latitude = locationData['latitude'];
          _longitude = locationData['longitude'];
          _locationController.text = locationData['locationName'] ?? '';
        });
      }
    }
  }

  void _addPhoto() {
    final options = <Widget>[];
    
    // Add camera option only if supported on this platform
    if (MediaService.supportsCameraCapture) {
      options.add(
        ListTile(
          leading: const Icon(Icons.camera_alt),
          title: const Text('Take Photo'),
          onTap: () async {
            Navigator.pop(context);
            final attachment = await MediaService.capturePhoto(_entryId);
            if (attachment != null) {
              setState(() {
                _attachments.add(attachment);
              });
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to capture photo. Please check camera permissions in settings.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
        ),
      );
    }

    // Add single photo selection option with platform-appropriate label
    options.add(
      ListTile(
        leading: const Icon(Icons.photo_library),
        title: Text(MediaService.selectPhotoLabel),
        onTap: () async {
          Navigator.pop(context);
          final attachment = await MediaService.selectPhoto(_entryId);
          
          if (attachment != null) {
            setState(() {
              _attachments.add(attachment);
            });
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to select photo. ${MediaService.supportsCameraCapture ? "Please check photo library permissions in settings." : "Please check file access permissions."}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
      ),
    );

    // Add multiple photo selection option with platform-appropriate label
    options.add(
      ListTile(
        leading: const Icon(Icons.photo_library_outlined),
        title: Text(MediaService.selectMultiplePhotosLabel),
        onTap: () async {
          Navigator.pop(context);
          final attachments = await MediaService.selectMultiplePhotos(_entryId);
          if (attachments.isNotEmpty) {
            setState(() {
              _attachments.addAll(attachments);
            });
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to select photos. ${MediaService.supportsCameraCapture ? "Please check photo library permissions in settings." : "Please check file access permissions or ensure image files were selected."}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
      ),
    );

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options,
        ),
      ),
    );
  }

  void _addAudio() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: AudioRecorderWidget(
          entryId: _entryId,
          onRecordingComplete: (attachment) {
            Navigator.pop(context);
            setState(() {
              _attachments.add(attachment);
            });
          },
          onCancel: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _addFile() async {
    final attachment = await MediaService.pickFile(_entryId);
    if (attachment != null) {
      setState(() {
        _attachments.add(attachment);
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to select file. Operation was cancelled or no file was selected.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _removeAttachment(Attachment attachment) {
    setState(() {
      _attachments.remove(attachment);
    });
  }
}