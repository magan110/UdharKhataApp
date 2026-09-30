# Udhaar Khata — Coding Standards / Development Guidelines

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [LLD](LLD.md) · [Security requirements](SECURITY-REQUIREMENTS.md) · [Test plan](TEST-PLAN.md) · [Daily implementation plan](docs/implementation/README.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Release:** Android v1  
**Status:** Implementation guide; D02 source and CI checks are present  
**Baseline:** [SRS](SRS.md) · [LLD](LLD.md) · [Database Design / ERD](DATABASE-DESIGN-ERD.md) · [API Specification](API-SPECIFICATION.md) · [Security Requirements](SECURITY-REQUIREMENTS.md)

## 1. Purpose and precedence

These standards guide the Flutter/Dart Android app, TypeScript Cloudflare Worker, local SQLite and D1 migrations. They make financial and security requirements easy to review and verify. Requirement text in the [SRS](SRS.md) and approved product decisions take precedence over illustrative code or package choices here. This document does not select a state-management, HTTP, SQLite or Worker framework; choose maintained packages in phase 0, pin versions, record the decision and test them against supported devices and the Cloudflare runtime.

The v1 nonnegotiable invariants are: integer paise only; one ledger effect per `(shopId, clientOperationId)`; posted entries remain immutable; payments and corrections cannot produce negative authoritative balance; shop/customer access is checked on the Worker; QR possession is not authorization; a locally Pending entry is never described as cloud-backed up. A change touching any of these requires explicit review and a test that exercises the affected boundary.

## 2. Repository structure and ownership

Use the [LLD module layout](LLD.md#2-package-and-module-layout) as the starting point:

```text
udhaarkhata/                  Flutter Android app
  lib/app/                    app bootstrap, routing, localization
  lib/core/                   auth, SQLite, HTTP, sync infrastructure
  lib/features/               QR, shop, ledger, disputes, sharing, settings
  test/                       unit and widget tests
  integration_test/           selected device journeys
services/api/                 Cloudflare Worker
  src/http/                   route and request/response boundary
  src/auth/                   identity and app sessions
  src/policy/                 role/shop/link authorization
  src/ledger/                 money, correction and idempotency services
  src/qr/ src/disputes/        focused domain services
  src/db/                    prepared statements and mappings
  migrations/                immutable numbered D1 SQL migrations
  test/                       unit, API and D1 integration tests
docs/                        later operational and user documentation
```

Avoid a shared mutable `utils` module that hides authorization or money rules. Keep dependency direction one way: UI/routes → use cases/services → repositories/adapters. Widgets do not calculate balances or write SQL. HTTP route handlers do not embed business rules. Domain services accept typed values and return explicit outcomes. DB adapters do not decide user permissions on their own; the service passes an authorized scope that is checked before query execution. Where possible, enforce scope again in SQL predicates.

Name files for the primary responsibility. Dart uses `lowercase_with_underscores.dart`, `UpperCamelCase` types and `lowerCamelCase` members. TypeScript uses one consistent file convention selected in phase 0; exported types/functions have descriptive names. SQL tables/columns use `snake_case` matching [Database Design / ERD](DATABASE-DESIGN-ERD.md). Use IDs such as `shopId`, `linkId` and `entryId`; avoid a generic `id` in a method signature with several identities.

## 3. Dart and Flutter rules

1. Run the official Dart formatter; do not hand-format around it. Enable a maintained Flutter lint preset plus project rules in `analysis_options.yaml`. Analyzer warnings in changed code block merge unless a documented suppression explains why.
2. Use sound null safety. Model API variants and sync states as sealed/typed outcomes or equivalent exhaustive representations. Do not use `dynamic` for financial payloads after the JSON boundary. Parse external JSON once and validate every required field.
3. Keep money as a validated integer paise value type. Parse a localized rupee input once at the UI boundary using decimal-string logic; never use binary floating point for storage, addition, comparison, conversion or export. Render with locale-aware formatting only after the integer result is known.
4. Keep `Draft`, `Pending`, `Synced` and `Needs attention` distinct. A tap on Submit must create a stable operation UUID and commit entry + outbox in one SQLite transaction before success UI. Never generate a fresh ID merely because a request timed out.
5. Treat repositories as the only owners of SQLite and HTTP access. The sync coordinator claims one outbox item at a time per account/shop, sends the original payload, classifies retryable versus permanent failures, and advances a pull cursor only with an atomic cache write. Do not hide a failed sync behind a generic success toast.
6. Partition local records by internal account ID. Lock an old account's cache on sign-out/switch, preserve unresolved Pending operations and keep credentials in Android secure storage rather than SQLite. The local QR cache may speed an existing link offline but cannot authorize a new link.
7. Keep text in localization resources with stable message keys. Review English and Hindi for debt direction, payment status and sync warnings. Do not build user-facing sentences by concatenating translated fragments. Show status with text/icons as well as color and give QR, amount and error controls screen-reader labels.
8. Use app-private storage for financial data and temporary exports. Request camera permission at scan time. Release manifest and backup rules must match [SEC-13](SECURITY-REQUIREMENTS.md#6-android-local-data-and-export-requirements).

Flutter's own testing guidance distinguishes unit, widget and integration tests; use each where it gives meaningful confidence rather than aiming for a number that rewards trivial tests. [Flutter testing overview](https://docs.flutter.dev/testing/overview), [Effective Dart style](https://dart.dev/effective-dart/style).

## 4. TypeScript Worker rules

1. Compile with `strict` TypeScript settings. Prefer explicit request/response/domain types, discriminated unions for result states, and checked array/map access. Avoid `any`; if unavoidable at a library edge, isolate it and validate before domain use.
2. Accept `unknown` at the HTTP JSON boundary. A single schema validator checks body size, content type, exact fields, types, integer bounds, UUID shape, QR syntax and date format before constructing a domain command. Unknown financial mutation fields are errors, not ignored extras.
3. Authenticate first, then authorize role, shop/link and active status before sensitive reads or writes. Never accept a client role, Google email, QR ID or balance as authority. Customer queries derive user ID from the session. Use typed authorization helpers whose return value is required by services.
4. Keep the route layer thin: parse → authenticate → authorize → call service → map stable API result. Public error bodies contain code, localization key and request ID, not SQL errors, stack traces or another tenant's existence.
5. Use D1 prepared statements with bound parameters. Query text, sort order and identifiers must be fixed or chosen from a small allowlist; never interpolate arbitrary user strings. Every ledger read includes authorized scope and bounded pagination.
6. Use a cryptographically secure source for QR and session tokens. Verify Google token signature and claims on the Worker. Signing keys and other secrets live in Cloudflare secret bindings; D1 binding is server-only. No secret in `vars`, source, test snapshot or mobile binary.
7. Implement ledger post and link as atomic D1 operations. Check the stored operation receipt before mutable business-state validation; same hash replays the original committed outcome, different hash conflicts. Payment balance and correction revision must be guarded in SQL at commit, not only by a pre-read. Audit D1 trigger and batch behavior on the pinned runtime.
8. Use structured telemetry with route template, request ID, latency, status/error class and D1 row usage. Exclude tokens, Google subject, QR IDs, names, notes, reasons and amounts from routine logs and analytics. Redaction is tested with synthetic sentinels.

TypeScript compiler options and D1 APIs may change; pin the compiler and Wrangler versions, and verify settings against current official documentation during phase 0. [TypeScript `noUncheckedIndexedAccess`](https://www.typescriptlang.org/tsconfig/noUncheckedIndexedAccess.html), [D1 Worker API](https://developers.cloudflare.com/d1/worker-api/d1-database/).

## 5. Domain modeling and time rules

| Concern | Rule |
|---|---|
| Money | Positive entered amount; signed ledger effect; checked integer arithmetic and an approved maximum. `₹500` is `50000` paise. |
| IDs | Opaque domain-specific types where practical. `clientOperationId` is generated once per action and stored with original payload. |
| Balance | Acknowledge D1 sum/projection as authoritative; local sum with Pending is provisional and labeled. Reconcile projection against immutable entries. |
| Corrections | Append a new entry referencing an original credit/payment with target amount, reason and expected revision. Keep original and all corrections visible. |
| Payments | `cash` or `upi` is owner-entered; no bank verification claim. Reject payment greater than current owed amount. |
| Timestamps | Server sets `createdAtMs`; device `occurredAtMs` is display/audit input, not posting order. Use UTC instants internally and user locale for display. |
| Due dates | Store a calendar date; do not show aggregate overdue amount until payment-allocation rule is approved and tested. |
| Pagination | Stable server sequence and authenticated scope; atomically persist cache page and cursor. Never use device clock as sync cursor. |

Business types should reject impossible values at construction. Mapping code explicitly converts between Dart, JSON and SQL names. Avoid hidden conversions such as `num.toInt()`, broad `parse` fallbacks, implicit timezone conversion or `double` formatting for exports.

## 6. Database and migration rules

1. Version D1 migrations as numbered, immutable SQL files. A reviewed migration states the old/new schema, data transform, forward-repair path, backup requirement and validation queries. Never edit an already-applied migration; create a new one.
2. Pin the migration target database name/ID and environment. Apply to disposable local/staging D1 first, then rehearse against representative data. Production migration requires backup and restore evidence, change record and explicit operator review.
3. Every migration runs foreign-key checks and balance/receipt reconciliation. Preserve ledger rows, `client_operation_id`, correction links, session revocation state and shop/customer links. No blanket cascade delete of financial history.
4. Use constraints/indexes for uniqueness and exact scoped queries, but measure row reads/writes and storage. Adding indexes changes D1 free-tier usage; check `EXPLAIN QUERY PLAN` and realistic load before accepting one.
5. Test triggers and transactional batches for duplicate operation ID, payment race, correction race, projection update and rollback. A local SQLite test is useful but does not replace a D1 integration test.
6. Version local SQLite schema independently. An app update may encounter an old Pending outbox; migration must preserve the operation ID, original command and status or provide an explicit recovery path. Test process crash at each migration boundary.

Cloudflare's migrations are versioned SQL files applied through Wrangler; verify the pinned Wrangler behavior before execution. [Cloudflare D1 migrations](https://developers.cloudflare.com/d1/reference/migrations/).

## 7. Errors, retries and observability

Return typed domain outcomes such as `ValidationError`, `Forbidden`, `BalanceConflict`, `RevisionConflict`, `IdempotencyConflict` and `RetryableUnavailable`. Map them once to the stable codes in the [API Specification](API-SPECIFICATION.md#8-status-codes-retries-and-compatibility). Do not catch every exception and return 200. Do not retry an authorization, validation or conflict error automatically. Timeout/5xx/429/quota errors retain the original outbox body and operation ID, use bounded exponential backoff with jitter, and remain visibly Pending. A response lost after commit is retried safely and reconciled to the original entry.

Log a request ID and outcome class for each server request. Log sync queue age/count and state transitions without financial values. Build support diagnostics around IDs and timestamps that reveal no sensitive content in routine telemetry. Avoid recording full HTTP bodies in production monitoring, crash reports, CI artifacts or test snapshots.

## 8. Testing and CI baseline

Tests must exercise outcomes and invariants, not duplicate implementation lines. Each feature PR adds or updates tests at the narrowest useful layer, then runs the appropriate higher-level path for changed boundaries. Minimum suites:

| Layer | Required scenarios |
|---|---|
| Dart domain/unit | Decimal-string money parse, overflow/limits, balance effects, correction delta, QR parser, sync error classification. |
| Flutter widget | Customer identity and amount before Submit; Pending/Synced/Needs attention labels; owner/customer balance wording; Hindi/English critical strings and accessibility semantics. |
| Local SQLite | Atomic entry+outbox save, restart survival, account isolation, cursor+cache transaction and migration from previous schema. |
| Worker unit/contract | Strict JSON validation, Google token claim failures, role and shop/link policy, stable response/error schemas. |
| D1 integration | Concurrent duplicate, same ID/different body, overpayment race, repeated/stale correction, trigger rollback, FK integrity and balance reconciliation. |
| Device/end-to-end | New QR online, existing QR offline, unknown QR offline, Google sign-in, lost response, quota outage, new-phone restore, share/export and camera permission denial. |

Suggested CI sequence after scaffolding: install **pinned** dependencies from lock files; format check; Dart/TypeScript static analysis; unit/widget tests; Worker contract tests; local SQLite and D1 integration tests; security/secret/dependency scan; build an Android release candidate; run selected device tests before release. Keep exact commands in repository scripts so local and CI behavior match. Likely starting commands are `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `tsc --noEmit` and the pinned package-manager test script. Do not claim these pass until the source tree and toolchain exist. A coverage percentage alone is not a release gate; money, authorization, idempotency and recovery scenarios must pass explicitly.

## 9. Git, review and change control

- Use small, reviewable changes that map to SRS/SEC IDs or a documented defect. Commit messages state the behavior changed, not just “fix” or “update.” Keep generated files, build outputs, secret files, signed APKs and production exports out of source control; commit lock files, migrations and nonsecret config templates.
- PR description states the trigger, before/after behavior, affected requirement IDs, schema/API compatibility, tests run and unresolved risks. Include screenshots or a short recording for visible UX changes only when useful, using synthetic data.
- Require review from someone other than the author for changes to money arithmetic, authorization, session handling, D1 triggers/migrations, sync/idempotency or deletion/export flows. When team size is one, obtain an independent review before real-user deployment.
- Review the diff for accidental secrets, sensitive logs, missing permission checks, unbounded queries, changed operation IDs, floating money math and untested migration paths. Run dependency advisories for both Dart and Node ecosystems and triage exploitable findings before release.
- A contract change updates the relevant [API Specification](API-SPECIFICATION.md), [Database Design / ERD](DATABASE-DESIGN-ERD.md), [Security Requirements](SECURITY-REQUIREMENTS.md), [SRS](SRS.md) and tests in the same change. A product-scope change also updates BRD/PRD and phase plan after product-owner decision. Preserve old outbox replay compatibility during API evolution.

## 10. Definition of done and open setup decisions

A change is done only when its user-visible behavior and requirement IDs are clear; code is formatted/analyzed; relevant tests pass; data-access and money invariants are reviewed; migrations are rehearsed where applicable; localization/accessibility and telemetry are checked; and reviewer evidence is recorded. A phase or public release additionally requires the gates in [Security Requirements](SECURITY-REQUIREMENTS.md#8-required-security-tests-and-release-gates), the later Test Plan and a successful backup/restore drill.

Before implementation starts, decide and pin: supported Android versions/devices; Flutter/Dart, TypeScript, Wrangler and package-manager versions; state-management, SQLite, HTTP and schema-validation packages; maximum amount/text bounds; local database encryption; CI environment and code ownership. Record decisions without silently changing the approved QR-first, free-to-user v1 product. The next document, **Test Plan**, will organize verification by phase, environment, severity and exit criteria.
