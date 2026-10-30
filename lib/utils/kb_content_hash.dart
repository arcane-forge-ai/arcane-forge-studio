/// Returns the existing signed FNV-1a manifest hash on both Dart VM and web.
String kbContentHash(List<int> bytes) {
  final BigInt prime = BigInt.parse('100000001b3', radix: 16);
  final BigInt mask = (BigInt.one << 64) - BigInt.one;
  BigInt hash = BigInt.parse('cbf29ce484222325', radix: 16);

  for (final int value in bytes) {
    hash = ((hash ^ BigInt.from(value)) * prime) & mask;
  }

  // Existing desktop manifests use signed hex, including a leading minus sign.
  return hash.toSigned(64).toRadixString(16).padLeft(16, '0');
}
