import 'package:flutter/material.dart';

import '../../domain/sms_status.dart';

class MessageStatusChip extends StatelessWidget {
  const MessageStatusChip({super.key, required this.status});

  final SmsStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(theme.colorScheme);

    return Semantics(
      label: 'Message status ${status.label}',
      child: Chip(
        label: Text(status.label),
        avatar: Icon(_icon(), size: 16),
        side: BorderSide(color: color),
        labelStyle: TextStyle(color: color),
      ),
    );
  }

  Color _color(ColorScheme scheme) {
    switch (status) {
      case SmsStatus.accepted:
        return scheme.primary;
      case SmsStatus.sent:
        return scheme.tertiary;
      case SmsStatus.delivered:
        return scheme.secondary;
      case SmsStatus.failed:
        return scheme.error;
    }
  }

  IconData _icon() {
    switch (status) {
      case SmsStatus.accepted:
        return Icons.schedule;
      case SmsStatus.sent:
        return Icons.send;
      case SmsStatus.delivered:
        return Icons.check_circle_outline;
      case SmsStatus.failed:
        return Icons.error_outline;
    }
  }
}
