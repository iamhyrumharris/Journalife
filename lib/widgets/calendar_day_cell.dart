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
    final photoAttachments = _getPhotoAttachments();
    final hasPhotos = photoAttachments.isNotEmpty;
    final hasNonPhotoEntries = entries.any((e) => e.attachments.isEmpty || 
        e.attachments.any((a) => a.type != AttachmentType.photo));

    return GestureDetector(
      onTap: onTap,
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
          child: hasPhotos 
              ? _buildPhotoCell(context, photoAttachments, hasNonPhotoEntries)
              : _buildEmptyCell(context, hasNonPhotoEntries),
        ),
      ),
    );
  }

  List<Attachment> _getPhotoAttachments() {
    final photos = <Attachment>[];
    for (final entry in entries) {
      photos.addAll(entry.photoAttachments);
    }
    return photos;
  }

  Widget _buildPhotoCell(BuildContext context, List<Attachment> photos, bool hasNonPhotoEntries) {
    return Stack(
      children: [
        // Background photo(s)
        if (photos.length == 1)
          _buildSinglePhoto(photos.first)
        else
          _buildMultiplePhotos(photos),
        
        // Day number overlay
        _buildDayNumberOverlay(context),
        
        // Non-photo entry indicator
        if (hasNonPhotoEntries)
          _buildEntryIndicator(context),
        
        // Today highlight
        if (isToday)
          _buildTodayHighlight(context),
      ],
    );
  }

  Widget _buildSinglePhoto(Attachment photo) {
    return AttachmentThumbnail(
      attachment: photo,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.zero,
    );
  }

  Widget _buildMultiplePhotos(List<Attachment> photos) {
    if (photos.length == 2) {
      return Row(
        children: [
          Expanded(
            child: AttachmentThumbnail(
              attachment: photos[0],
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.zero,
            ),
          ),
          const SizedBox(width: 1),
          Expanded(
            child: AttachmentThumbnail(
              attachment: photos[1],
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.zero,
            ),
          ),
        ],
      );
    } else if (photos.length == 3) {
      return Column(
        children: [
          Expanded(
            child: AttachmentThumbnail(
              attachment: photos[0],
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.zero,
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: AttachmentThumbnail(
                    attachment: photos[1],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                const SizedBox(width: 1),
                Expanded(
                  child: AttachmentThumbnail(
                    attachment: photos[2],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // 4+ photos - show first photo with overlay indicating more
      return Stack(
        children: [
          AttachmentThumbnail(
            attachment: photos[0],
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.zero,
          ),
          if (photos.length > 4)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${photos.length - 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
    }
  }

  Widget _buildEmptyCell(BuildContext context, bool hasEntries) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isCurrentMonth 
          ? (isToday ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent)
          : Colors.grey.withValues(alpha: 0.1),
      child: Stack(
        children: [
          _buildDayNumberOverlay(context),
          if (hasEntries)
            _buildEntryIndicator(context),
          if (isToday)
            _buildTodayHighlight(context),
        ],
      ),
    );
  }

  Widget _buildDayNumberOverlay(BuildContext context) {
    final hasPhotos = _getPhotoAttachments().isNotEmpty;
    
    // Don't show day numbers for non-current-month days
    if (!isCurrentMonth) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      top: 4,
      left: 4,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: hasPhotos 
              ? Colors.black.withValues(alpha: 0.6)
              : (isToday ? Theme.of(context).primaryColor : Colors.transparent),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$dayNumber',
            style: TextStyle(
              color: hasPhotos 
                  ? Colors.white
                  : (isToday 
                      ? Colors.white 
                      : Theme.of(context).textTheme.bodyMedium?.color),
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryIndicator(BuildContext context) {
    return Positioned(
      bottom: 4,
      left: 4,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
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