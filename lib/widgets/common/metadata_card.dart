import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MetadataCard extends StatelessWidget {
  final String journalName;
  final DateTime? createdAt;
  final String? locationName;
  final String? weather;
  final bool showAllMetadata;

  const MetadataCard({
    super.key,
    required this.journalName,
    this.createdAt,
    this.locationName,
    this.weather,
    this.showAllMetadata = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormatter = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormatter = DateFormat('h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (createdAt != null) ...[
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateFormatter.format(createdAt!),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        timeFormatter.format(createdAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showAllMetadata) const SizedBox(height: 16),
          ],
          
          if (showAllMetadata) ...[
            _buildMetadataRow(
              icon: Icons.book,
              label: 'Journal',
              value: journalName,
              theme: theme,
              colorScheme: colorScheme,
            ),
            
            if (locationName != null && locationName!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildMetadataRow(
                icon: Icons.location_on,
                label: 'Location',
                value: locationName!,
                theme: theme,
                colorScheme: colorScheme,
              ),
            ],
            
            if (weather != null) ...[
              const SizedBox(height: 12),
              _buildMetadataRow(
                icon: Icons.wb_sunny,
                label: 'Weather',
                value: weather!,
                theme: theme,
                colorScheme: colorScheme,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}