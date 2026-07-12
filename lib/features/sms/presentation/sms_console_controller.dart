import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_failure.dart';
import '../domain/sms_repository.dart';
import '../domain/cost_breakdown.dart';
import '../domain/sms_message.dart';
import '../domain/send_sms_input.dart';
import 'sms_console_state.dart';

final smsConsoleControllerProvider =
    AsyncNotifierProvider.family<SmsConsoleController, SmsConsoleState, String>(
      SmsConsoleController.new,
    );

class SmsConsoleController extends AsyncNotifier<SmsConsoleState> {
  static const _pageSize = 10;

  SmsConsoleController(this._tenantId);

  final String _tenantId;
  late _MonthRange _range;

  @override
  FutureOr<SmsConsoleState> build() async {
    _range = _currentUtcMonthRange();

    final repository = ref.watch(smsRepositoryProvider);
    final cost = await repository.getCostBreakdown(
      tenantId: _tenantId,
      from: _range.from,
      to: _range.to,
    );
    final messages = await repository.getMessages(
      tenantId: _tenantId,
      limit: _pageSize,
      currency: cost.currency,
    );

    return SmsConsoleState(
      from: _range.from,
      to: _range.to,
      costBreakdown: cost,
      messages: messages.items,
      nextCursor: messages.nextCursor,
      isSending: false,
      isRefreshing: false,
      isLoadingMore: false,
      failure: null,
      lastSendResult: null,
    );
  }

  Future<void> refresh() async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(isRefreshing: true, failure: null));

    try {
      final refreshed = await _loadFirstPage();
      state = AsyncData(
        current.copyWith(
          costBreakdown: refreshed.costBreakdown,
          messages: refreshed.messages,
          nextCursor: refreshed.nextCursor,
          isRefreshing: false,
          failure: null,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(isRefreshing: false, failure: _toFailure(error)),
      );
    }
  }

  Future<void> sendSms(SendSmsInput input) async {
    final current = state.value;
    if (current == null || current.isSending) return;

    state = AsyncData(
      current.copyWith(isSending: true, failure: null, lastSendResult: null),
    );

    try {
      final repository = ref.read(smsRepositoryProvider);
      final result = await repository.sendSms(
        tenantId: _tenantId,
        input: input,
      );

      final refreshed = await _loadFirstPage();
      state = AsyncData(
        current.copyWith(
          costBreakdown: refreshed.costBreakdown,
          messages: refreshed.messages,
          nextCursor: refreshed.nextCursor,
          isSending: false,
          failure: null,
          lastSendResult: result,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(isSending: false, failure: _toFailure(error)),
      );
    }
  }

  Future<void> loadMoreMessages() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || current.nextCursor == null)
      return;

    state = AsyncData(current.copyWith(isLoadingMore: true, failure: null));

    try {
      final repository = ref.read(smsRepositoryProvider);
      final page = await repository.getMessages(
        tenantId: _tenantId,
        cursor: current.nextCursor,
        limit: _pageSize,
        currency: current.costBreakdown.currency,
      );

      state = AsyncData(
        current.copyWith(
          messages: [...current.messages, ...page.items],
          nextCursor: page.nextCursor,
          isLoadingMore: false,
          failure: null,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(isLoadingMore: false, failure: _toFailure(error)),
      );
    }
  }

  void clearFailure() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(failure: null));
  }

  Future<_FirstPage> _loadFirstPage() async {
    final repository = ref.read(smsRepositoryProvider);
    final cost = await repository.getCostBreakdown(
      tenantId: _tenantId,
      from: _range.from,
      to: _range.to,
    );
    final messages = await repository.getMessages(
      tenantId: _tenantId,
      limit: _pageSize,
      currency: cost.currency,
    );

    return _FirstPage(
      costBreakdown: cost,
      messages: messages.items,
      nextCursor: messages.nextCursor,
    );
  }

  AppFailure _toFailure(Object error) {
    if (error is AppFailure) return error;
    return AppFailure.unknown(error.toString());
  }

  _MonthRange _currentUtcMonthRange() {
    final now = DateTime.now().toUtc();
    final from = DateTime.utc(now.year, now.month, 1);
    final to = now.month == 12
        ? DateTime.utc(now.year + 1, 1, 1)
        : DateTime.utc(now.year, now.month + 1, 1);
    return _MonthRange(from: from, to: to);
  }
}

class _FirstPage {
  const _FirstPage({
    required this.costBreakdown,
    required this.messages,
    required this.nextCursor,
  });

  final CostBreakdown costBreakdown;
  final List<SmsMessage> messages;
  final String? nextCursor;
}

class _MonthRange {
  const _MonthRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;
}
