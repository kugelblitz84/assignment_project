class Money implements Comparable<Money> {
  const Money({
    required this.currency,
    required this.minorUnits,
    this.scale = 4,
  });

  final String currency;
  final BigInt minorUnits;
  final int scale;

  factory Money.zero(String currency, {int scale = 4}) {
    return Money(currency: currency, minorUnits: BigInt.zero, scale: scale);
  }

  factory Money.parse(String value, {required String currency, int scale = 4}) {
    final trimmed = value.trim();
    final regex = RegExp(r'^-?\d+(\.\d+)?$');
    if (!regex.hasMatch(trimmed)) {
      throw FormatException('Invalid decimal money string: $value');
    }

    final negative = trimmed.startsWith('-');
    final unsigned = negative ? trimmed.substring(1) : trimmed;
    final parts = unsigned.split('.');
    final whole = parts[0];
    final fraction = parts.length == 2 ? parts[1] : '';

    if (fraction.length > scale) {
      throw FormatException('Money string has more than $scale decimal places: $value');
    }

    final normalizedFraction = fraction.padRight(scale, '0');
    final factor = BigInt.from(10).pow(scale);
    final units = BigInt.parse(whole) * factor + BigInt.parse(normalizedFraction.isEmpty ? '0' : normalizedFraction);

    return Money(
      currency: currency,
      minorUnits: negative ? -units : units,
      scale: scale,
    );
  }

  Money operator +(Money other) {
    _ensureCompatible(other);
    return Money(currency: currency, minorUnits: minorUnits + other.minorUnits, scale: scale);
  }

  Money operator -(Money other) {
    _ensureCompatible(other);
    return Money(currency: currency, minorUnits: minorUnits - other.minorUnits, scale: scale);
  }

  Money multiplyByInt(int multiplier) {
    return Money(currency: currency, minorUnits: minorUnits * BigInt.from(multiplier), scale: scale);
  }

  String toDecimalString() {
    final negative = minorUnits.isNegative;
    final absolute = minorUnits.abs();
    final factor = BigInt.from(10).pow(scale);
    final whole = absolute ~/ factor;
    final fraction = (absolute % factor).toString().padLeft(scale, '0');
    return '${negative ? '-' : ''}$whole.$fraction';
  }

  String format() => '$currency ${toDecimalString()}';

  void _ensureCompatible(Money other) {
    if (currency != other.currency || scale != other.scale) {
      throw ArgumentError('Cannot operate on different money currencies/scales.');
    }
  }

  @override
  int compareTo(Money other) {
    _ensureCompatible(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  String toString() => format();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Money &&
            other.currency == currency &&
            other.scale == scale &&
            other.minorUnits == minorUnits;
  }

  @override
  int get hashCode => Object.hash(currency, minorUnits, scale);
}
