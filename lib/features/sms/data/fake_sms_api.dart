import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/security/redacted_logger.dart';
import '../domain/money.dart';
import '../domain/sms_status.dart';
import 'sms_api.dart';
import 'sms_dtos.dart';

enum FakeNetworkMode {
  normal,
  slow,
  offline,
  rateLimited,
  providerDown,
  expiredToken,
  empty,
}

class FakeNetworkModeProvider extends Notifier<FakeNetworkMode> {
  @override
  FakeNetworkMode build() => FakeNetworkMode.normal;
}

final fakeNetworkModeProvider =
    NotifierProvider<FakeNetworkModeProvider, FakeNetworkMode>(
      FakeNetworkModeProvider.new,
    );

class FakeSmsApi implements SmsApi {
  FakeSmsApi({required this.mode}) {
    _seedIfNeeded();
  }

  final FakeNetworkMode mode;

  static final Map<String, List<SmsMessageDto>> _messagesByTenant = {};
  static final Map<String, Map<String, _ProviderCost>> _costsByTenant = {};
  static final Map<String, int> _pollCountByMessageId = {};
  static int _counter = 1000;

  static const _currency = 'EUR';
  static const _ratePerSegment = '0.0079';

  @override
  Future<SendSmsResponseDto> sendSms({
    required String tenantId,
    required SendSmsRequestDto request,
  }) async {
    await _simulateNetwork();
    _throwForMode();

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(request.to)) {
      throw AppFailure.validation('Phone number must be E.164.');
    }

    final segmentCount = max(1, (request.body.length / 160).ceil());
    final cost = Money.parse(
      _ratePerSegment,
      currency: _currency,
    ).multiplyByInt(segmentCount).toDecimalString();
    final messageId = 'SM${_counter++}';
    final provider = _counter.isEven ? 'TWILIO' : 'AWS_SNS';

    RedactedLogger.info(
      'Fake backend accepted SMS: tenant=$tenantId recipient=${RedactedLogger.phone(request.to)} body=${RedactedLogger.textLength(request.body)}',
    );

    _messagesByTenant.putIfAbsent(tenantId, () => []);
    _messagesByTenant[tenantId]!.insert(
      0,
      SmsMessageDto(
        messageId: messageId,
        recipient: _maskPhone(request.to),
        status: SmsStatus.accepted.apiValue,
        segmentCount: segmentCount,
        cost: cost,
        sentAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );

    _addCost(tenantId: tenantId, provider: provider, cost: cost);

    return SendSmsResponseDto(
      messageId: messageId,
      provider: provider,
      status: SmsStatus.accepted.apiValue,
      segmentCount: segmentCount,
      cost: cost,
      currency: _currency,
    );
  }

  @override
  Future<CostBreakdownDto> getCostBreakdown({
    required String tenantId,
    required DateTime from,
    required DateTime to,
  }) async {
    await _simulateNetwork();
    _throwForMode();

    if (mode == FakeNetworkMode.empty) {
      return const CostBreakdownDto(
        currency: _currency,
        totalCost: '0.0000',
        rows: [],
      );
    }

    final providerCosts = _costsByTenant[tenantId] ?? {};
    var total = Money.zero(_currency);
    final rows = <CostBreakdownRowDto>[];

    for (final entry in providerCosts.entries) {
      total = total + entry.value.total;
      rows.add(
        CostBreakdownRowDto(
          provider: entry.key,
          totalCost: entry.value.total.toDecimalString(),
          messageCount: entry.value.messageCount,
        ),
      );
    }

    return CostBreakdownDto(
      currency: _currency,
      totalCost: total.toDecimalString(),
      rows: rows,
    );
  }

  @override
  Future<MessageHistoryResponseDto> getMessages({
    required String tenantId,
    String? cursor,
    int limit = 50,
  }) async {
    await _simulateNetwork();
    _throwForMode();

    if (mode == FakeNetworkMode.empty) {
      return const MessageHistoryResponseDto(items: [], nextCursor: null);
    }

    _advanceStatuses(tenantId);

    final messages = _messagesByTenant[tenantId] ?? [];
    final start = _decodeCursor(cursor);
    final end = min(start + limit, messages.length);
    final page = messages.sublist(start, end);
    final nextCursor = end >= messages.length ? null : _encodeCursor(end);

    return MessageHistoryResponseDto(items: page, nextCursor: nextCursor);
  }

  Future<void> _simulateNetwork() async {
    switch (mode) {
      case FakeNetworkMode.slow:
        await Future<void>.delayed(const Duration(milliseconds: 1700));
      default:
        await Future<void>.delayed(const Duration(milliseconds: 450));
    }
  }

