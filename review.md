# Review of `starter/lib/sms_console.dart`

## Initial assessment and review approach

The starter keeps networking, response parsing, billing logic, mutable state, and widget rendering in one file. That makes failures difficult to isolate and is contrary to the assignment requirement to move business logic into a typed data and state-management layer.

I reviewed the starter manually first, then used an AI assistant as a second-pass reviewer against `ASSIGNMENT.md` and `API-CONTRACT.md`. I rechecked the suggested issues against the source, corrected or removed anything I could not defend, and verified the line locations myself. The findings and severity decisions below are my final assessment; the fuller AI-use disclosure belongs in `AI-USAGE.md`.

# Findings

### 1. Critical — A credential is embedded in distributable source code

**Location:** Lines 8–10, especially line 9.

**User/business loss:** Anyone who can access the repository, application bundle, browser source, CI logs, or a decompiled mobile build can recover the credential and use it to call the SMS API. That can create fraudulent SMS charges and unauthorized access to tenant data. The exposed credential must be considered compromised.

**What's wrong:**

```dart
const String kApiKey = 'fw_live_...';
```

A Flutter application cannot safely hold a shared backend secret. Moving the same value to `.env`, `--dart-define`, or an obfuscated constant changes how it is configured, but it does not make the value secret; it still ships to the customer. The API contract describes short-lived access tokens and refresh tokens, not a permanent shared API key.

**How I would fix it:**

- Revoke and rotate the exposed credential immediately.
- Authenticate the current user and obtain a short-lived access token at runtime.
- Store access/refresh tokens using platform-backed secure storage where supported.
- Keep provider or service-account secrets only on a trusted backend, never in Flutter.
- Configure the non-secret base URL per environment using build configuration.
- Add secret scanning to CI and prevent secret files from being committed.
- For this take-home, keep only the non-secret base URL in build configuration, for example:

```dart
apiBaseUrl: String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.example.invalid',
),
```

  It can then be supplied with `--dart-define=API_BASE_URL=https://api.example.com`. This is appropriate for configuration, but not for hiding an access token.

**Regression evidence:** CI secret scanning should fail when token-like values are committed. The exposed credential still has to be revoked and rotated; a test cannot make an already published secret safe.

---

### 2. Critical — SMS content and credentials are transmitted over cleartext HTTP

**Location:** Line 8; used by lines 46–49, 71–78, and 125–128.

**User/business loss:** A network observer can intercept the bearer token, recipient phone number, and message body. SMS bodies commonly contain OTPs and other sensitive content. In addition, Android and Apple platforms may block cleartext traffic by default, so the application can simply fail on a normal device.

**What's wrong:**

```dart
const String kApiBase = 'http://api.formwork.internal';
```

Every request containing credentials or personal data is made without TLS.

**How I would fix it:**

- Use an `https://` endpoint with normal certificate verification. Changing from `http` to Dio alone would not fix this; TLS depends on the endpoint and transport configuration.
- Do not add broad platform exceptions that permit cleartext traffic in production.
- Fail closed when TLS validation fails; do not use partial-success or insecure fallback behavior. This prevents man-in-the-middle attacks.
- Keep any local HTTP stub limited to test/debug builds and inject it through the repository/client configuration.

**Regression evidence:** A configuration test should reject a non-HTTPS production base URL.

---

### 3. Critical — The required tenant header is missing from every request

**Location:** Lines 46–49, 71–78, and 125–128. The tenant constant on line 10 is never used.

**User/business loss:** Under the documented backend behavior, every request returns `403`, making the application unusable. If a future backend or mock falls back to a default tenant, the same defect can read or write data in the wrong tenant, creating a cross-customer data incident.

**What's wrong:** The API contract requires both headers on every call:

```text
Authorization: Bearer <access-token>
X-Tenant-Id: <uuid>
```

The implementation sends only `Authorization`.

**How I would fix it:**

- Require a `TenantId` value in the repository method or tenant-scoped API client.
- Add both headers centrally in an interceptor/client wrapper rather than manually at call sites.
- Reject a request locally when no tenant is selected.
- Scope repositories/controllers/providers by tenant so switching tenants creates a separate dependency chain.

**Regression evidence:** A client test should assert that all three endpoints receive the selected `X-Tenant-Id`. A tenant-switch widget test should prove that tenant A data never appears after switching to tenant B.

