import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../domain/sms_message.dart';
import 'message_status_chip.dart';

class MessageHistoryList extends StatelessWidget {
  const MessageHistoryList({
    super.key,
    required this.messages,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final List<SmsMessage> messages;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Message history', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            if (messages.isEmpty)
              const AppEmptyView(
                title: 'No messages yet',
                message: 'Send the first SMS to see delivery status and cost here.',
                icon: Icons.sms_outlined,
              )
            else ...[
              for (final message in messages) _MessageHistoryTile(message: message),
              if (hasMore) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: isLoadingMore ? null : onLoadMore,
                  icon: isLoadingMore
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more),
                  label: Text(isLoadingMore ? 'Loading…' : 'Load more messages'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageHistoryTile extends StatelessWidget {
  const _MessageHistoryTile({required this.message});

  final SmsMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      message.maskedRecipient,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  MessageStatusChip(status: message.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  Text('Segments: ${message.segmentCount}'),
                  Text('Cost: ${message.cost.format()}'),
                  Text('Sent: ${_formatSentAt(message.sentAt)}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSentAt(DateTime sentAt) {
    final local = sentAt.toLocal();
    final date = '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}
