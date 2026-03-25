bool startsWithCjk(String text) {
  final trimmed = text.trimLeft();
  if (trimmed.isEmpty) {
    return false;
  }
  final codePoint = trimmed.runes.first;
  return codePoint >= 0x4E00 && codePoint <= 0x9FFF;
}

String localizedStreamHint({
  required bool refined,
  required String seedText,
}) {
  final zh = startsWithCjk(seedText);
  if (refined) {
    return zh ? '回答已优化' : 'Response refined';
  }
  return zh ? '回答未完成' : 'Response incomplete';
}

String localizedPartialHint(String seedText) {
  return startsWithCjk(seedText) ? '回答未完成' : 'Response incomplete';
}