---

### 4. Critical — Full recipient numbers and message bodies are logged

**Location:** Line 69.

**User/business loss:** Phone numbers, OTPs, private message content, and possibly authentication codes can appear in `adb logcat`, IDE consoles, CI logs, device diagnostics, or crash-reporting breadcrumbs. This is a direct personal-data leak.

**What's wrong:**

```dart
print('Sending SMS to $phone: $body');
```

The API contract explicitly says recipients must not be logged. Logging the message body is even more sensitive.

**How I would fix it:**

- Remove this log entirely.
- Use structured logging with an allow-list of non-sensitive fields, such as request ID, endpoint, status class, and duration.
- Never log access tokens, refresh tokens, recipient values, or SMS bodies.
- Where operationally necessary, log only an irreversible correlation ID or a safely masked recipient already supplied by the backend.

**Regression evidence:** A logging test should assert that phone numbers and body text are absent from captured logs.

---

### 5. High — The cost response is cast to `double`, although the API returns decimal strings

**Location:** Lines 50–56, especially line 55.

**User/business loss:** The documented response contains values such as `"8.2500"`. Casting that `String` to `double` throws at runtime during the first cost load, so the screen breaks for a valid production response. Parsing into binary floating point would also introduce billing drift at scale.

**What's wrong:**

```dart
total = total + (costRows[i]['totalCost'] as double);
```

The contract explicitly states that all money is a decimal string and must not be parsed into `double`.

**How I would fix it:**

- Parse monetary strings into a fixed-scale value object, such as integer ten-thousandths (`0.0079` → `79`) or a decimal package.
- Keep arithmetic and equality in the fixed-scale type.
- Parse and use the response's authoritative `totalCost` rather than rebuilding it from dynamic rows unless reconciliation is explicitly required.
- Replace `List<dynamic>` with typed DTOs and domain models.

**Regression evidence:** Unit tests must prove that `0.0079 × 3` equals exactly `0.0237`, and that the contract fixture containing `"8.2500"` parses without a runtime cast.

---

### 6. Critical — The client independently calculates the wrong charge after sending

**Location:** Lines 18–23 and 80–85.

**User/business loss:** The customer is shown the wrong amount and local totals can disagree with the invoice. For the contract example, the API reports two segments and `0.1500`, but this code forces one segment and reports `0.0750`, undercounting the charge by 50%.

**What's wrong:**

```dart
final segments = 1;
final cost = rateFor(provider) * segments;
```

The implementation ignores both `segmentCount` and the authoritative decimal-string `cost` returned by the backend. The hardcoded provider rate table is not part of the contract and can become stale without an app release.

**How I would fix it:**

- Parse `segmentCount`, `cost`, and `currency` from the successful `202` response.
- Treat the backend's returned cost as authoritative.
- Do not duplicate provider pricing rules in the app.
- Reconcile the refreshed breakdown against the server rather than mutating a global total optimistically with a guessed amount.

**Regression evidence:** A send repository test using the contract fixture must assert `segmentCount == 2` and exact cost `0.1500`; reintroducing `segments = 1` must fail the test.

---

### 7. High — Non-success HTTP responses are decoded as if they were successful sends

**Location:** Lines 71–89.

**User/business loss:** A `400`, `401`, `403`, `429`, or `502` can be reported as a successful send, or produce a secondary type/runtime error. The customer may believe an OTP or alert was sent when it was not, and may repeatedly retry and create duplicate requests.

**What's wrong:** The code never checks `res.statusCode`. It immediately expects success fields such as `provider`, even though error bodies contain `errorCode` and `message`. It also trusts `result['provider']` to be a non-null `String`; a missing, null, or differently typed field causes a runtime error instead of a controlled protocol failure. The `Retry-After` header on `429` is ignored as well.

**How I would fix it:**

- Accept only `202` as a successful single send.
- Map `400` into field-level validation feedback.
- On `401`, refresh the token once through a synchronized auth flow, then retry once.
- On `403`, show an authorization/tenant-access error and do not retry blindly.
- On `429`, parse `Retry-After`, disable resubmission, and show when retry is allowed.
- On `502`, show a recoverable provider failure without claiming success.
- Map malformed/unexpected responses to a typed protocol error.

