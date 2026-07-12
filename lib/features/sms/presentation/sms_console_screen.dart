import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_view.dart';
import '../../tenant/selected_tenant_provider.dart';
import '../../tenant/tenant_selector.dart';
import '../data/fake_sms_api.dart';
import '../domain/send_sms_input.dart';
import 'sms_console_controller.dart';
import 'sms_console_state.dart';
import 'widgets/cost_breakdown_card.dart';
import 'widgets/message_history_list.dart';
import 'widgets/send_sms_form.dart';

class SmsConsoleScreen extends ConsumerWidget {
  const SmsConsoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(selectedTenantIdProvider);
    final controller = smsConsoleControllerProvider(tenantId);
    final state = ref.watch(controller);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Console'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(controller.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.when(
        loading: () => const AppLoadingView(),
        error: (error, stackTrace) => AppErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(controller),
        ),
        data: (consoleState) => _SmsConsoleBody(
          state: consoleState,
          onSend: ref.read(controller.notifier).sendSms,
          onRefresh: ref.read(controller.notifier).refresh,
          onLoadMore: ref.read(controller.notifier).loadMoreMessages,
          onDismissFailure: ref.read(controller.notifier).clearFailure,
        ),
      ),
    );
  }
}

class _SmsConsoleBody extends ConsumerWidget {
  const _SmsConsoleBody({
    required this.state,
    required this.onSend,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onDismissFailure,
  });

  final SmsConsoleState state;
  final Future<void> Function(SendSmsInput input) onSend;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onDismissFailure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppSpacing.desktopBreakpoint;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TopControls(),
        if (state.failure != null) ...[
          const SizedBox(height: AppSpacing.md),
          _InlineFailureBanner(
            message: state.failure!.message,
            onRetry: onRefresh,
            onDismiss: onDismissFailure,
          ),
        ],
        if (state.lastSendResult != null) ...[
          const SizedBox(height: AppSpacing.md),
          _SuccessBanner(
            message:
                'SMS accepted by ${state.lastSendResult!.provider}. Current status: ${state.lastSendResult!.status.label}.',
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    SendSmsForm(
                      isSending: state.isSending,
                      onSubmit: (input) => onSend(input),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CostBreakdownCard(breakdown: state.costBreakdown),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                flex: 7,
                child: MessageHistoryList(
                  messages: state.messages,
                  hasMore: state.hasMoreMessages,
                  isLoadingMore: state.isLoadingMore,
                  onLoadMore: onLoadMore,
                ),
              ),
            ],
          )
        else ...[
          SendSmsForm(
            isSending: state.isSending,
            onSubmit: (input) => onSend(input),
          ),
          const SizedBox(height: AppSpacing.lg),
          CostBreakdownCard(breakdown: state.costBreakdown),
          const SizedBox(height: AppSpacing.lg),
          MessageHistoryList(
            messages: state.messages,
            hasMore: state.hasMoreMessages,
            isLoadingMore: state.isLoadingMore,
            onLoadMore: onLoadMore,
          ),
        ],
      ],
    );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.maxContentWidth,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopControls extends ConsumerWidget {
  const _TopControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(fakeNetworkModeProvider);

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const SizedBox(width: 320, child: TenantSelector()),
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<FakeNetworkMode>(
            value: mode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Demo network state',
              helperText: 'Used to prove error/loading states.',
            ),
            items: FakeNetworkMode.values
                .map(
                  (item) => DropdownMenuItem<FakeNetworkMode>(
                    value: item,
                    child: Text(_modeLabel(item)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              ref.read(fakeNetworkModeProvider.notifier).state = value;
            },
          ),
        ),
        IconButton(
          tooltip: 'Toggle theme',
          icon: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode
                : Icons.dark_mode,
          ),
          onPressed: () {
            ref.read(themeModeProvider.notifier).toggle();
          },
        ),
      ],
    );
  }

  static String _modeLabel(FakeNetworkMode mode) {
    switch (mode) {
      case FakeNetworkMode.normal:
        return 'Normal';
      case FakeNetworkMode.slow:
        return 'Slow network';
      case FakeNetworkMode.offline:
        return 'Offline';
      case FakeNetworkMode.rateLimited:
        return '429 rate limit';
      case FakeNetworkMode.providerDown:
        return '502 provider down';
      case FakeNetworkMode.expiredToken:
        return 'Expired token';
      case FakeNetworkMode.empty:
        return 'Empty tenant';
    }
  }
}

class _InlineFailureBanner extends StatelessWidget {
  const _InlineFailureBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
            IconButton(
              tooltip: 'Dismiss error',
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
