# ADR-0003: Select fake or real SMS backends through dependency injection

## Status

Accepted — retrospective

## Date

2026-07-12

## Context

The API contract stated that a live backend was not required and explicitly allowed stubbing. The assignment also required evidence of loading, empty, retry, tenancy, and failure behaviour.

A happy-path fake alone would not demonstrate resilience. Conversely, hardwiring fake/real conditionals throughout controllers or repositories would spread environment concerns into business and presentation code.

The real client existed but needed to be wired through the same repository path as the fake implementation.

## Decision drivers

- Keep presentation and repository code unaware of the selected backend.
- Make error and loading scenarios deterministic for review and tests.
- Preserve a contract-faithful real HTTP path.
- Allow one configuration flag to switch the data source.
- Avoid duplicating repository logic for fake and real environments.

## Decision

Define one data-source contract:

```dart
abstract class SmsApi { ... }
```

Provide two implementations:

- `FakeSmsApi`
- `RealSmsApi`

Select the implementation in `smsApiProvider`:

```text
USE_FAKE_BACKEND=true
  -> FakeSmsApi(mode: selected fake mode)

USE_FAKE_BACKEND=false
  -> RealSmsApi(ApiClient)
```

`SmsRepositoryImpl` receives only `SmsApi` and is unchanged by the environment.

The fake backend uses static in-memory maps so that changing the fake network mode and recreating `FakeSmsApi` does not immediately erase the current demo session.

## Fake conditions

The fake supports:

- normal;
- slow network;
- offline;
- HTTP-equivalent 429 rate limit;
- HTTP-equivalent 502 provider failure;
- expired/session token;
- successful empty tenant.

These modes directly produce the same `AppFailure` types that the real client maps from network/HTTP errors.

## Seed-data decision

The fake seeds message history and provider cost rows for the same IDs listed in `Tenant.demoTenants`.

Seed data exists to demonstrate:

- history;
- cursor pagination;
- multiple statuses;
- provider breakdown;
- tenant separation;
- empty-versus-populated UI.

The fake-only `0.0079` rate is simulator data, not a production pricing rule.

## Alternatives considered

### Use only a fake backend

Rejected because the assignment benefits from showing the real contract path and header/error mapping.

### Use only the real backend

Rejected because no live backend was required and deterministic incident scenarios would be difficult to demonstrate.

### Branch inside `SmsRepositoryImpl`

Rejected because the repository should map domain and data, not decide deployment environment.

### Create separate fake and real repositories

Rejected because most repository validation and DTO/domain mapping would be duplicated.

### Mock Dio directly in the screen/controller

Rejected because it would test the wrong boundary and expose transport concerns to presentation code.

## Consequences

### Positive

- One configuration value selects the environment.
- The same controller and repository are exercised by fake and real paths.
- Failure scenarios can be demonstrated without changing device connectivity.
- The real implementation remains small and contract-oriented.

### Negative

- The demo-mode dropdown is meaningful only when the fake backend is active.
- Static in-memory state resets on a full process restart and can leak between tests unless explicitly reset.
- The fake models behaviour, not literal HTTP transport.
- The fake pricing/status simulation must not be mistaken for backend truth.

## Implementation evidence

- `core/config/app_config.dart`
- `features/sms/data/sms_api.dart`
- `features/sms/data/sms_api_provider.dart`
- `features/sms/data/fake_sms_api.dart`
- `features/sms/data/real_sms_api.dart`
- `features/sms/data/sms_repository_impl.dart`

## Revisit when

- a real staging server is available;
- contract tests can run against recorded fixtures or a mock server;
- deterministic fake state reset is needed for a larger test suite;
- pricing or delivery simulation becomes more complex.
