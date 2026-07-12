# ADR 0001: Use Riverpod AsyncNotifier with tenant-scoped provider families

- **Status:** Accepted
- **Date:** 2026-07-12

## Context

The SMS console must load cost and history data, send messages, refresh delivery state, paginate history, expose recoverable failures, and prevent duplicate actions while requests are in progress. It must also keep one tenant's data from appearing under another tenant's header.

The backend contract requires `X-Tenant-Id`, but it does not define tenant discovery. The take-home also has a 6–8 hour time-box, so the state solution needs to be testable and explicit without adding unnecessary framework ceremony.

An early version used several `StateProvider`-based values. `StateProvider` is suitable for simple synchronous selections, but using it to coordinate the console's related asynchronous transitions spread the logic across providers and widgets. It made loading, refresh, pagination, send guards, and error recovery harder to reason about as one state machine.

## Decision

Use Riverpod with two provider roles:

1. `NotifierProvider<..., String>` stores the currently selected demo tenant ID.
2. `AsyncNotifierProvider.family<SmsConsoleController, SmsConsoleState, String>` owns the complete SMS-console state for one tenant ID.

The controller coordinates initial loading, send, refresh, and pagination through the domain repository contract. Widgets render `AsyncValue` and dispatch user actions; they do not call Dio or the repository directly.

The family key is the immutable tenant ID string rather than a full `Tenant` object. String value equality already provides stable provider identity, removes custom `==`/`hashCode` boilerplate, and matches the value required by the repository, fake storage map, and `X-Tenant-Id` header.

The repository and API implementations are injected through Riverpod. `USE_FAKE_BACKEND` selects either the deterministic fake API or the Dio-backed real API without changing the controller or widgets.

## Alternatives considered

### Multiple `StateProvider`s

Rejected for the main console workflow. They remain appropriate for small synchronous values, but the console needs coordinated asynchronous operations, guards, and immutable state updates. Keeping those transitions in one notifier is easier to test and defend.

### `setState` in the screen

Rejected because it would mix networking and business orchestration with rendering. It also makes navigation during an `await`, duplicate submissions, tenant switching, and isolated tests more fragile.

### Bloc/Cubit

A valid alternative with strong event/state conventions. Rejected for this time-box because the additional events, states, and wiring did not add enough value over Riverpod's notifier and provider override support for a single feature.

### GetX

Rejected because its global service-location style and combined navigation/state APIs make dependency boundaries less explicit. The assignment specifically rewards visible architecture and testability.

### Full `Tenant` object as the family key

Rejected for this demo. It required custom equality to guarantee stable family identity when equivalent objects were reconstructed. The unique tenant ID is the actual isolation key and is simpler.

## Consequences

### Positive

- Async loading and top-level failures are represented directly by `AsyncValue`.
- Sending, refreshing, and loading more share one coherent immutable state.
- Widgets remain focused on display and user interaction.
- Repository implementations can be replaced in tests through provider overrides.
- Each tenant ID receives a separate family state and dependency chain.
- Fake and real backends use the same presentation and domain code.

### Negative and follow-up

- Contributors must understand Riverpod notifier lifecycle and family behavior.
- The current demo has only two tenant IDs; a production app with many tenants would need an explicit disposal/cache policy.
- Local demo tenant selection is not authorization. The backend must still verify that the bearer token may access the supplied `X-Tenant-Id`.
- Full authentication and tenant discovery remain deferred until their contracts are defined.
