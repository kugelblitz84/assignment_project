import 'money.dart';
import 'sms_status.dart';

class SendSmsInput {
  const SendSmsInput({
    required this.to,
    required this.body,
    this.referenceId,
  });

  final String to;
  final String body;
  final String? referenceId;
}

class SendSmsResult {
  const SendSmsResult({
    required this.messageId,
    required this.provider,
    required this.status,
    required this.segmentCount,
    required this.cost,
    required this.currency,
  });

  final String messageId;
  final String provider;
  final SmsStatus status;
  final int segmentCount;
  final Money cost;
  final String currency;
}
