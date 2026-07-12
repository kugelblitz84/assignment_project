import 'package:assignment_project/core/error/app_failure.dart';
import 'package:assignment_project/features/sms/data/fake_sms_api.dart';
import 'package:assignment_project/features/sms/data/sms_api.dart';
import 'package:assignment_project/features/sms/data/sms_dtos.dart';
import 'package:assignment_project/features/sms/data/sms_repository_impl.dart';
import 'package:assignment_project/features/sms/domain/money.dart';
import 'package:assignment_project/features/sms/domain/send_sms_input.dart';
import 'package:assignment_project/features/sms/domain/sms_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('calculates 0.0079 × 3 exactly', () {
      final rate = Money.parse('0.0079', currency: 'EUR');

      final result = rate.multiplyByInt(3);

      expect(result.minorUnits, BigInt.from(237));
      expect(result.toDecimalString(), '0.0237');
    });

    test('pads valid decimal values to the configured four-place scale', () {
      final value = Money.parse('1.2', currency: 'EUR');

      expect(value.minorUnits, BigInt.from(12000));
      expect(value.toDecimalString(), '1.2000');
    });

    test('rejects values with more precision than the configured scale', () {
      expect(
        () => Money.parse('0.00791', currency: 'EUR'),
        throwsA(isA<FormatException>()),
      );
    });

    test('does not allow arithmetic across different currencies', () {
      final euros = Money.parse('1.0000', currency: 'EUR');
      final dollars = Money.parse('1.0000', currency: 'USD');

      expect(() => euros + dollars, throwsArgumentError);
    });
  });

  group('SmsRepositoryImpl', () {
    test('forwards tenant ID and maps a send response into domain types', () async {
      final api = _RecordingSmsApi();
      final repository = SmsRepositoryImpl(api: api);

      final result = await repository.sendSms(
        tenantId: 'tenant-123',
        input: const SendSmsInput(
          to: ' +4915112345678 ',
          body: ' Your code is 123456 ',
          referenceId: ' otp-1 ',
        ),
      );

      expect(api.lastTenantId, 'tenant-123');
      expect(api.lastRequest?.to, '+4915112345678');
      expect(api.lastRequest?.body, 'Your code is 123456');
      expect(api.lastRequest?.referenceId, 'otp-1');

      expect(result.messageId, 'SM-test-1');
      expect(result.status, SmsStatus.accepted);
      expect(result.segmentCount, 3);
      expect(result.cost.toDecimalString(), '0.0237');
    });

    test('maps message DTO values without dynamic casts at the call site', () async {
      final api = _RecordingSmsApi();
      final repository = SmsRepositoryImpl(api: api);

      final page = await repository.getMessages(
        tenantId: 'tenant-456',
        currency: 'EUR',
      );

      expect(api.lastTenantId, 'tenant-456');
      expect(page.items, hasLength(1));
      expect(page.items.single.status, SmsStatus.delivered);
      expect(page.items.single.cost.toDecimalString(), '0.0079');
      expect(page.items.single.sentAt, DateTime.utc(2026, 7, 12, 8, 30));
      expect(page.nextCursor, 'next-page');
    });
  });

  group('FakeSmsApi', () {
    test('keeps sent messages isolated by tenant and calculates segments exactly', () async {
      final api = FakeSmsApi(mode: FakeNetworkMode.normal);
      const tenantA = 'unit-test-tenant-a';
      const tenantB = 'unit-test-tenant-b';

      final result = await api.sendSms(
        tenantId: tenantA,
        request: SendSmsRequestDto(
          to: '+4915112345678',
          body: List.filled(321, 'a').join(),
        ),
      );

      final tenantAMessages = await api.getMessages(tenantId: tenantA);
      final tenantBMessages = await api.getMessages(tenantId: tenantB);

      expect(result.segmentCount, 3);
      expect(result.cost, '0.0237');
      expect(tenantAMessages.items, hasLength(1));
      expect(tenantAMessages.items.single.recipient, '+4915*****78');
      expect(tenantBMessages.items, isEmpty);
    });

    test('returns a typed offline failure instead of hanging', () async {
      final api = FakeSmsApi(mode: FakeNetworkMode.offline);

      await expectLater(
        api.getMessages(tenantId: 'offline-test-tenant'),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.type,
            'type',
            AppFailureType.offline,
          ),
        ),
      );
    });

    test('preserves Retry-After information for a 429 response', () async {
      final api = FakeSmsApi(mode: FakeNetworkMode.rateLimited);

      await expectLater(
        api.getCostBreakdown(
          tenantId: 'rate-limit-test-tenant',
          from: DateTime.utc(2026, 7, 1),
          to: DateTime.utc(2026, 8, 1),
        ),
        throwsA(
          isA<AppFailure>()
              .having(
                (failure) => failure.type,
                'type',
                AppFailureType.rateLimited,
              )
              .having(
                (failure) => failure.retryAfter,
                'retryAfter',
                const Duration(seconds: 10),
              ),
        ),
      );
    });
  });
}

class _RecordingSmsApi implements SmsApi {
  String? lastTenantId;
  SendSmsRequestDto? lastRequest;

  @override
  Future<SendSmsResponseDto> sendSms({
    required String tenantId,
    required SendSmsRequestDto request,
  }) async {
    lastTenantId = tenantId;
    lastRequest = request;

    return const SendSmsResponseDto(
      messageId: 'SM-test-1',
      provider: 'TWILIO',
      status: 'ACCEPTED',
      segmentCount: 3,
      cost: '0.0237',
      currency: 'EUR',
    );
  }

  @override
  Future<CostBreakdownDto> getCostBreakdown({
    required String tenantId,
    required DateTime from,
    required DateTime to,
  }) async {
    lastTenantId = tenantId;

    return const CostBreakdownDto(
      currency: 'EUR',
      totalCost: '0.0079',
      rows: [
        CostBreakdownRowDto(
          provider: 'TWILIO',
          totalCost: '0.0079',
          messageCount: 1,
        ),
      ],
    );
  }

  @override
  Future<MessageHistoryResponseDto> getMessages({
    required String tenantId,
    String? cursor,
    int limit = 50,
  }) async {
    lastTenantId = tenantId;

    return const MessageHistoryResponseDto(
      items: [
        SmsMessageDto(
          messageId: 'SM-history-1',
          recipient: '+4915*****78',
          status: 'DELIVERED',
          segmentCount: 1,
          cost: '0.0079',
          sentAt: '2026-07-12T08:30:00.000Z',
        ),
      ],
      nextCursor: 'next-page',
    );
  }
}
