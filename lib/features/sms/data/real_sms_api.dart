import '../../../core/network/api_client.dart';
import 'sms_api.dart';
import 'sms_dtos.dart';

class RealSmsApi implements SmsApi {
  const RealSmsApi({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<SendSmsResponseDto> sendSms({
    required String tenantId,
    required SendSmsRequestDto request,
  }) async {
    final json = await _client.post(
      '/api/v1/sms/send',
      tenantId: tenantId,
      body: request.toJson(),
      expectedStatusCode: 202,
    );

    return SendSmsResponseDto.fromJson(json);
  }

  @override
  Future<CostBreakdownDto> getCostBreakdown({
    required String tenantId,
    required DateTime from,
    required DateTime to,
  }) async {
    final json = await _client.get(
      '/api/v1/sms/cost/breakdown',
      tenantId: tenantId,
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
      expectedStatusCode: 200,
    );

    return CostBreakdownDto.fromJson(json);
  }

  @override
  Future<MessageHistoryResponseDto> getMessages({
    required String tenantId,
    String? cursor,
    int limit = 50,
  }) async {
    final json = await _client.get(
      '/api/v1/sms/messages',
      tenantId: tenantId,
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit.toString(),
      },
      expectedStatusCode: 200,
    );

    return MessageHistoryResponseDto.fromJson(json);
  }
}
