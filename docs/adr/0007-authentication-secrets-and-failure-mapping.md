# ADR-0007: Avoid inventing auth refresh; centralize headers, configuration, and typed failures

## Status

Accepted with production limitations

## Date

2026-07-12

## Context

The contract requires a bearer token and `X-Tenant-Id` on every request. It mentions token refresh, but does not define the refresh request/response payload, token storage model, retry rules, or login/session response.

The starter hardcoded an API base URL, live-looking credential, and tenant ID in source. It also logged recipient and body content and treated failures as generic exceptions.

A clarification question asked whether expired-token handling should be simulated as session expiration instead of implementing a guessed refresh flow. No answer was received.

## Decision drivers

- Remove credentials and environment selection from source constants.
- Avoid inventing an undefined authentication protocol.
- Add required headers in one place.
- Distinguish actionable failure types.
- Prevent sensitive message content from being logged.
- Keep the assignment runnable without pretending the demo token is production-safe storage.

## Decision

### Configuration

Read:

- `API_BASE_URL`
- `ACCESS_TOKEN`
- `USE_FAKE_BACKEND`

from compile-time environment values through `AppConfig`.

`API_BASE_URL` is configuration, not a secret. `ACCESS_TOKEN` is a credential; its environment-based demo handling is a take-home limitation rather than a complete production session design.

### Header injection

`ApiClient` stores the required tenant ID in request `extra`.

`AppApiInterceptor`:

- rejects missing/blank tenant IDs;
- adds `Authorization: Bearer ...`;
- adds `X-Tenant-Id`;
- adds JSON content/accept headers.

### Failure mapping

Map transport/HTTP failures to `AppFailure`:

- offline;
- timeout;
- validation/400;
- session expired/401;
- forbidden tenant/403;
- rate limited/429 with `Retry-After`;
- provider failure/502;
- unknown.

### Token expiration

Do not implement refresh without a defined contract. Treat 401 as `sessionExpired`, and let the fake mode demonstrate this state.

### Logging

Use `RedactedLogger` in debug mode and log:

- tenant ID;
- masked phone number;
- message length;

not the full recipient or body.

Provider credentials and SMS-vendor secrets belong on the backend and are not part of the Flutter configuration.

## Alternatives considered

### Keep hardcoded constants

Rejected because source control is not an acceptable place for credentials or environment-specific deployment values.

### Guess the refresh JSON shape

Rejected because an invented auth protocol can be more misleading and insecure than an explicitly deferred flow.

### Retry every 401 automatically

Rejected because refresh failure, token rotation, replay, and logout behaviour are undefined.

### Log full request/response content for debugging

Rejected because phone numbers, SMS bodies, access tokens, and tenant information may be sensitive.

### Store the demo access token in plain global state

Rejected as no improvement over hardcoded source and difficult to replace with a real session abstraction.

## Consequences

### Positive

- Required headers are consistently applied.
- Tenant omission fails early.
- UI/controller code receives typed, user-facing failures.
- The implementation does not falsely claim a complete auth-refresh system.
- Debug logging is less likely to expose message content.

### Negative

- `ACCESS_TOKEN` from compile-time environment is not a complete production credential solution.
- There is no secure token persistence, refresh token, logout, or retry-after-refresh flow.
- The default demo token must never be treated as a real secret.
- Error-body mapping is intentionally minimal.

## Implementation evidence

- `core/config/app_config.dart`
- `core/network/api_client.dart`
- `core/error/app_failure.dart`
- `core/security/redacted_logger.dart`
- `features/sms/data/real_sms_api.dart`
- `features/sms/data/fake_sms_api.dart`

## Revisit when

- login and refresh contracts are supplied;
- a secure session/token-storage strategy is defined;
- certificate pinning or advanced transport security is required;
- structured telemetry and privacy policy are introduced.
