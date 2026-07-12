# ADR-0006: Refresh status through history, use cursor pagination, and use UTC month boundaries

## Status

Accepted — retrospective

## Date

2026-07-12

## Context

The contract states that SMS delivery status changes asynchronously, but it does not provide:

- a single-message status endpoint;
- websocket/server-sent-event details;
- a required polling interval;
- background refresh requirements.

The contract does provide paginated message history and a monthly cost-breakdown endpoint with `from` and `to`, but it does not specify the month timezone.

Clarification questions were submitted for both behaviours and received no answer.

## Decision drivers

- Use only documented endpoints in the real path.
- Avoid inventing an aggressive polling protocol.
- Show current status and allow deterministic review.
- Support large histories without fetching everything.
- Make billing-window boundaries reproducible.

## Decision

### Status refresh

Use `getMessages(...)` as the status-refresh source.

The UI supports:

- explicit app-bar refresh;
- pull-to-refresh;
- automatic first-page refresh after a successful send.

The fake backend advances nonterminal statuses when history is fetched:

```text
ACCEPTED -> SENT -> DELIVERED
```

This demonstrates asynchronous change without claiming a websocket or undocumented status endpoint exists.

### Pagination

Use cursor pagination.

The controller requests ten records initially and appends later pages when “Load more messages” is selected.

The fake cursor is an opaque base64-url encoded offset. The UI treats it only as an opaque string.

### Month boundaries

Use a half-open UTC month:

```text
from = UTC first day of current month, 00:00:00
to   = UTC first day of next month, 00:00:00
```

The real API serializes both boundaries as UTC ISO-8601 strings.

Message timestamps are parsed as UTC domain values and formatted in the device’s local time for display.

## Alternatives considered

### Automatic timer polling

Rejected because the contract does not define cadence, lifecycle, rate-limit expectations, or battery/network policy.

### Websocket or SSE

Rejected because no protocol or endpoint is specified.

### Optimistically set delivered status after send

Rejected because provider acceptance is not delivery.

### Fetch all history

Rejected because the assignment explicitly asks for paginated history and unbounded lists do not scale.

### Device-local or guessed tenant-local billing month

Rejected because device timezone can change and tenant timezone is unavailable. UTC is deterministic and matches the transport normalization already used.

## Consequences

### Positive

- The real client remains contract-faithful.
- Status changes are visible through a user-controlled refresh.
- Pagination behaviour can be reviewed with seeded data.
- Month calculations are deterministic across devices.
- Accepted status is not misrepresented as delivered.

### Negative

- Real status is not automatically live.
- A tenant whose billing calendar is not UTC may need different boundaries.
- The fake cursor is simpler than a production cursor.
- Status refresh reloads first-page cost and message data rather than a single record.

## Implementation evidence

- `features/sms/presentation/sms_console_controller.dart`
- `features/sms/presentation/sms_console_screen.dart`
- `features/sms/presentation/widgets/message_history_list.dart`
- `features/sms/data/fake_sms_api.dart`
- `features/sms/data/real_sms_api.dart`

## Revisit when

- a status endpoint or push protocol is defined;
- product requirements specify background polling;
- tenant timezone becomes available;
- server-provided billing periods replace client-generated boundaries.