**Regression evidence:** Repository and widget tests should cover at least `400`, `429`, and `502`, and verify that no success message appears.

---

### 8. High — Expired access tokens are not refreshed

**Location:** Lines 46–49, 71–78, and 125–128.

**User/business loss:** The contract says access tokens expire after 15 minutes. A user can open the screen successfully and then have all sends and refreshes fail during an ordinary session, with no recovery other than restarting or signing in again.

**What's wrong:** There is no refresh-token flow, no handling for an expired-token response, and no protection against several requests attempting refresh simultaneously.

**How I would fix it:**

- Put authentication in a dedicated session/auth repository.
- Intercept an expired-token response, perform one refresh using a mutex/single-flight operation, update secure storage, and retry the original request once.
- If refresh fails, clear the session and route to sign-in with an explanatory message.
- Never log either token.

**Regression evidence:** A client test should simulate an expired token, one successful refresh, and one replayed request. A concurrency test should verify that multiple failed requests trigger only one refresh call.

---

### 9. High — `loadCosts()` has no guaranteed exit state and trusts unvalidated response data

**Location:** Lines 44–60, especially lines 45–55 and 60.

**User/business loss:** A normal network exception, a `401`/`403`/`500` response, malformed JSON, a missing or null `rows` field, or a row with an unexpected type can throw before the final `setState`. Because the entire page uses the same `loading` flag, the customer can be left on a permanently blocked screen with no error message or retry path.

**What's wrong:**

```dart
setState(() => loading = true);
final res = await http.get(...);
final data = jsonDecode(res.body);
costRows = data['rows'] as List<dynamic>;
...
setState(() => loading = false);
```

The method has no `try`, `catch`, or `finally`. It does not check `res.statusCode` before decoding the body and assumes that decoded JSON is an object containing a non-null `List` called `rows`. Each row is then accessed dynamically and assumed to contain a correctly typed `totalCost`. The only transition back to `loading = false` is on the complete happy path, so any exception skips the exit state.

**How I would fix it:**

- Move the request and parsing into a repository that returns typed success or failure results.
- Check the HTTP status before parsing a success DTO.
- Validate the JSON shape and required fields, and convert malformed responses into a typed protocol error.
- Replace `List<dynamic>` and direct casts with typed DTO parsing.
- Represent loading, success, empty, and error as explicit screen states.
- If this method remains widget-owned, clear the loading state in `finally` and check `mounted` before calling `setState`.

**Regression evidence:** Tests should cover a thrown network exception, a `500` error body, malformed JSON, `rows: null`, `rows` with the wrong type, and a row missing `totalCost`. Every case should finish with loading cleared and an actionable error state instead of an uncaught exception or infinite spinner.

---

### 10. High — Network waits and `FutureBuilder` errors can become permanent spinners

**Location:** Lines 46–49, 71–78, and 124–132.

**User/business loss:** On weak mobile data, a captive portal, an offline device, or a server that accepts a connection but never completes the response, the screen can remain blocked indefinitely. The user cannot retry, edit the message, or tell whether the send happened.

**What's wrong:** None of the HTTP calls defines a timeout or cancellation policy. In addition, the `FutureBuilder` treats every snapshot without data as loading. That includes `snapshot.hasError`, so even a request that fails can still render a spinner instead of an error state.

**How I would fix it:**

- Define connection and response timeouts in the API client.
- Map timeout and offline failures to typed failures.
- Handle `ConnectionState`, `snapshot.hasError`, empty data, and successful data separately.
- Keep a visible retry action and avoid blocking the whole screen when only one section is refreshing.
- Cancel or ignore obsolete requests when the page or tenant changes.

**Regression evidence:** A widget test should cover both a never-completing request and a completed request error, and verify that each ends in a recoverable error state rather than a permanent spinner.

---

### 11. High — Async callbacks use `State` and `BuildContext` after the widget may be disposed

**Location:** Lines 44–60 and 63–95, especially lines 60, 87, 91, and 95.

**User/business loss:** If the user navigates away while a request is slow, the completed future can call `setState()` or use `context` after disposal, causing exceptions on a normal navigation path.

**What's wrong:** There is no `mounted` check after any `await`. The send flow also invokes `ScaffoldMessenger.of(context)` after a network request.

**How I would fix it:**

