import 'package:assignment_project/core/error/app_failure.dart';
import 'package:assignment_project/features/sms/domain/cost_breakdown.dart';
import 'package:assignment_project/features/sms/domain/money.dart';
import 'package:assignment_project/features/sms/domain/send_sms_input.dart';
import 'package:assignment_project/features/sms/domain/sms_message.dart';
import 'package:assignment_project/features/sms/domain/sms_repository.dart';
import 'package:assignment_project/features/sms/domain/sms_status.dart';
import 'package:assignment_project/features/sms/presentation/sms_console_screen.dart';
import 'package:assignment_project/features/tenant/tenant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('invalid form values are rejected before the repository is called', (
    tester,
  ) async {
    final repository = _TestSmsRepository();
    await _pumpSmsConsole(tester, repository);

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), 'not-a-phone-number');
    await tester.enterText(fields.at(1), '');

    final sendButton = _sendButtonFinder();
    await tester.ensureVisible(sendButton);
    await tester.tap(sendButton);
    await tester.pump();

    expect(
      find.text(
        'Phone number must be in E.164 format, for example +4915112345678.',
      ),
      findsOneWidget,
    );
    expect(find.text('Message body is required.'), findsOneWidget);
    expect(repository.sendCalls, 0);
  });

  testWidgets('successful send uses the selected tenant and refreshes history', (
    tester,
  ) async {
    final repository = _TestSmsRepository();
    await _pumpSmsConsole(tester, repository);

    final sendButton = _sendButtonFinder();
    await tester.ensureVisible(sendButton);
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    expect(repository.sendCalls, 1);
    expect(repository.lastSendTenantId, Tenant.demoTenants.first.id);
    expect(
      find.text(
        'SMS accepted by TWILIO. Current status: Accepted.',
      ),
      findsOneWidget,
    );
    expect(find.text('+4915*****78'), findsOneWidget);
    expect(find.text('Cost: EUR 0.0079'), findsOneWidget);
  });

  testWidgets('offline send shows a recoverable error and restores the button', (
    tester,
  ) async {
    final repository = _TestSmsRepository(sendFailure: AppFailure.offline());
    await _pumpSmsConsole(tester, repository);

    final sendButton = _sendButtonFinder();
    await tester.ensureVisible(sendButton);
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    expect(repository.sendCalls, 1);
    expect(
      find.text(
        'You appear to be offline. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    expect(find.text('Sending…'), findsNothing);
    expect(_sendButtonFinder(), findsOneWidget);
  });
}

Finder _sendButtonFinder() {
  return find.ancestor(
    of: find.text('Send SMS'),
    matching: find.byType(FilledButton),
  );
}

Future<void> _pumpSmsConsole(
  WidgetTester tester,
  SmsRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        smsRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: SmsConsoleScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

class _TestSmsRepository implements SmsRepository {
  _TestSmsRepository({this.sendFailure});

  final AppFailure? sendFailure;
  final Map<String, List<SmsMessage>> _messagesByTenant = {};

  int sendCalls = 0;
  String? lastSendTenantId;

  @override
  Future<SendSmsResult> sendSms({
    required String tenantId,
    required SendSmsInput input,
  }) async {
    sendCalls += 1;
    lastSendTenantId = tenantId;

    if (sendFailure != null) {
      throw sendFailure!;
    }

    final cost = Money.parse('0.0079', currency: 'EUR');
    final message = SmsMessage(
      messageId: 'SM-widget-1',
      maskedRecipient: '+4915*****78',
      status: SmsStatus.accepted,
      segmentCount: 1,
      cost: cost,
      sentAt: DateTime.utc(2026, 7, 12, 9),
    );

    _messagesByTenant.putIfAbsent(tenantId, () => []).insert(0, message);

    return SendSmsResult(
      messageId: message.messageId,
      provider: 'TWILIO',
      status: SmsStatus.accepted,
      segmentCount: 1,
      cost: cost,
      currency: 'EUR',
    );
  }

  @override
  Future<CostBreakdown> getCostBreakdown({
    required String tenantId,
    required DateTime from,
    required DateTime to,
  }) async {
    final messageCount = _messagesByTenant[tenantId]?.length ?? 0;
    final total = Money.parse(
      messageCount == 0 ? '0.0000' : '0.0079',
      currency: 'EUR',
    );

    return CostBreakdown(
      currency: 'EUR',
      totalCost: total,
      rows: messageCount == 0
          ? const []
          : [
              CostBreakdownRow(
                provider: 'TWILIO',
                totalCost: total,
                messageCount: messageCount,
              ),
            ],
    );
  }

  @override
  Future<MessagePage> getMessages({
    required String tenantId,
    String? cursor,
    int limit = 50,
    String currency = 'EUR',
  }) async {
    return MessagePage(
      items: List.unmodifiable(_messagesByTenant[tenantId] ?? const []),
      nextCursor: null,
    );
  }
}
