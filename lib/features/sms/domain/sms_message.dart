import 'money.dart';
import 'sms_status.dart';

class SmsMessage {
  const SmsMessage({
    required this.messageId,
    required this.maskedRecipient,
    required this.status,
    required this.segmentCount,
    required this.cost,
    required this.sentAt,
  });

  final String messageId;
  final String maskedRecipient;
  final SmsStatus status;
  final int segmentCount;
  final Money cost;
  final DateTime sentAt;

  SmsMessage copyWith({
    String? messageId,
    String? maskedRecipient,
    SmsStatus? status,
    int? segmentCount,
    Money? cost,
    DateTime? sentAt,
  }) {
    return SmsMessage(
      messageId: messageId ?? this.messageId,
      maskedRecipient: maskedRecipient ?? this.maskedRecipient,
      status: status ?? this.status,
      segmentCount: segmentCount ?? this.segmentCount,
      cost: cost ?? this.cost,
      sentAt: sentAt ?? this.sentAt,
    );
  }
}
