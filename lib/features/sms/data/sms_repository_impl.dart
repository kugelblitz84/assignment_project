import '../domain/cost_breakdown.dart';
import '../domain/send_sms_input.dart';
import '../domain/sms_repository.dart';
import 'sms_api.dart';
import 'sms_dtos.dart';

class SmsRepositoryImpl implements SmsRepository {
  const SmsRepositoryImpl({required SmsApi api}) : _api = api;

  final SmsApi _api;

  @override
  Future<SendSmsResult> sendSms({
    required String tenantId,
    required SendSmsInput input,
  }) async {
    final dto = await _api.sendSms(
      tenantId: tenantId,
      request: SendSmsRequestDto.fromDomain(input),
    );
    return dto.toDomain();
  }

  @override
  Future<CostBreakdown> getCostBreakdown({
    required String tenantId,
    required DateTime from,
    required DateTime to,
  }) async {
    final dto = await _api.getCostBreakdown(
      tenantId: tenantId,
      from: from,
      to: to,
    );
    return dto.toDomain();
  }

  @override
  Future<MessagePage> getMessages({
    required String tenantId,
    String? cursor,
    int limit = 50,
    String currency = 'EUR',
  }) async {
    final dto = await _api.getMessages(
      tenantId: tenantId,
      cursor: cursor,
      limit: limit,
    );

    return MessagePage(
      items: dto.items.map((item) => item.toDomain(currency)).toList(),
      nextCursor: dto.nextCursor,
    );
  }
}
