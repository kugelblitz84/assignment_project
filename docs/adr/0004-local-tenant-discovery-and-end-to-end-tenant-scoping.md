# ADR-0004: Use local tenant discovery and explicit end-to-end tenant scoping

## Status

Accepted — retrospective

## Date

2026-07-12

## Context

Every backend request requires `X-Tenant-Id`, but the supplied contract did not define:

- login response shape;
- available-tenant discovery;
- selected-tenant persistence;
- authorization metadata.

A clarification question asked whether a local selector or only the original hardcoded tenant should be used. No response was received.

Using one hidden global tenant would technically make requests work but would not demonstrate tenant isolation. Inventing an authentication/tenant-list API would exceed the provided contract.

## Decision drivers

- Make tenancy visible and reviewable.
- Require tenant context on every repository/API operation.
- Demonstrate that tenant A and tenant B do not share state or fake data.
- Avoid storing a mutable “current tenant” inside the repository or API client.
- Preserve the expectation that the backend is the real authorization boundary.

## Decision

Define two local `Tenant.demoTenants` for the take-home selector.

Use `selectedTenantProvider` for the current UI selection.

Use a Riverpod family controller:

```dart
AsyncNotifierProvider.family<
  SmsConsoleController,
  SmsConsoleState,
  Tenant
>
```

The family argument is currently the `Tenant` object. `Tenant.==` and `hashCode` use only `id`, so the provider identity is logically tenant-ID based even if equivalent tenant objects are reconstructed.

The controller stores the tenant and passes `_tenant.id` to every repository operation.

The repository forwards `tenantId` to `SmsApi`.

The fake backend stores data in maps keyed by `tenantId`.

The real `ApiClient` places the ID in Dio request `extra`, and `AppApiInterceptor` requires it and writes:

```http
X-Tenant-Id: <tenant-id>
```

## Dependency flow

```text
TenantSelector
  -> selectedTenantProvider
  -> smsConsoleControllerProvider(tenant)
  -> SmsConsoleController._tenant.id
  -> SmsRepository
  -> SmsApi
  -> Fake storage key or real X-Tenant-Id header
```

## Security boundary

The Flutter-side scoping prevents accidental cross-tenant state mixing in the client. It is not sufficient authorization.

For the real system, the backend must verify that the bearer token is allowed to use the supplied tenant ID and return 403 otherwise.

## Alternatives considered

### Keep one hardcoded tenant constant

Rejected because it hides whether state, history, and cost data are actually isolated.

### Invent a tenant-list/login response

Rejected because the contract did not define one.

### Store selected tenant globally inside `ApiClient`

Rejected because in-flight operations could use mutable global state and repository methods would no longer show their tenant requirement.

### Pass only `String tenantId` as the family key

This is a valid simplification and removes the need for custom `Tenant` equality. The current final implementation instead passes `Tenant` because the state also displays tenant information. The logical identity remains the ID.

### Depend only on provider-family separation

Rejected as insufficient. Tenant ID is also required through repository, API, storage, and HTTP header boundaries.

## Consequences

### Positive

- Tenant scope is explicit in method signatures.
- The UI can demonstrate two isolated datasets.
- Switching tenants selects a separate controller state.
- Missing tenant context is rejected before a real request is sent.
- Fake and real paths use the same tenant ID.

### Negative

- Demo tenants are hardcoded because discovery is undefined.
- Tenant selection is not persisted.
- `Tenant` custom equality is additional code for a small demo.
- Client-side isolation must not be presented as backend authorization.

## Implementation evidence

- `features/tenant/tenant.dart`
- `features/tenant/selected_tenant_provider.dart`
- `features/tenant/tenant_selector.dart`
- `features/sms/presentation/sms_console_controller.dart`
- `features/sms/domain/sms_repository.dart`
- `features/sms/data/sms_api.dart`
- `features/sms/data/fake_sms_api.dart`
- `core/network/api_client.dart`

## Revisit when

- the backend exposes login/session tenant membership;
- tenant selection must persist;
- deep links or multiple concurrent tenant views are added;
- the family key is simplified to `String tenantId`.
