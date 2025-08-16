import 'package:flutter/material.dart';
import '../models/attachment.dart';
import '../utils/responsive_breakpoints.dart';
import 'photo_collage_widget.dart';
import 'entry_content_widget.dart';

class ResponsiveEntryLayout extends StatelessWidget {
  final List<Attachment> photos;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final FocusNode titleFocusNode;
  final FocusNode contentFocusNode;
  final List<Attachment> attachments;
  final Function(int index) onPhotoTap;
  final Function(Attachment) onRemoveAttachment;

  const ResponsiveEntryLayout({
    super.key,
    required this.photos,
    required this.titleController,
    required this.contentController,
    required this.titleFocusNode,
    required this.contentFocusNode,
    required this.attachments,
    required this.onPhotoTap,
    required this.onRemoveAttachment,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutType = ResponsiveBreakpoints.getLayoutTypeFromWidth(constraints.maxWidth);
        
        // Constrain the entire layout to max width for very large screens
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveBreakpoints.getMaxContainerWidth(),
            ),
            child: _buildLayoutForType(context, layoutType),
          ),
        );
      },
    );
  }

  Widget _buildLayoutForType(BuildContext context, LayoutType layoutType) {
    switch (layoutType) {
      case LayoutType.mobile:
        return _buildMobileLayout(context, layoutType);
      case LayoutType.tablet:
        return _buildTabletLayout(context, layoutType);
      case LayoutType.desktop:
        return _buildDesktopLayout(context, layoutType);
    }
  }

  Widget _buildMobileLayout(BuildContext context, LayoutType layoutType) {
    return Padding(
      padding: ResponsiveBreakpoints.getContentPadding(layoutType),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo collage - full width
          PhotoCollageWidget(
            photos: photos,
            onPhotoTap: onPhotoTap,
          ),
          
          // Content area
          EntryContentWidget(
            titleController: titleController,
            contentController: contentController,
            titleFocusNode: titleFocusNode,
            contentFocusNode: contentFocusNode,
            attachments: attachments,
            onRemoveAttachment: onRemoveAttachment,
            layoutType: layoutType,
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, LayoutType layoutType) {
    return Padding(
      padding: ResponsiveBreakpoints.getContentPadding(layoutType),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo collage - constrained width, centered
          Center(
            child: ConstrainedBox(
              constraints: ResponsiveBreakpoints.getPhotoCollageConstraints(layoutType),
              child: PhotoCollageWidget(
                photos: photos,
                onPhotoTap: onPhotoTap,
              ),
            ),
          ),
          
          // Content area
          EntryContentWidget(
            titleController: titleController,
            contentController: contentController,
            titleFocusNode: titleFocusNode,
            contentFocusNode: contentFocusNode,
            attachments: attachments,
            onRemoveAttachment: onRemoveAttachment,
            layoutType: layoutType,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, LayoutType layoutType) {
    return Padding(
      padding: ResponsiveBreakpoints.getContentPadding(layoutType),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content area - flexible width
          Expanded(
            child: EntryContentWidget(
              titleController: titleController,
              contentController: contentController,
              titleFocusNode: titleFocusNode,
              contentFocusNode: contentFocusNode,
              attachments: attachments,
              onRemoveAttachment: onRemoveAttachment,
              layoutType: layoutType,
            ),
          ),
          
          // Spacing between sections
          SizedBox(width: ResponsiveBreakpoints.getSectionSpacing(layoutType)),
          
          // Photo collage - simplified fixed 2x3 grid
          PhotoCollageWidget(
            photos: photos,
            onPhotoTap: onPhotoTap,
            isDesktopLayout: true,
            maxPhotosToShow: 6,
          ),
        ],
      ),
    );
  }
}