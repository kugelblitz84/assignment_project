import '../../../core/error/app_failure.dart';
import '../domain/cost_breakdown.dart';
import '../domain/send_sms_input.dart';
import '../domain/sms_message.dart';

const _unset = Object();

class SmsConsoleState {
  const SmsConsoleState({
    required this.from,
    required this.to,
    required this.costBreakdown,
    required this.messages,
    required this.nextCursor,
    required this.isSending,
    required this.isRefreshing,
    required this.isLoadingMore,
    required this.failure,
    required this.lastSendResult,
  });

  final DateTime from;
  final DateTime to;
  final CostBreakdown costBreakdown;
  final List<SmsMessage> messages;
  final String? nextCursor;
  final bool isSending;
  final bool isRefreshing;
  final bool isLoadingMore;
  final AppFailure? failure;
  final SendSmsResult? lastSendResult;

  bool get hasMoreMessages => nextCursor != null;

  SmsConsoleState copyWith({
    DateTime? from,
    DateTime? to,
    CostBreakdown? costBreakdown,
    List<SmsMessage>? messages,
    Object? nextCursor = _unset,
    bool? isSending,
    bool? isRefreshing,
    bool? isLoadingMore,
    Object? failure = _unset,
    Object? lastSendResult = _unset,
  }) {
    return SmsConsoleState(
      from: from ?? this.from,
      to: to ?? this.to,
      costBreakdown: costBreakdown ?? this.costBreakdown,
      messages: messages ?? this.messages,
      nextCursor: identical(nextCursor, _unset) ? this.nextCursor : nextCursor as String?,
      isSending: isSending ?? this.isSending,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      failure: identical(failure, _unset) ? this.failure : failure as AppFailure?,
      lastSendResult: identical(lastSendResult, _unset) ? this.lastSendResult : lastSendResult as SendSmsResult?,
    );
  }
}
