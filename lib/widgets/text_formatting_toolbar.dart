import 'package:flutter/material.dart';

class TextFormattingToolbar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onBold;
  final VoidCallback? onItalic;
  final VoidCallback? onUnderline;
  final VoidCallback? onBulletList;
  final VoidCallback? onNumberedList;
  final VoidCallback? onQuote;
  final VoidCallback? onHeading;

  const TextFormattingToolbar({
    super.key,
    required this.controller,
    this.onBold,
    this.onItalic,
    this.onUnderline,
    this.onBulletList,
    this.onNumberedList,
    this.onQuote,
    this.onHeading,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.12),
            width: 1,
          ),
          bottom: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FormatButton(
              icon: Icons.format_bold,
              tooltip: 'Bold',
              onPressed: () => _wrapSelectedText('**', '**'),
              colorScheme: colorScheme,
            ),
            _FormatButton(
              icon: Icons.format_italic,
              tooltip: 'Italic',
              onPressed: () => _wrapSelectedText('*', '*'),
              colorScheme: colorScheme,
            ),
            _FormatButton(
              icon: Icons.format_underlined,
              tooltip: 'Underline',
              onPressed: () => _wrapSelectedText('<u>', '</u>'),
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 24,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(width: 8),
            _FormatButton(
              icon: Icons.title,
              tooltip: 'Heading',
              onPressed: () => _addLinePrefix('## '),
              colorScheme: colorScheme,
            ),
            _FormatButton(
              icon: Icons.format_quote,
              tooltip: 'Quote',
              onPressed: () => _addLinePrefix('> '),
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 24,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(width: 8),
            _FormatButton(
              icon: Icons.format_list_bulleted,
              tooltip: 'Bullet List',
              onPressed: () => _addLinePrefix('• '),
              colorScheme: colorScheme,
            ),
            _FormatButton(
              icon: Icons.format_list_numbered,
              tooltip: 'Numbered List',
              onPressed: () => _addLinePrefix('1. '),
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  void _wrapSelectedText(String prefix, String suffix) {
    final selection = controller.selection;
    final text = controller.text;

    if (selection.isValid && !selection.isCollapsed) {
      // Text is selected
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix$selectedText$suffix',
      );
      
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + prefix.length + selectedText.length + suffix.length,
        ),
      );
    } else {
      // No text selected, insert at cursor
      final offset = selection.baseOffset;
      final newText = text.replaceRange(offset, offset, '$prefix$suffix');
      
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: offset + prefix.length,
        ),
      );
    }
  }

  void _addLinePrefix(String prefix) {
    final selection = controller.selection;
    final text = controller.text;
    final offset = selection.baseOffset;

    // Find the start of the current line
    int lineStart = offset;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    // Check if prefix already exists
    final lineEnd = text.indexOf('\n', lineStart);
    final currentLine = lineEnd == -1 
        ? text.substring(lineStart)
        : text.substring(lineStart, lineEnd);

    String newText;
    int newOffset;

    if (currentLine.startsWith(prefix)) {
      // Remove prefix
      newText = text.replaceRange(lineStart, lineStart + prefix.length, '');
      newOffset = offset - prefix.length;
    } else {
      // Add prefix
      newText = text.replaceRange(lineStart, lineStart, prefix);
      newOffset = offset + prefix.length;
    }

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

class _FormatButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;

  const _FormatButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}