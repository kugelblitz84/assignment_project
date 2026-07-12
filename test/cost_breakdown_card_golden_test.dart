import 'package:assignment_project/core/theme/app_theme.dart';
import 'package:assignment_project/features/sms/domain/cost_breakdown.dart';
import 'package:assignment_project/features/sms/domain/money.dart';
import 'package:assignment_project/features/sms/presentation/widgets/cost_breakdown_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a stable cost breakdown card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final breakdown = CostBreakdown(
      currency: 'EUR',
      totalCost: Money.parse('0.1578', currency: 'EUR'),
      rows: [
        CostBreakdownRow(
          provider: 'TWILIO',
          totalCost: Money.parse('0.0079', currency: 'EUR'),
          messageCount: 2,
        ),
        CostBreakdownRow(
          provider: 'VONAGE',
          totalCost: Money.parse('0.1499', currency: 'EUR'),
          messageCount: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 380,
              child: CostBreakdownCard(breakdown: breakdown),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CostBreakdownCard),
      matchesGoldenFile('goldens/cost_breakdown_card.png'),
    );
  });
}