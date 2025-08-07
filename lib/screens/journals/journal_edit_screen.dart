import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/journal.dart';
import '../../providers/journal_provider.dart';

class JournalEditScreen extends ConsumerStatefulWidget {
  final Journal? journal;

  const JournalEditScreen({super.key, this.journal});

  @override
  ConsumerState<JournalEditScreen> createState() => _JournalEditScreenState();
}

class _JournalEditScreenState extends ConsumerState<JournalEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedColor;
  String? _selectedIcon;
  bool _isSaving = false;

  bool get _isEditing => widget.journal != null;

  // Predefined colors for journals
  final List<String> _colors = [
    'FF2196F3', // Blue
    'FF4CAF50', // Green
    'FFF44336', // Red
    'FFFF9800', // Orange
    'FF9C27B0', // Purple
    'FF607D8B', // Blue Grey
    'FF795548', // Brown
    'FFFF5722', // Deep Orange
    'FF3F51B5', // Indigo
    'FF009688', // Teal
  ];

  // Predefined icons for journals
  final List<String> _icons = [
    '📓', '📔', '📕', '📗', '📘', '📙',
    '📚', '📖', '✍️', '📝', '🖊️', '✏️',
    '💭', '💡', '🌟', '❤️', '🎯', '🌈',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final journal = widget.journal!;
      _nameController.text = journal.name;
      _descriptionController.text = journal.description;
      _selectedColor = journal.color;
      _selectedIcon = journal.icon;
    } else {
      // Set default color for new journals
      _selectedColor = _colors.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Journal' : 'Create Journal'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveJournal,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview card
              _buildPreviewCard(),
              const SizedBox(height: 24),

              // Journal Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Journal Name *',
                  hintText: 'My Daily Journal',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a journal name';
                  }
                  if (value.trim().length > 50) {
                    return 'Journal name must be 50 characters or less';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What will you write about in this journal?',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                validator: (value) {
                  if (value != null && value.length > 200) {
                    return 'Description must be 200 characters or less';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              // Color Selection
              Text(
                'Color Theme',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _colors.map((colorHex) => _buildColorOption(colorHex)).toList(),
              ),
              const SizedBox(height: 24),

              // Icon Selection
              Text(
                'Icon (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildIconOption(null), // No icon option
                  ..._icons.map((icon) => _buildIconOption(icon)).toList(),
                ],
              ),
              const SizedBox(height: 32),

              // Additional options for editing
              if (_isEditing) ...[
                const Divider(),
                const SizedBox(height: 16),
                _buildAdvancedOptions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final color = _selectedColor != null 
        ? Color(int.parse(_selectedColor!, radix: 16))
        : Theme.of(context).primaryColor;

    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            if (_selectedIcon != null)
              Text(
                _selectedIcon!,
                style: const TextStyle(fontSize: 32),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.book, color: Colors.white, size: 24),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameController.text.isEmpty ? 'Journal Name' : _nameController.text,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _nameController.text.isEmpty ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _descriptionController.text.isEmpty 
                        ? 'Journal description will appear here'
                        : _descriptionController.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _descriptionController.text.isEmpty 
                          ? Colors.grey 
                          : Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(String colorHex) {
    final color = Color(int.parse(colorHex, radix: 16));
    final isSelected = _selectedColor == colorHex;

    return GestureDetector(
      onTap: () => setState(() => _selectedColor = colorHex),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 24)
            : null,
      ),
    );
  }

  Widget _buildIconOption(String? icon) {
    final isSelected = _selectedIcon == icon;
    final isNoneOption = icon == null;

    return GestureDetector(
      onTap: () => setState(() => _selectedIcon = icon),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: isNoneOption
              ? Icon(
                  Icons.close,
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                  size: 20,
                )
              : Text(
                  icon,
                  style: const TextStyle(fontSize: 24),
                ),
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions() {
    final journal = widget.journal!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced Options',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        ListTile(
          leading: const Icon(Icons.people),
          title: const Text('Sharing Settings'),
          subtitle: Text(journal.isShared ? 'Shared with others' : 'Private journal'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Navigate to sharing settings - will be implemented later
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sharing settings coming soon')),
            );
          },
        ),
        
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Sync Settings'),
          subtitle: const Text('WebDAV and backup options'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Navigate to sync settings - will be implemented later
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sync settings coming soon')),
            );
          },
        ),
      ],
    );
  }

  void _saveJournal() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final journalNotifier = ref.read(journalProvider.notifier);
      
      if (_isEditing) {
        final updatedJournal = widget.journal!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          color: _selectedColor,
          icon: _selectedIcon,
        );
        
        await journalNotifier.updateJournal(updatedJournal);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Journal updated successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        await journalNotifier.createJournal(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          color: _selectedColor,
          icon: _selectedIcon,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Journal created successfully')),
          );
          Navigator.pop(context);
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving journal: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}