enum SmsStatus {
  accepted,
  sent,
  delivered,
  failed;

  factory SmsStatus.fromApi(String value) {
    switch (value.toUpperCase()) {
      case 'ACCEPTED':
        return SmsStatus.accepted;
      case 'SENT':
        return SmsStatus.sent;
      case 'DELIVERED':
        return SmsStatus.delivered;
      case 'FAILED':
        return SmsStatus.failed;
      default:
        throw FormatException('Unknown SMS status: $value');
    }
  }

  String get apiValue {
    switch (this) {
      case SmsStatus.accepted:
        return 'ACCEPTED';
      case SmsStatus.sent:
        return 'SENT';
      case SmsStatus.delivered:
        return 'DELIVERED';
      case SmsStatus.failed:
        return 'FAILED';
    }
  }

  String get label {
    switch (this) {
      case SmsStatus.accepted:
        return 'Accepted';
      case SmsStatus.sent:
        return 'Sent';
      case SmsStatus.delivered:
        return 'Delivered';
      case SmsStatus.failed:
        return 'Failed';
    }
  }
}
