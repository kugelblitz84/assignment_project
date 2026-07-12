# ADR-0009: Bound the take-home scope and record deferred production work

## Status

Accepted — retrospective

## Date

2026-07-12

## Context

The assignment expected a professional rebuild but did not expect every possible production concern to be completed. Several contract areas were ambiguous, and completing guessed features would reduce confidence rather than improve it.

The initial assignment notes explicitly questioned bulk SMS, token refresh, tenant discovery, status polling, pricing, and month boundaries. No clarification was received.

The implementation therefore prioritized the required user journeys and the defects most likely to cause real incidents:

- tenant leakage;
- money precision/pricing disagreement;
- missing headers and unsafe credentials;
- misleading status;
- unhandled network/provider/rate-limit failures;
- duplicate sends and poor loading state;
- inaccessible or nonresponsive UI.

## Decision

Ship the required scope:

- send one SMS;
- paginated message history;
- monthly cost breakdown;
- tenant selector and end-to-end tenant scoping;
- fake and real API implementations;
- deterministic loading/error/empty scenarios;
- exact decimal money;
- theme, accessibility, responsive layout, and reusable widgets.

Deliberately defer:

- bulk SMS;
- invented token-refresh protocol;
- login and tenant-discovery API;
- secure token persistence/session lifecycle;
- websocket/SSE or timer-based automatic status updates;
- tenant-specific timezone selection;
- persistent fake storage;
- persisted theme selection;
- vendor-pricing administration;
- production telemetry;
- removal of all legacy reference code.

Keep `lib/sms_console.dart` as a deliberately unwired reference model of the original implementation. It must not be imported by the rebuilt runtime.

## Why this is an architectural decision

Scope affects architecture. Implementing undefined features would require invented contracts and create misleading abstractions. Deferring them keeps the current boundaries honest:

- session refresh waits for a real auth contract;
- tenant discovery waits for a real membership contract;
- production pricing remains server-owned;
- realtime status waits for a real status protocol;
- bulk send waits for explicit product requirements.

## Alternatives considered

### Implement every mentioned endpoint or concept

Rejected because the contract does not define enough detail for a correct implementation and the exercise is time-boxed.

### Hide missing features without documenting them

Rejected because reviewers need to distinguish intentional scope from accidental omission.

### Remove the legacy file immediately

A valid cleanup for production, but it was intentionally retained for comparison/reference in this submission. It remains isolated from runtime.

### Build a local database and full authentication flow

Rejected as disproportionate to the assignment and dependent on missing contracts.

## Consequences

### Positive

- The delivered implementation is coherent and reviewable.
- Ambiguity is handled explicitly rather than hidden.
- Required failure and tenant behaviours receive more attention.
- Deferred work has clear triggers instead of vague “TODOs.”

### Negative

- The app is not a complete production authentication client.
- Demo data resets on process restart.
- Theme and selected tenant are not persisted.
- Delivery status requires user refresh.
- Bulk send is absent.
- The legacy file remains in the repository and needs a clear comment/README explanation.

## Revisit when

- clarification or a revised API contract is supplied;
- the take-home becomes an active product;
- a backend environment and auth service are available;
- product scope includes bulk send or realtime delivery tracking.
