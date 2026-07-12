# ADR-0005: Treat production API money as authoritative and avoid `double`

## Status

Accepted — retrospective

## Date

2026-07-12

## Context

The starter used `double`, invented local provider rates, and recomputed costs after sending. The API contract returned monetary values as decimal strings such as `0.0079`, but did not define a pricing endpoint.

Clarification questions asked whether backend `cost` and `totalCost` were authoritative and whether the client should avoid inventing rates. No answer was received.

Financial values are a real-incident risk: binary floating-point arithmetic and stale local pricing can produce visible or billable mismatches.

## Decision drivers

- Preserve exact decimal values.
- Avoid production-side pricing assumptions.
- Keep currency and scale explicit.
- Allow safe addition and integer multiplication in the fake simulator.
- Make malformed money values fail early.

## Decision

Use the domain `Money` value object:

```text
currency + BigInt minorUnits + fixed scale (default 4)
```

`Money.parse(...)` converts decimal strings into fixed-point units. Addition, subtraction, comparison, and integer multiplication require compatible currency and scale.

For the real backend path:

- `cost` and `totalCost` from API responses are authoritative;
- DTOs parse them into `Money`;
- the client does not recalculate provider pricing.

For the fake backend path only:

- a fixed `0.0079` rate is used to create coherent demo messages and totals;
- the fake calculates segments and costs because there is no actual backend response;
- this behaviour is explicitly simulation, not production billing logic.

## Alternatives considered

### Continue using `double`

Rejected because values such as decimal SMS rates cannot always be represented exactly and repeated additions can drift.

### Use `toStringAsFixed` to hide floating-point differences

Rejected because formatting does not correct the underlying arithmetic.

### Store raw strings everywhere

Rejected because strings preserve transport fidelity but do not provide safe arithmetic, comparison, or compatibility checks.

### Use a decimal package

A valid production option. A small custom fixed-point type was selected to keep dependencies and behaviour visible in the take-home.

### Recompute real costs from provider and segment count

Rejected because the client has no authoritative pricing endpoint and rates can change independently.

## Consequences

### Positive

- No binary floating-point arithmetic is used for SMS money.
- API decimal precision is preserved up to the configured scale.
- Currency/scale mismatches fail rather than silently combine.
- Production data remains backend-authoritative.

### Negative

- The default scale is fixed at four decimal places.
- Values with greater precision throw unless the scale is changed.
- Currency is represented as a string and is not validated against an ISO currency catalogue.
- The fake rate must remain clearly labelled as demo-only.

## Implementation evidence

- `features/sms/domain/money.dart`
- `features/sms/domain/cost_breakdown.dart`
- `features/sms/domain/send_sms_input.dart`
- `features/sms/data/sms_dtos.dart`
- `features/sms/data/fake_sms_api.dart`
- `features/sms/data/real_sms_api.dart`

## Revisit when

- the backend publishes currency-specific scale metadata;
- taxation, discounts, conversion, or rounding rules are introduced;
- an audited decimal/money library becomes preferable;
- API values can exceed four fractional digits.
