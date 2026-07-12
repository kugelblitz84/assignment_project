# ADR-0008: Use explicit Riverpod presentation state and reusable responsive UI

## Status

Accepted — retrospective

## Date

2026-07-12

## Context

The assignment required explicit state management, real loading/error states, reusable components, theme support, accessibility, and a professional responsive UI.

The starter mixed controllers, network calls, global state, calculations, and widgets in one `StatefulWidget`. A single `loading` flag could not distinguish initial loading, sending, refreshing, or pagination.

The initial assignment notes selected Riverpod and GoRouter but did not fully record how the presentation requirement shaped the resulting state model.

## Decision drivers

- Separate initial loading from in-place actions.
- Keep screen widgets declarative.
- Scope state by tenant.
- Make network scenarios visibly demonstrable.
- Reuse empty/loading/error and feature widgets.
- Support mobile and desktop widths.
- Expose semantic labels and adequate touch targets.
- Support light/dark/system theme behaviour.

## Decision

Use a tenant-family `AsyncNotifier` for the SMS console.

`AsyncValue<SmsConsoleState>` represents:

- initial loading;
- initial fatal error;
- loaded screen state.

`SmsConsoleState` additionally represents independent in-place states:

- `isSending`;
- `isRefreshing`;
- `isLoadingMore`;
- inline `failure`;
- `lastSendResult`;
- `nextCursor`.

This prevents a send or pagination request from replacing the entire loaded screen with a full-page spinner.

Split the UI into:

- `SmsConsoleScreen`;
- `SendSmsForm`;
- `CostBreakdownCard`;
- `MessageHistoryList`;
- `MessageStatusChip`;
- shared loading/error/empty views;
- `TenantSelector`.

Use a breakpoint to render a two-column desktop layout and a stacked mobile layout.

Use Material 3 light/dark themes, default `ThemeMode.system`, and an in-memory theme toggle.

Use semantics/tooltips for tenant selection, send action, status, refresh, dismiss, and theme actions.

## Alternatives considered

### Keep all state in `setState`

Rejected because dependencies, async coordination, tenant scoping, and test overrides would remain coupled to the widget.

### One global `isLoading`

Rejected because the UI needs to distinguish initial loading from send, refresh, and load-more actions.

### Separate providers for every boolean

Rejected because the flags describe one screen transaction model and are easier to update coherently in one state object.

### BLoC

Rejected for this scope because the event/state ceremony would outweigh the benefit for one feature controller.

### Theme only through device setting

Rejected because the assignment benefits from demonstrating that both themes are wired and usable. System remains the default.

### Fixed desktop-only layout

Rejected because the app is a Flutter client and should remain usable at narrow widths.

## Consequences

### Positive

- UI states are explicit and independently renderable.
- Buttons disable during their own operations.
- Existing data remains visible during refresh/send/load-more failures.
- Components are easier to widget-test.
- The layout adapts to screen size.
- Theme and accessibility requirements are visibly implemented.

### Negative

- `SmsConsoleState.copyWith` needs a sentinel to distinguish “keep nullable value” from “clear nullable value.”
- Theme choice is not persisted.
- The demo network selector currently lives in the feature UI and should be hidden or removed for production.
- Some small private widgets remain in the screen file rather than separate files.

## Implementation evidence

- `features/sms/presentation/sms_console_controller.dart`
- `features/sms/presentation/sms_console_state.dart`
- `features/sms/presentation/sms_console_screen.dart`
- `features/sms/presentation/widgets/`
- `core/widgets/`
- `core/theme/app_theme.dart`
- `core/theme/theme_mode_provider.dart`
- `core/theme/app_spacing.dart`
- `app/router.dart`

## Revisit when

- the UI grows into multiple independent subflows;
- theme persistence is required;
- localization is introduced;
- accessibility testing identifies additional semantics needs;
- production builds must exclude demo controls.