- Prefer moving async business logic into a controller/notifier whose lifecycle is managed outside the widget.
- In widget-owned async code, check `if (!mounted) return;` before using `context` or calling `setState` after an `await`.
- Cancel or ignore obsolete work when the screen/tenant changes.

**Regression evidence:** A widget test should start a delayed request, remove the page from the tree, complete the request, and assert that no Flutter exception is raised.

---

### 12. High — The UI reads a recipient from an endpoint that never returns recipients

**Location:** Lines 124–142, especially line 140.

**User/business loss:** With a valid cost-breakdown response, `rows[i]['recipient']` is `null`; passing it to `Text` can throw a runtime type error and prevent the list from rendering. If someone later fills this field client-side, the UI would be fabricating personal data that the endpoint intentionally excludes.

**What's wrong:** The contract explicitly states that the cost endpoint contains provider totals and message counts, not phone numbers. The starter mixes cost rows with message-history rows.

**How I would fix it:**

- Render cost rows with only `provider`, exact `totalCost`, `messageCount`, and the response currency.
- Fetch message history from `GET /api/v1/sms/messages` using a separate typed model.
- Display only the already-masked `recipient` returned by the message-history endpoint.

**Regression evidence:** A widget test using the exact cost contract fixture should render without a recipient field. A history test should verify that only the masked value is shown.

---

### 13. Critical — Static global state is not scoped by tenant and can expose stale tenant data

**Location:** Lines 12–16, 58–59, 85, and 122.

**User/business loss:** `AppState.totalCost` and `AppState.history` survive widget instances and have no tenant key. After switching from tenant A to tenant B, tenant A's values can remain visible while B is loading or when B's request fails. This violates the explicit requirement that one tenant's data must never appear under another tenant's header.

**What's wrong:** The state is mutable, global, static, and unrelated to the selected tenant. There is also no atomic transition that clears old data before a tenant change.

**How I would fix it:**

- Use immutable screen state owned by a controller/notifier.
- Scope the controller/repository chain by `TenantId` (for example, a Riverpod `family`).
- Include tenant ID in cache keys and cancel/ignore results from a previously selected tenant.
- On tenant switch, show B's loading/empty state rather than A's last data.

**Regression evidence:** A deterministic tenant-switch test should delay tenant A, switch to B, complete A last, and assert that A's response is never rendered in B's screen.

---

### 14. High — The required paginated message history is not implemented

**Location:** Lines 58–59 and 124–146.

**User/business loss:** Customers cannot inspect individual messages, masked recipients, delivery state, send time, segment count, or per-message cost. The screen instead stores cost-summary rows under a variable named `history`, so later code can easily make invalid assumptions about the shape of the data.

**What's wrong:** The implementation never calls `GET /api/v1/sms/messages?cursor=<opaque>&limit=50` and has no cursor, next-page, loading-more, deduplication, or end-of-list behavior.

**How I would fix it:**

- Add typed `SmsMessage` and `MessagePage` models.
- Implement a repository method accepting an opaque cursor and limit.
- Keep pagination state (`items`, `nextCursor`, initial load, loading more, page error, exhausted).
- Deduplicate by `messageId` and reset the list when the tenant changes.

**Regression evidence:** Unit tests should cover first page, next page, `nextCursor == null`, duplicate IDs, page failure, and tenant reset. A widget test should verify loading-more and retry behavior.

---

### 15. High — The UI claims “Sent” even though send-time status is not final

**Location:** Lines 80–89.

**User/business loss:** The backend may return `ACCEPTED`, which only means that the provider accepted the request. Telling the customer it was “Sent” can create false confidence that a security code, outage alert, or customer notification was delivered.

**What's wrong:** The implementation ignores the response `status` and never refreshes history to reflect `ACCEPTED → SENT → DELIVERED` or `→ FAILED`.

**How I would fix it:**

- Parse and display the actual returned status, for example, “Accepted by provider”.
- Insert/update the returned message by `messageId` in the tenant-scoped history.
- Refresh or poll pending statuses with bounded backoff, or consume a server-supported realtime mechanism if available.
- Stop polling at terminal states and on page disposal/tenant change.

**Regression evidence:** A widget test should ensure an `ACCEPTED` response is not labelled “Delivered” or unqualified “Sent”, and a controller test should update the same message through later statuses.

