import 'package:flutter/material.dart';
import '../models/entry.dart';
import '../models/attachment.dart';
import 'attachment_thumbnail.dart';

class CalendarDayCell extends StatelessWidget {
  final int dayNumber;
  final bool isCurrentMonth;
  final bool isSelected;
  final bool isToday;
  final List<Entry> entries;
  final VoidCallback? onTap;
  const CalendarDayCell({
    super.key,
    required this.dayNumber,
    required this.isCurrentMonth,
    required this.isSelected,
    required this.isToday,
    required this.entries,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Use RepaintBoundary to isolate repaints for performance
    return RepaintBoundary(
      child: _CalendarDayCellContent(
        dayNumber: dayNumber,
        isCurrentMonth: isCurrentMonth,
        isSelected: isSelected,
        isToday: isToday,
        entries: entries,
        onTap: onTap,
      ),
    );
  }
}

class _CalendarDayCellContent extends StatelessWidget {
  final int dayNumber;
  final bool isCurrentMonth;
  final bool isSelected;
  final bool isToday;
  final List<Entry> entries;
  final VoidCallback? onTap;
  const _CalendarDayCellContent({
    required this.dayNumber,
    required this.isCurrentMonth,
    required this.isSelected,
    required this.isToday,
    required this.entries,
    this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    // Cache computed values within build to avoid repeated calculations
    final representativePhoto = _getRepresentativePhoto();
    final hasPhoto = representativePhoto != null;
    final totalPhotos = _getTotalPhotoCount();
    final hasNonPhotoEntries = _computeHasNonPhotoEntries();

    return Semantics(
      label: isCurrentMonth 
          ? 'Select day $dayNumber'
          : 'Day $dayNumber from adjacent month',
      button: isCurrentMonth,
      child: GestureDetector(
        onTap: isCurrentMonth ? onTap : null,
        child: Container(
        decoration: BoxDecoration(
          border: isSelected 
              ? Border.all(color: Theme.of(context).primaryColor, width: 2)
              : Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  width: 1.0,
                ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: hasPhoto 
              ? _buildPhotoCell(context, representativePhoto, totalPhotos, hasNonPhotoEntries)
              : _buildEmptyCell(context, hasNonPhotoEntries),
        ),
        ),
      ),
    );
  }

  Attachment? _getRepresentativePhoto() {
    if (entries.isEmpty) return null;
    
    // Find entries with photos
    final entriesWithPhotos = entries
        .where((entry) => entry.photoAttachments.isNotEmpty)
        .toList();
    
    if (entriesWithPhotos.isEmpty) return null;
    
    // Sort by content richness (content length + attachment count)
    // This prioritizes entries with more substantial content
    entriesWithPhotos.sort((a, b) {
      final scoreA = a.content.length + (a.attachments.length * 10);
      final scoreB = b.content.length + (b.attachments.length * 10);
      return scoreB.compareTo(scoreA);
    });
    
    // Return the first photo from the most substantial entry
    return entriesWithPhotos.first.photoAttachments.first;
  }

  int _getTotalPhotoCount() {
    int count = 0;
    for (final entry in entries) {
      count += entry.photoAttachments.length;
    }
    return count;
  }

  bool _computeHasNonPhotoEntries() {
    return entries.any((e) => e.attachments.isEmpty || 
        e.attachments.any((a) => a.type != AttachmentType.photo));
  }

  Widget _buildPhotoCell(BuildContext context, Attachment photo, int totalPhotos, bool hasNonPhotoEntries) {
    return Stack(
      children: [
        // Background photo
        _buildSinglePhoto(photo),
        
        // Day number centered
        _buildCenteredDayNumber(context),
        
        // Entry dots indicator  
        if (entries.isNotEmpty)
          _buildEntryDotsIndicator(context),
        
        // Today highlight
        if (isToday && !isSelected)
          _buildTodayHighlight(context),
      ],
    );
  }

  Widget _buildSinglePhoto(Attachment photo) {
    return _LazyAttachmentThumbnail(
      attachment: photo,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.zero,
    );
  }


  Widget _buildEmptyCell(BuildContext context, bool hasEntries) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isCurrentMonth 
          ? (isToday ? Colors.blue.withValues(alpha: 0.15) : Colors.transparent)
          : Colors.grey.withValues(alpha: 0.1),
      child: Stack(
        children: [
          _buildCenteredDayNumber(context),
          if (entries.isNotEmpty)
            _buildEntryDotsIndicator(context),
          if (isToday && !isSelected)
            _buildTodayHighlight(context),
        ],
      ),
    );
  }

  Widget _buildCenteredDayNumber(BuildContext context) {
    // Don't show day numbers for non-current month days
    if (!isCurrentMonth) {
      return const SizedBox.shrink();
    }
    
    final hasPhotos = _getRepresentativePhoto() != null;
    
    final textColor = hasPhotos 
        ? Colors.white
        : (isSelected
            ? Colors.black
            : (isToday 
                ? Theme.of(context).primaryColor
                : Theme.of(context).textTheme.bodyMedium?.color));
    
    return Center(
      child: Text(
        '$dayNumber',
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEntryDotsIndicator(BuildContext context) {
    final entryCount = entries.length;
    
    // Return empty widget if no entries
    if (entryCount == 0) {
      return const SizedBox.shrink();
    }
    
    // Determine number of dots to show (max 3)
    final dotsToShow = entryCount > 3 ? 3 : entryCount;
    final showPlus = entryCount > 3;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show dots
              for (int i = 0; i < dotsToShow; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              // Show + if more than 3 entries
              if (showPlus) ...[
                const SizedBox(width: 4),
                const Text(
                  '+',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayHighlight(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

/// A lazy-loading wrapper for AttachmentThumbnail that only loads when in viewport
class _LazyAttachmentThumbnail extends StatefulWidget {
  final Attachment attachment;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const _LazyAttachmentThumbnail({
    required this.attachment,
    required this.width,
    required this.height,
    required this.fit,
    this.borderRadius,
  });

  @override
  State<_LazyAttachmentThumbnail> createState() => _LazyAttachmentThumbnailState();
}

class _LazyAttachmentThumbnailState extends State<_LazyAttachmentThumbnail> {
  bool _isInView = false;

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to detect when widget is actually rendered
    return LayoutBuilder(
      builder: (context, constraints) {
        // Mark as in view when we have constraints (i.e., widget is laid out)
        if (!_isInView && constraints.maxWidth > 0 && constraints.maxHeight > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isInView = true;
              });
            }
          });
        }

        if (_isInView) {
          return AttachmentThumbnail(
            attachment: widget.attachment,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            borderRadius: widget.borderRadius,
          );
        } else {
          // Show a placeholder while not in view
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: widget.borderRadius ?? BorderRadius.zero,
            ),
            child: const Center(
              child: Icon(
                Icons.image,
                color: Colors.grey,
                size: 16,
              ),
            ),
          );
        }
      },
    );
  }
}