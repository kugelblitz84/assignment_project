import 'sms_dtos.dart';

abstract class SmsApi {
  Future<SendSmsResponseDto> sendSms({
    required String tenantId,
    required SendSmsRequestDto request,
  });

  Future<CostBreakdownDto> getCostBreakdown({
    required String tenantId,
    required DateTime from,
    required DateTime to,
  });

  Future<MessageHistoryResponseDto> getMessages({
    required String tenantId,
    String? cursor,
    int limit = 50,
  });
}
