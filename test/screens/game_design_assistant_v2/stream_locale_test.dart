import 'package:arcane_forge/screens/game_design_assistant_v2/utils/stream_locale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stream locale hints', () {
    test('uses chinese hints for cjk leading text', () {
      expect(startsWithCjk('  你好，世界'), isTrue);
      expect(localizedStreamHint(refined: true, seedText: '你好'), '回答已优化');
      expect(localizedStreamHint(refined: false, seedText: '你好'), '回答未完成');
      expect(localizedPartialHint('你好'), '回答未完成');
    });

    test('uses english hints for non-cjk leading text', () {
      expect(startsWithCjk('  Hello world'), isFalse);
      expect(
        localizedStreamHint(refined: true, seedText: 'Hello world'),
        'Response refined',
      );
      expect(
        localizedStreamHint(refined: false, seedText: 'Hello world'),
        'Response incomplete',
      );
      expect(localizedPartialHint('Hello world'), 'Response incomplete');
    });

    test('defaults to english for empty content', () {
      expect(startsWithCjk(''), isFalse);
      expect(localizedStreamHint(refined: false, seedText: ''),
          'Response incomplete');
    });
  });
}