---

### 16. High — A new cost request is created inside every build

**Location:** Lines 124–128.

**User/business loss:** Any rebuild can start another network call. Loading transitions, theme changes, keyboard/media-query changes, or parent rebuilds can create duplicate requests, inconsistent snapshots, unnecessary cost, and rate limiting. Combined with `429` being unhandled, this can leave the screen unusable.

**What's wrong:**

```dart
FutureBuilder(
  future: http.get(...),
)
```

The future is not stored and the data is already fetched separately by `loadCosts()`, so the same endpoint is requested twice even during initial display.

**How I would fix it:**

- Make the repository/controller the single source of truth.
- Start loading from the controller lifecycle, not `build()`.
- Render the controller's current async state.
- Support explicit refresh without creating requests on unrelated rebuilds.

**Regression evidence:** A widget test should count client calls and verify that unrelated rebuilds do not trigger additional cost requests.

---

### 17. Medium — The “monthly” cost request sends no date range

**Location:** Lines 46–49 and 125–128.

**User/business loss:** The backend may reject the request or return a default period that does not match the month shown to the customer. This can display the wrong total for billing and reconciliation.

**What's wrong:** The contract defines:

```text
GET /api/v1/sms/cost/breakdown?from=<iso8601>&to=<iso8601>
```

The implementation sends neither `from` nor `to`, despite the screen claiming to show a monthly breakdown.

**How I would fix it:**

- Define the selected reporting period explicitly.
- Convert its boundaries to ISO-8601 consistently, documenting whether the business month is tenant-local or UTC.
- Include both parameters in the repository request and show the period in the UI.

**Regression evidence:** A repository test should verify the exact encoded `from` and `to` query parameters for a known month and timezone rule.

---

### 18. Medium — Errors are swallowed and never shown to the user

**Location:** Lines 92–95 and lines 12–15.

**User/business loss:** A failed send appears to do nothing. The user receives no explanation, no retry path, and no indication whether retrying could duplicate a request. Support also receives only an unstructured local string, if anything can access it.

**What's wrong:** The catch block stores `e.toString()` in `AppState.lastError`, but no widget reads that field. It also collapses validation, timeout, authorization, rate limit, and provider failures into one untyped string.

**How I would fix it:**

- Map infrastructure errors to typed domain failures.
- Represent failure in screen state and render actionable messages.
- Keep field errors beside the form field; show retry for transient failures; route expired sessions to sign-in.
- Preserve a safe correlation/request ID for support without exposing PII.

**Regression evidence:** A widget failure-path test should verify the specific message and recovery action and confirm that loading stops.

---

### 19. Medium — The send form performs no client-side validation

**Location:** Lines 66–77 and 108–119.

**User/business loss:** Empty or malformed recipients and empty messages are sent to the API, creating avoidable failed requests and poor feedback. With the current response handling, the result may be silent or misleading.

**What's wrong:** The phone field is not checked for E.164 formatting, whitespace is not normalized, the body is not validated, and the button is not guarded against invalid input.

**How I would fix it:**

- Use a form/controller with explicit validation rules aligned with the backend contract.
- Trim values and validate E.164 syntax before sending while still treating the backend as authoritative.
- Display `INVALID_PHONE_NUMBER` as a field error.
- Disable or guard submission while a send is already in progress.

**Regression evidence:** Widget tests should verify that invalid input does not call the repository and that a backend `INVALID_PHONE_NUMBER` error is attached to the phone field.

---

### 20. Medium — Currency and precision are hardcoded in the presentation

**Location:** Lines 88, 122, and 141.

**User/business loss:** The API returns a currency value, but the screen always prints `€`. A tenant billed in another supported currency would see materially incorrect financial information. The total is also forced to two decimals even though contract values have four-decimal precision.

**What's wrong:** Currency metadata is ignored and formatting rules are scattered through widgets.

**How I would fix it:**

- Carry `currency` with the typed money value.
- Use one money formatter/component with explicit display rules.
- Keep exact four-decimal arithmetic internally; only round for display according to an agreed product rule.
- Use the theme and reusable cost-row component rather than embedding symbols and formatting throughout the widget.

**Regression evidence:** Unit/widget tests should cover exact values such as `0.0237` and verify that the response currency, not a hardcoded symbol, controls display.