import 'package:flutter/material.dart';

import '../models/image_generation_models.dart';

class ImageProvenanceBadge extends StatelessWidget {
  final ImageGeneration generation;
  final bool compact;
  final bool showArcaneForge;

  const ImageProvenanceBadge({
    super.key,
    required this.generation,
    this.compact = false,
    this.showArcaneForge = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!showArcaneForge && !generation.isExternalSource) {
      return const SizedBox.shrink();
    }

    final style = _styleForOrigin(generation.origin);
    return Semantics(
      label: '${generation.originLabel} image',
      child: Container(
        key: ValueKey('image-origin-${generation.id}'),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: style.foreground.withValues(alpha: 0.8)),
          boxShadow: generation.isHistoricalImport
              ? const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, color: style.foreground, size: compact ? 12 : 15),
            const SizedBox(width: 5),
            Text(
              generation.originLabel.toUpperCase(),
              style: TextStyle(
                color: style.foreground,
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ProvenanceStyle _styleForOrigin(String origin) {
    switch (origin) {
      case 'historical_import':
        return const _ProvenanceStyle(
          background: Color(0xFF3E2A10),
          foreground: Color(0xFFFFC857),
          icon: Icons.inventory_2_outlined,
        );
      case 'external_generated':
        return const _ProvenanceStyle(
          background: Color(0xFF123449),
          foreground: Color(0xFF6FD3FF),
          icon: Icons.cloud_download_outlined,
        );
      case 'user_authored':
        return const _ProvenanceStyle(
          background: Color(0xFF173D31),
          foreground: Color(0xFF71E1B4),
          icon: Icons.brush_outlined,
        );
      default:
        return const _ProvenanceStyle(
          background: Color(0xFF30254A),
          foreground: Color(0xFFCBB5FF),
          icon: Icons.auto_awesome,
        );
    }
  }
}

class HistoricalImageCountBadge extends StatelessWidget {
  final int count;
  final bool compact;

  const HistoricalImageCountBadge({
    super.key,
    required this.count,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Semantics(
      label: '$count historical ${count == 1 ? 'image' : 'images'}',
      child: Container(
        key: const Key('historical-image-count-badge'),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF3E2A10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xCCFFC857)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: const Color(0xFFFFC857),
              size: compact ? 12 : 15,
            ),
            const SizedBox(width: 5),
            Text(
              compact ? 'HISTORICAL $count' : '$count HISTORICAL',
              style: TextStyle(
                color: const Color(0xFFFFC857),
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProvenanceStyle {
  final Color background;
  final Color foreground;
  final IconData icon;

  const _ProvenanceStyle({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}
