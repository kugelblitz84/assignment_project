import 'money.dart';

class CostBreakdown {
  const CostBreakdown({
    required this.currency,
    required this.totalCost,
    required this.rows,
  });

  final String currency;
  final Money totalCost;
  final List<CostBreakdownRow> rows;

  static CostBreakdown empty(String currency) {
    return CostBreakdown(
      currency: currency,
      totalCost: Money.zero(currency),
      rows: const [],
    );
  }
}

class CostBreakdownRow {
  const CostBreakdownRow({
    required this.provider,
    required this.totalCost,
    required this.messageCount,
  });

  final String provider;
  final Money totalCost;
  final int messageCount;
}
