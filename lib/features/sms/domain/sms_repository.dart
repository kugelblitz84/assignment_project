import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_failure.dart';
import 'cost_breakdown.dart';
import 'send_sms_input.dart';
import 'sms_message.dart';
import '../data/sms_api_provider.dart';
import '../data/sms_repository_impl.dart';

final smsRepositoryProvider = Provider<SmsRepository>((ref) {
  return SmsRepositoryImpl(api: ref.watch(smsApiProvider));
});

abstract class SmsRepository {
  Future<SendSmsResult> sendSms({
    required String tenantId,
    required SendSmsInput input,
  });

  Future<CostBreakdown> getCostBreakdown({
    required String tenantId,
    required DateTime from,
    required DateTime to,
  });

  Future<MessagePage> getMessages({
    required String tenantId,
    String? cursor,
    int limit = 50,
    String currency = 'EUR',
  });
}

class MessagePage {
  const MessagePage({required this.items, required this.nextCursor});

  final List<SmsMessage> items;
  final String? nextCursor;
}
