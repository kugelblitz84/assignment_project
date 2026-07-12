# ADR-0002: Separate domain contracts from data transfer concerns

## Status

Accepted with a documented implementation deviation

## Date

2026-07-12

## Context

The requirement called for typed models and a repository. The starter code used untyped maps and raw JSON directly in the UI.

A key architectural distinction was required:

- a repository contract expresses what the SMS domain needs;
- a repository implementation fulfils that contract;
- an API contract abstracts a remote/fake data source;
- DTOs represent transport payloads;
- domain entities represent business meaning.

The current implementation reflects this split, but one dependency-injection provider is still colocated with the domain contract.

## Decision drivers

- Prevent Dio/JSON/backend field shapes from leaking into presentation and domain logic.
- Keep fake and real backends interchangeable.
- Keep domain money/status/date types stronger than transport strings.
- Make repository behaviour independently testable.
- Avoid incorrectly treating every interface as a domain interface.

## Decision

Place the conceptual responsibilities as follows:

```text
Domain
- SmsRepository contract
- SmsMessage
- SendSmsInput / SendSmsResult
- CostBreakdown
- SmsStatus
- Money
- MessagePage

Data
- SmsRepositoryImpl
- SmsApi contract
- FakeSmsApi
- RealSmsApi
- request/response DTOs
- DTO-to-domain mapping
```

`SmsRepositoryImpl` depends on `SmsApi`. The repository maps:

```text
domain input -> request DTO -> SmsApi
SmsApi response DTO -> domain result
```

`SmsApi` remains a data-layer abstraction because it exposes DTOs and represents an external source, not a business capability.

## Current implementation deviation

`lib/features/sms/domain/sms_repository.dart` correctly contains the repository contract, but it also declares `smsRepositoryProvider` and imports:

- `../data/sms_api_provider.dart`
- `../data/sms_repository_impl.dart`
- `flutter_riverpod`

That means the file is not a pure domain-only dependency boundary.

This was accepted as a small take-home composition shortcut. In a stricter implementation, the provider should move to an app/DI file such as:

```text
lib/app/di/sms_dependencies.dart
```

Then the domain contract would import no Riverpod or data-layer classes.

## Alternatives considered

### Put DTOs in the domain layer because they are typed objects

Rejected. DTOs encode API names and serialization formats such as string timestamps, string costs, and JSON field names. A backend contract change should not redefine the domain.

### Return DTOs directly from `SmsRepository`

Rejected because presentation code would then depend on transport representations and perform mapping itself.

### Remove `SmsApi` and let the repository call Dio directly

Rejected because it would make fake and real implementations harder to switch and would mix transport details with repository mapping.

### Put all interfaces in domain

Rejected because abstraction placement depends on its consumer and vocabulary. `SmsRepository` is business-facing; `SmsApi` is data-source-facing.

## Consequences

### Positive

- Domain code receives `Money`, `SmsStatus`, and `DateTime` instead of raw transport strings.
- Real and fake APIs share one data-source contract.
- JSON changes are contained in DTO/mapping code.
- Repository tests can inject a fake `SmsApi`.

### Negative

- DTO and domain classes can look repetitive.
- The current provider placement introduces a reverse dependency from the domain file into data/framework code.
- Mapping code must handle malformed status, money, and date values.

## Implementation evidence

- `features/sms/domain/sms_repository.dart`
- `features/sms/data/sms_repository_impl.dart`
- `features/sms/data/sms_api.dart`
- `features/sms/data/sms_dtos.dart`
- `features/sms/domain/sms_message.dart`
- `features/sms/domain/cost_breakdown.dart`
- `features/sms/domain/send_sms_input.dart`

## Revisit when

- the assignment is promoted to production;
- strict dependency linting/package boundaries are introduced;
- local persistence is added;
- DTO versions diverge from domain models further.
