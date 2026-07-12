import '../domain/cost_breakdown.dart';
import '../domain/money.dart';
import '../domain/send_sms_input.dart';
import '../domain/sms_message.dart';
import '../domain/sms_status.dart';

class SendSmsRequestDto {
  const SendSmsRequestDto({
    required this.to,
    required this.body,
    this.referenceId,
  });

  factory SendSmsRequestDto.fromDomain(SendSmsInput input) {
    return SendSmsRequestDto(
      to: input.to.trim(),
      body: input.body.trim(),
      referenceId: input.referenceId?.trim().isEmpty == true ? null : input.referenceId?.trim(),
    );
  }

  final String to;
  final String body;
  final String? referenceId;

  Map<String, dynamic> toJson() => {
        'to': to,
        'body': body,
        if (referenceId != null) 'referenceId': referenceId,
      };
}

class SendSmsResponseDto {
  const SendSmsResponseDto({
    required this.messageId,
    required this.provider,
    required this.status,
    required this.segmentCount,
    required this.cost,
    required this.currency,
  });

  factory SendSmsResponseDto.fromJson(Map<String, dynamic> json) {
    return SendSmsResponseDto(
      messageId: json['messageId'] as String,
      provider: json['provider'] as String,
      status: json['status'] as String,
      segmentCount: json['segmentCount'] as int,
      cost: json['cost'] as String,
      currency: json['currency'] as String,
    );
  }

  final String messageId;
  final String provider;
  final String status;
  final int segmentCount;
  final String cost;
  final String currency;

  SendSmsResult toDomain() {
    return SendSmsResult(
      messageId: messageId,
      provider: provider,
      status: SmsStatus.fromApi(status),
      segmentCount: segmentCount,
      cost: Money.parse(cost, currency: currency),
      currency: currency,
    );
  }
}

class SmsMessageDto {
  const SmsMessageDto({
    required this.messageId,
    required this.recipient,
    required this.status,
    required this.segmentCount,
    required this.cost,
    required this.sentAt,
  });

  factory SmsMessageDto.fromJson(Map<String, dynamic> json) {
    return SmsMessageDto(
      messageId: json['messageId'] as String,
      recipient: json['recipient'] as String,
      status: json['status'] as String,
      segmentCount: json['segmentCount'] as int,
      cost: json['cost'] as String,
      sentAt: json['sentAt'] as String,
    );
  }

  final String messageId;
  final String recipient;
  final String status;
  final int segmentCount;
  final String cost;
  final String sentAt;

  SmsMessage toDomain(String currency) {
    return SmsMessage(
      messageId: messageId,
      maskedRecipient: recipient,
      status: SmsStatus.fromApi(status),
      segmentCount: segmentCount,
      cost: Money.parse(cost, currency: currency),
      sentAt: DateTime.parse(sentAt).toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'recipient': recipient,
        'status': status,
        'segmentCount': segmentCount,
        'cost': cost,
        'sentAt': sentAt,
      };
}

class MessageHistoryResponseDto {
  const MessageHistoryResponseDto({
    required this.items,
    required this.nextCursor,
  });

  factory MessageHistoryResponseDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>;
    return MessageHistoryResponseDto(
      items: rawItems.map((item) => SmsMessageDto.fromJson(item as Map<String, dynamic>)).toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }

  final List<SmsMessageDto> items;
  final String? nextCursor;
}

class CostBreakdownDto {
  const CostBreakdownDto({
    required this.currency,
    required this.totalCost,
    required this.rows,
  });

  factory CostBreakdownDto.fromJson(Map<String, dynamic> json) {
    final rawRows = json['rows'] as List<dynamic>;
    return CostBreakdownDto(
      currency: json['currency'] as String,
      totalCost: json['totalCost'] as String,
      rows: rawRows.map((row) => CostBreakdownRowDto.fromJson(row as Map<String, dynamic>)).toList(),
    );
  }

  final String currency;
  final String totalCost;
  final List<CostBreakdownRowDto> rows;

  CostBreakdown toDomain() {
    return CostBreakdown(
      currency: currency,
      totalCost: Money.parse(totalCost, currency: currency),
      rows: rows.map((row) => row.toDomain(currency)).toList(),
    );
  }
}

class CostBreakdownRowDto {
  const CostBreakdownRowDto({
    required this.provider,
    required this.totalCost,
    required this.messageCount,
  });

  factory CostBreakdownRowDto.fromJson(Map<String, dynamic> json) {
    return CostBreakdownRowDto(
      provider: json['provider'] as String,
      totalCost: json['totalCost'] as String,
      messageCount: json['messageCount'] as int,
    );
  }

  final String provider;
  final String totalCost;
  final int messageCount;

  CostBreakdownRow toDomain(String currency) {
    return CostBreakdownRow(
      provider: provider,
      totalCost: Money.parse(totalCost, currency: currency),
      messageCount: messageCount,
    );
  }
}

class ApiErrorDto {
  const ApiErrorDto({required this.errorCode, required this.message});

  factory ApiErrorDto.fromJson(Map<String, dynamic> json) {
    return ApiErrorDto(
      errorCode: json['errorCode'] as String,
      message: json['message'] as String,
    );
  }

  final String errorCode;
  final String message;
}
