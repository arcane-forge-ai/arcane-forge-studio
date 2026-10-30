import 'package:arcane_forge/models/image_generation_models.dart';
import 'package:arcane_forge/widgets/image_provenance_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads historical provenance from generation metadata', () {
    final generation = ImageGeneration(
      id: 'generation-1',
      assetId: 'asset-1',
      imagePath: '',
      parameters: const {},
      createdAt: DateTime.utc(2026, 8, 1),
      status: GenerationStatus.completed,
      metadata: const {
        'provenance': {
          'origin': 'historical_import',
          'source_timestamp': '2026-07-01T00:00:00Z',
        },
      },
    );

    expect(generation.isHistoricalImport, isTrue);
    expect(generation.originLabel, 'Historical');
    expect(generation.isExternalSource, isTrue);
  });

  testWidgets('historical badge is visually explicit', (tester) async {
    final generation = ImageGeneration(
      id: 'generation-1',
      assetId: 'asset-1',
      imagePath: '',
      parameters: const {},
      createdAt: DateTime.utc(2026, 8, 1),
      status: GenerationStatus.completed,
      metadata: const {
        'provenance': {'origin': 'historical_import'},
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: ImageProvenanceBadge(generation: generation)),
        ),
      ),
    );

    expect(find.text('HISTORICAL'), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });
}
