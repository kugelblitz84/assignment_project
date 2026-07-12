enum AppFailureType {
  offline,
  timeout,
  validation,
  rateLimited,
  providerFailure,
  sessionExpired,
  forbiddenTenant,
  unknown,
}

class AppFailure implements Exception {
  const AppFailure({
    required this.type,
    required this.message,
    this.retryAfter,
  });

  final AppFailureType type;
  final String message;
  final Duration? retryAfter;

  factory AppFailure.offline() => const AppFailure(
        type: AppFailureType.offline,
        message: 'You appear to be offline. Check your connection and try again.',
      );

  factory AppFailure.timeout() => const AppFailure(
        type: AppFailureType.timeout,
        message: 'The request took too long. Please try again.',
      );

  factory AppFailure.validation(String message) => AppFailure(
        type: AppFailureType.validation,
        message: message,
      );

  factory AppFailure.rateLimited(Duration retryAfter) => AppFailure(
        type: AppFailureType.rateLimited,
        message: 'Too many requests. Try again in ${retryAfter.inSeconds} seconds.',
        retryAfter: retryAfter,
      );

  factory AppFailure.providerFailure() => const AppFailure(
        type: AppFailureType.providerFailure,
        message: 'The SMS provider is temporarily unavailable. Please retry shortly.',
      );

  factory AppFailure.sessionExpired() => const AppFailure(
        type: AppFailureType.sessionExpired,
        message: 'Your session has expired. Please sign in again.',
      );

  factory AppFailure.forbiddenTenant() => const AppFailure(
        type: AppFailureType.forbiddenTenant,
        message: 'You do not have access to this tenant.',
      );

  factory AppFailure.unknown([String? message]) => AppFailure(
        type: AppFailureType.unknown,
        message: message ?? 'Something went wrong. Please try again.',
      );

  @override
  String toString() => message;
}
