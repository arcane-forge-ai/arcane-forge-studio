import 'package:flutter/material.dart';
import '../../game_design_assistant/models/api_models.dart';
import 'tags_chips.dart';
import 'package:url_launcher/url_launcher.dart';

/// Expandable detail panel for displaying full entry information
class EntryDetailPanel extends StatelessWidget {
  final KnowledgeBaseFile entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const EntryDetailPanel({
    Key? key,
    required this.entry,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        border: Border(
          top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
          bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          if (entry.description != null && entry.description!.isNotEmpty) ...[
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              entry.description!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // URL for link entries
          if (entry.entryType == 'link' && entry.url != null) ...[
            const Text(
              'URL',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _launchURL(entry.url!),
              child: Text(
                entry.url!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Contact info for contact entries
          if (entry.entryType == 'contact' && entry.contactInfo != null) ...[
            const Text(
              'Contact Information',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            ...entry.contactInfo!.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      '${e.key.toUpperCase()}:',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 12),
          ],

          // All tags
          if (entry.tags.isNotEmpty) ...[
            const Text(
              'Tags',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            TagsChips(tags: entry.tags, maxVisible: 100),
            const SizedBox(height: 12),
          ],

          // Metadata
          if (entry.metadata != null && 
              entry.metadata!.containsKey('content') &&
              entry.metadata!['content'].toString().isNotEmpty) ...[
            const Text(
              'Content',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              entry.metadata!['content'].toString(),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Action buttons
          Row(
            children: [
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Metadata'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
              const SizedBox(width: 8),
              if (onDelete != null)
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
