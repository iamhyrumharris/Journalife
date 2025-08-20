import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/entry.dart';
import '../../models/attachment.dart';
import '../../providers/entry_provider.dart';
import '../../providers/journal_provider.dart';
import '../../services/media_service.dart';
import '../../widgets/text_formatting_toolbar.dart';
import '../../widgets/full_screen_gallery_widget.dart';
import '../../widgets/responsive_entry_layout.dart';
import '../../utils/responsive_breakpoints.dart';

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

class _EntryEditScreenState extends ConsumerState<EntryEditScreen> with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _locationController = TextEditingController();
  
  final _titleFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();
  
  bool _isTextFieldFocused = false;
  bool _showFormattingToolbar = false;

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
    WidgetsBinding.instance.addObserver(this);

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
    final wasTextFieldFocused = _isTextFieldFocused;
    final isNowTextFieldFocused = _titleFocusNode.hasFocus || _contentFocusNode.hasFocus;
    
    setState(() {
      _isTextFieldFocused = isNowTextFieldFocused;
    });
    
    // Save when both text fields lose focus
    if (wasTextFieldFocused && !isNowTextFieldFocused) {
      _saveEntryIfNotBlank();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Save when app goes to background or is paused
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _saveEntryIfNotBlank();
    }
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

    if (currentJournal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('No Journal Selected')),
        body: const Center(child: Text('Please select a journal first')),
      );
    }

    // Get date for display - use existing entry date, initial date, or current date
    final displayDate = widget.entry?.createdAt ?? widget.initialDate ?? DateTime.now();
    final dateFormatter = DateFormat('E, MMM d, yyyy h:mm a');
    final formattedDate = dateFormatter.format(displayDate);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _saveEntryIfNotBlank();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: colorScheme.surface,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {
              _saveEntryIfNotBlank();
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back,
              color: colorScheme.onSurface,
              size: 20,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Text(
          formattedDate,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        actions: [
          if (_isTextFieldFocused)
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _saveEntryIfNotBlank();
                },
                icon: Icon(
                  Icons.keyboard_hide,
                  color: colorScheme.primary,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
        ),
        body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          _saveEntryIfNotBlank();
        },
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
                    color: colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 12),
                  // Metadata content
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          currentJournal.name,
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _locationController.text.isEmpty
                              ? 'Unknown Location'
                              : _locationController.text,
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                child: ResponsiveEntryLayout(
                  photos: _attachments
                      .where((attachment) => attachment.type == AttachmentType.photo)
                      .toList(),
                  titleController: _titleController,
                  contentController: _contentController,
                  titleFocusNode: _titleFocusNode,
                  contentFocusNode: _contentFocusNode,
                  attachments: _attachments,
                  onPhotoTap: _openGallery,
                  onRemoveAttachment: _removeAttachment,
                ),
              ),
            ),

            // Bottom action row - show when text fields are not focused (clean writing experience)
            if (!_isTextFieldFocused)
              LayoutBuilder(
                builder: (context, constraints) {
                  final layoutType = ResponsiveBreakpoints.getLayoutTypeFromWidth(constraints.maxWidth);
                  final isDesktop = layoutType == LayoutType.desktop;
                  
                  return Container(
                    margin: EdgeInsets.fromLTRB(
                      isDesktop ? 32 : 16,
                      0,
                      isDesktop ? 32 : 16,
                      16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: Icons.image_outlined,
                          onPressed: _addPhoto,
                          isActive: false,
                          colorScheme: colorScheme,
                        ),
                        _buildActionButton(
                          icon: Icons.attach_file_outlined,
                          onPressed: _addFile,
                          isActive: false,
                          colorScheme: colorScheme,
                        ),
                        _buildActionButton(
                          icon: _latitude != null && _longitude != null
                              ? Icons.location_on
                              : Icons.location_on_outlined,
                          onPressed: _addLocation,
                          isActive: _latitude != null && _longitude != null,
                          colorScheme: colorScheme,
                        ),
                        _buildActionButton(
                          icon: _showFormattingToolbar 
                              ? Icons.text_format 
                              : Icons.text_format_outlined,
                          onPressed: () {
                            setState(() {
                              _showFormattingToolbar = !_showFormattingToolbar;
                            });
                          },
                          isActive: _showFormattingToolbar,
                          colorScheme: colorScheme,
                        ),
                        _buildActionButton(
                          icon: Icons.bookmark_outline,
                          onPressed: () {
                            // TODO: Implement bookmark functionality
                          },
                          isActive: false,
                          colorScheme: colorScheme,
                        ),
                      ],
                    ),
                  );
                },
              ),

            // Text formatting toolbar - show when enabled
            if (_showFormattingToolbar)
              TextFormattingToolbar(
                controller: _contentController,
              ),
          ],
        ),
      ),
    ));
  }

  Future<void> _saveEntryIfNotBlank() async {
    // Check if entry is completely blank
    final titleText = _titleController.text.trim();
    final contentText = _contentController.text.trim();
    
    if (titleText.isEmpty && contentText.isEmpty && _attachments.isEmpty) {
      // Don't save blank entries
      return;
    }
    
    await _saveEntry();
  }

  Future<void> _saveEntry() async {
    final currentJournal = ref.read(currentJournalProvider);
    if (currentJournal == null) return;

    // For the simplified interface, we'll keep existing tags from editing
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
            latitude: _latitude,
            longitude: _longitude,
            locationName: _locationController.text.isEmpty
                ? null
                : _locationController.text,
            attachments: _attachments,
          );
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

  void _addLocation() async {
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting current location...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final locationData = await MediaService.getCurrentLocation();
    
    if (locationData != null && !locationData.containsKey('error')) {
      setState(() {
        _latitude = locationData['latitude'];
        _longitude = locationData['longitude'];
        _locationController.text = locationData['locationName'] ?? 'Unknown Location';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location added: ${_locationController.text}'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } else if (mounted) {
      final errorMessage = locationData?['error'] ?? 'Failed to get location';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _removeAttachment(Attachment attachment) {
    setState(() {
      _attachments.remove(attachment);
    });
  }

  void _openGallery(int index) {
    final photos = _attachments
        .where((attachment) => attachment.type == AttachmentType.photo)
        .toList();
    
    if (photos.isNotEmpty && index < photos.length) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullScreenGalleryWidget(
            photos: photos,
            initialIndex: index,
          ),
        ),
      );
    }
  }



  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isActive,
    required ColorScheme colorScheme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive 
            ? colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: isActive
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.7),
          size: 24,
        ),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
      ),
    );
  }
}
