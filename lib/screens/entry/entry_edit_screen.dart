import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/entry.dart';
import '../../models/attachment.dart';
import '../../providers/entry_provider.dart';
import '../../providers/journal_provider.dart';
import '../../services/media_service.dart';
import '../../widgets/audio_recorder_widget.dart';

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
  
  final _titleFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();
  
  bool _isTextFieldFocused = false;

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

    // Add focus listeners
    _titleFocusNode.addListener(_onFocusChange);
    _contentFocusNode.addListener(_onFocusChange);

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

      // For new entries, leave text fields empty to show hint text
      _titleController.clear();
      _contentController.clear();
    }
  }

  void _onFocusChange() {
    setState(() {
      _isTextFieldFocused = _titleFocusNode.hasFocus || _contentFocusNode.hasFocus;
    });
  }

  Future<bool> _onWillPop() async {
    _saveEntryIfNotBlank();
    return true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _locationController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentJournal = ref.watch(currentJournalProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    if (currentJournal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('No Journal Selected')),
        body: const Center(child: Text('Please select a journal first')),
      );
    }

    // Get current date for display
    final now = DateTime.now();
    final dateFormatter = DateFormat('E, MMM d, yyyy h:mm a');
    final formattedDate = dateFormatter.format(now);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: colorScheme.surface,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
        ),
        title: Text(
          formattedDate,
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.7),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: false,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Metadata row with line
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 0),
                  // Line above metadata
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: colorScheme.onSurface.withOpacity(0.08),
                  ),
                  const SizedBox(height: 12),
                  // Metadata content
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentJournal.name,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _locationController.text.isEmpty
                            ? 'Unknown Location'
                            : _locationController.text,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.wb_sunny,
                        size: 14,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '72°F',
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 0),
                ],
              ),
            ),

            // Editor area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title TextField
                    TextField(
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      cursorColor: colorScheme.primary,
                      decoration: InputDecoration(
                        hintText: _isEditing ? null : 'A moment to remember',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.3),
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),

                    const SizedBox(height: 24),

                    // Body TextField
                    TextField(
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        height: 1.6,
                        fontWeight: FontWeight.w400,
                      ),
                      cursorColor: colorScheme.primary,
                      decoration: InputDecoration(
                        hintText: _isEditing
                            ? null
                            : 'Today brought new perspectives and quiet revelations that shifted my understanding. The morning light filtered through familiar windows, casting shadows that seemed to whisper stories of transformation...',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.3),
                          fontSize: 18,
                          height: 1.6,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      maxLines: null,
                      minLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom action row - show when text fields are not focused (clean writing experience)
            if (!_isTextFieldFocused)
              Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: 8 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.onSurface.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (keyboardHeight > 0)
                      IconButton(
                        onPressed: () => FocusScope.of(context).unfocus(),
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: colorScheme.onSurface.withOpacity(0.6),
                          size: 24,
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      onPressed: _addPhoto,
                      icon: Icon(
                        Icons.image_outlined,
                        color: colorScheme.onSurface.withOpacity(0.6),
                        size: 22,
                      ),
                    ),
                    IconButton(
                      onPressed: _addFile,
                      icon: Icon(
                        Icons.attach_file_outlined,
                        color: colorScheme.onSurface.withOpacity(0.6),
                        size: 22,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // TODO: Implement text formatting options
                      },
                      icon: Icon(
                        Icons.text_format_outlined,
                        color: colorScheme.onSurface.withOpacity(0.6),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  void _saveEntryIfNotBlank() {
    // Check if entry is completely blank
    final titleText = _titleController.text.trim();
    final contentText = _contentController.text.trim();
    
    if (titleText.isEmpty && contentText.isEmpty && _attachments.isEmpty) {
      // Don't save blank entries
      return;
    }
    
    _saveEntry();
  }

  void _saveEntry() {
    final currentJournal = ref.read(currentJournalProvider);
    if (currentJournal == null) return;

    // For the simplified interface, we'll keep existing tags and ratings from editing
    // but won't allow setting new ones for new entries
    final tags = _isEditing
        ? _tagsController.text
              .split(',')
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList()
        : <String>[];

    if (_isEditing) {
      final updatedEntry = widget.entry!.copyWith(
        title: _titleController.text.isEmpty
            ? 'Untitled'
            : _titleController.text,
        content: _contentController.text,
        tags: tags,
        rating: _rating,
        latitude: _latitude,
        longitude: _longitude,
        locationName: _locationController.text.isEmpty
            ? null
            : _locationController.text,
        attachments: _attachments,
      );

      ref
          .read(entryProvider(currentJournal.id).notifier)
          .updateEntry(updatedEntry);
    } else {
      ref
          .read(entryProvider(currentJournal.id).notifier)
          .createEntry(
            id: _entryId,
            title: _titleController.text.isEmpty
                ? 'Untitled'
                : _titleController.text,
            content: _contentController.text,
            createdAt: widget.initialDate,
            tags: tags,
            rating: null, // No rating for new entries in simplified interface
            latitude: _latitude,
            longitude: _longitude,
            locationName: _locationController.text.isEmpty
                ? null
                : _locationController.text,
            attachments: _attachments,
          );
    }

    Navigator.pop(context);
  }

  void _getCurrentLocation() async {
    final locationData = await MediaService.getCurrentLocation();

    if (locationData != null && mounted) {
      if (locationData.containsKey('error')) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(locationData['error'])));
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
                  content: Text(
                    'Failed to capture photo. Please check camera permissions in settings.',
                  ),
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
                content: Text(
                  'Failed to select photo. ${MediaService.supportsCameraCapture ? "Please check photo library permissions in settings." : "Please check file access permissions."}',
                ),
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
                content: Text(
                  'Failed to select photos. ${MediaService.supportsCameraCapture ? "Please check photo library permissions in settings." : "Please check file access permissions or ensure image files were selected."}',
                ),
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
        child: Column(mainAxisSize: MainAxisSize.min, children: options),
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
          content: Text(
            'Failed to select file. Operation was cancelled or no file was selected.',
          ),
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
