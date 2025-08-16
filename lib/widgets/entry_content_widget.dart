import 'package:flutter/material.dart';
import '../models/attachment.dart';
import '../utils/responsive_breakpoints.dart';
import 'attachment_list_widget.dart';

class EntryContentWidget extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController contentController;
  final FocusNode titleFocusNode;
  final FocusNode contentFocusNode;
  final List<Attachment> attachments;
  final Function(Attachment) onRemoveAttachment;
  final LayoutType layoutType;

  const EntryContentWidget({
    super.key,
    required this.titleController,
    required this.contentController,
    required this.titleFocusNode,
    required this.contentFocusNode,
    required this.attachments,
    required this.onRemoveAttachment,
    required this.layoutType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title TextField
        TextField(
          controller: titleController,
          focusNode: titleFocusNode,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 28,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
          cursorColor: colorScheme.primary,
          decoration: const InputDecoration(
            hintText: 'A moment to remember',
            hintStyle: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 28,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
            filled: false,
          ),
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
        ),

        const SizedBox(height: 24),

        // Body TextField
        TextField(
          controller: contentController,
          focusNode: contentFocusNode,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 17,
            height: 1.6,
            fontWeight: FontWeight.w400,
          ),
          cursorColor: colorScheme.primary,
          decoration: const InputDecoration(
            hintText: 'Today brought new perspectives and quiet revelations that shifted my understanding. The morning light filtered through familiar windows, casting shadows that seemed to whisper stories of transformation...',
            hintStyle: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 17,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
            filled: false,
          ),
          maxLines: null,
          minLines: layoutType == LayoutType.desktop ? 12 : 8,
          textCapitalization: TextCapitalization.sentences,
        ),

        // Attachment list
        AttachmentListWidget(
          attachments: attachments,
          onRemove: onRemoveAttachment,
        ),
      ],
    );
  }
}