  void _throwForMode() {
    switch (mode) {
      case FakeNetworkMode.offline:
        throw AppFailure.offline();
      case FakeNetworkMode.rateLimited:
        throw AppFailure.rateLimited(const Duration(seconds: 10));
      case FakeNetworkMode.providerDown:
        throw AppFailure.providerFailure();
      case FakeNetworkMode.expiredToken:
        throw AppFailure.sessionExpired();
      case FakeNetworkMode.normal:
      case FakeNetworkMode.slow:
      case FakeNetworkMode.empty:
        return;
    }
  }

  void _seedIfNeeded() {
    if (_messagesByTenant.isNotEmpty) return;

    _seedTenant(
      tenantId: '11111111-1111-1111-1111-111111111111',
      providerTotals: const {'TWILIO': 110, 'AWS_SNS': 91},
      recipients: const [
        '+4915*****78',
        '+4917*****21',
        '+4916*****44',
        '+4915*****10',
      ],
    );

    _seedTenant(
      tenantId: '22222222-2222-2222-2222-222222222222',
      providerTotals: const {'TWILIO': 12, 'AWS_SNS': 7},
      recipients: const ['+4477*****12', '+4475*****89', '+4479*****33'],
    );
  }

  void _seedTenant({
    required String tenantId,
    required Map<String, int> providerTotals,
    required List<String> recipients,
  }) {
    final messages = <SmsMessageDto>[];
    final now = DateTime.now().toUtc();
    var index = 0;

    for (final providerEntry in providerTotals.entries) {
      final provider = providerEntry.key;
      final messageCount = providerEntry.value;
      final shownCount = min(messageCount, 14);
      var providerTotal = Money.zero(_currency);

      for (var i = 0; i < shownCount; i++) {
        final segmentCount = i % 3 == 0 ? 2 : 1;
        final cost = Money.parse(
          _ratePerSegment,
          currency: _currency,
        ).multiplyByInt(segmentCount);
        providerTotal = providerTotal + cost;

        messages.add(
          SmsMessageDto(
            messageId: 'SMSEED${tenantId.substring(0, 4)}$index',
            recipient: recipients[index % recipients.length],
            status: index % 5 == 0
                ? SmsStatus.sent.apiValue
                : SmsStatus.delivered.apiValue,
            segmentCount: segmentCount,
            cost: cost.toDecimalString(),
            sentAt: now.subtract(Duration(hours: index * 3)).toIso8601String(),
          ),
        );
        index++;
      }

      _costsByTenant.putIfAbsent(tenantId, () => {});
      _costsByTenant[tenantId]![provider] = _ProviderCost(
        total: providerTotal,
        messageCount: shownCount,
      );
    }

    messages.sort(
      (a, b) => DateTime.parse(b.sentAt).compareTo(DateTime.parse(a.sentAt)),
    );
    _messagesByTenant[tenantId] = messages;
  }

  void _advanceStatuses(String tenantId) {
    final messages = _messagesByTenant[tenantId] ?? [];
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (message.status == SmsStatus.delivered.apiValue ||
          message.status == SmsStatus.failed.apiValue) {
        continue;
      }

      final pollCount = (_pollCountByMessageId[message.messageId] ?? 0) + 1;
      _pollCountByMessageId[message.messageId] = pollCount;

      final nextStatus = pollCount <= 1 ? SmsStatus.sent : SmsStatus.delivered;
      messages[i] = SmsMessageDto(
        messageId: message.messageId,
        recipient: message.recipient,
        status: nextStatus.apiValue,
        segmentCount: message.segmentCount,
        cost: message.cost,
        sentAt: message.sentAt,
      );
    }
  }

  void _addCost({
    required String tenantId,
    required String provider,
    required String cost,
  }) {
    final tenantCosts = _costsByTenant.putIfAbsent(tenantId, () => {});
    final current =
        tenantCosts[provider] ??
        _ProviderCost(total: Money.zero(_currency), messageCount: 0);
    tenantCosts[provider] = _ProviderCost(
      total: current.total + Money.parse(cost, currency: _currency),
      messageCount: current.messageCount + 1,
    );
  }

  String _maskPhone(String phone) {
    if (phone.length <= 6) return '*****';
    return '${phone.substring(0, 5)}*****${phone.substring(phone.length - 2)}';
  }

  int _decodeCursor(String? cursor) {
    if (cursor == null || cursor.isEmpty) return 0;
    try {
      return int.parse(utf8.decode(base64Url.decode(cursor)));
    } catch (_) {
      return 0;
    }
  }

  String _encodeCursor(int offset) =>
      base64Url.encode(utf8.encode(offset.toString()));
}

class _ProviderCost {
  const _ProviderCost({required this.total, required this.messageCount});

  final Money total;
  final int messageCount;
}
