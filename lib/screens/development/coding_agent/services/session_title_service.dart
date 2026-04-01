import 'package:intl/intl.dart';

class SessionTitleService {
  String defaultTimestampTitle() {
    return 'Session ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}';
  }

  String fromUserMessage(String rawMessage) {
    final String cleaned = rawMessage
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[#*_`>\[\]]'), '')
        .trim();

    if (cleaned.isEmpty) {
      return defaultTimestampTitle();
    }

    String title = cleaned;
    final RegExp sentenceBreak = RegExp(r'[.!?]');
    final Match? sentence = sentenceBreak.firstMatch(title);
    if (sentence != null && sentence.start > 0) {
      title = title.substring(0, sentence.start).trim();
    }

    final List<String> words = title
        .split(' ')
        .map((String word) => word.trim())
        .where((String word) => word.isNotEmpty)
        .toList();

    if (words.length > 8) {
      title = words.take(8).join(' ');
    }

    if (title.length > 60) {
      title = title.substring(0, 60).trimRight();
    }

    if (title.isEmpty) {
      return defaultTimestampTitle();
    }

    return title;
  }
}
