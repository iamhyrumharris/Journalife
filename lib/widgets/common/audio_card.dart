import 'package:flutter/material.dart';
import '../../models/attachment.dart';

class AudioCard extends StatefulWidget {
  final Attachment audioAttachment;
  final VoidCallback? onPlay;
  final VoidCallback? onRemove;
  final bool isEditable;

  const AudioCard({
    super.key,
    required this.audioAttachment,
    this.onPlay,
    this.onRemove,
    this.isEditable = true,
  });

  @override
  State<AudioCard> createState() => _AudioCardState();
}

class _AudioCardState extends State<AudioCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final duration = widget.audioAttachment.metadata?['duration'] ?? 0;
    final formattedDuration = _formatDuration(duration);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.audiotrack,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio Recording',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDuration,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onPlay != null)
                IconButton(
                  onPressed: widget.onPlay,
                  icon: Icon(
                    Icons.play_circle_filled,
                    color: colorScheme.primary,
                    size: 32,
                  ),
                ),
              if (widget.isEditable && widget.onRemove != null)
                IconButton(
                  onPressed: widget.onRemove,
                  icon: Icon(
                    Icons.close,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Simple waveform visualization
          _buildWaveform(colorScheme),
        ],
      ),
    );
  }

  Widget _buildWaveform(ColorScheme colorScheme) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(30, (index) {
          // Generate pseudo-random heights for waveform effect
          final seed = widget.audioAttachment.id.hashCode + index;
          final height = 8 + (seed % 24).toDouble();
          
          return Container(
            width: 3,
            height: height,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '00:00';
    
    final int seconds = duration is int ? duration : int.tryParse(duration.toString()) ?? 0;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}