# Daily implementation progress

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../DOCUMENT-MAP.md). **Read with:** [Daily implementation plan](README.md) · [Roadmap](../../PROJECT-PLAN-ROADMAP.md) · [Test plan](../../TEST-PLAN.md).
<!-- DOC_NAV_END -->

**Current phase:** D04 local engineering complete; live OAuth gate pending. **Last updated:** 1 October 2026. D05 is next after the chosen live setup checkpoint.

| Phase | State | Date | Evidence / blocker |
|---|---|---|---|
| D01 | Done | 2026-09-29 | Local Git repository, root ignore/README, Android ID/API 24/label/unsigned release config, Flutter smoke test, Worker scaffold and lockfile, CI workflow. See evidence below. |
| D02 | Done | 2026-09-30 | Flutter architecture and guarded shells, Worker edge pipeline, shared fixtures, and tests. See D02 evidence below. |
| D03 | Done | 2026-09-30 | Local D1 migration, SQL ledger/projection/receipt guards, account-scoped SQLite and atomic persistence adapters. See D03 evidence below. |
| D04 | Done locally; live gate pending | 2026-10-01 | Google verifier, rotating sessions, secure Android storage, role/sign-out UI and synthetic tests. See D04 evidence. |
| D05-D24 | Not started | - | Follow the order in [README](README.md). |

### D04 evidence (2026-10-01)

Branch `codex/d04-auth`, based on D03 commit `3906488`. Local implementation only: trusted Google RS256 JWKS verification with issuer/audience/subject/expiry/issued-time checks; immutable role/subject account mapping; 256-bit opaque credentials hashed with SHA-256; 15-minute access and rotating refresh capped at 30 days from initial creation; spent-token replay revokes the whole session, logout only its device session; atomic network auth throttling. HTTP Google exchange/refresh/logout/profile are wired with safe envelopes. Profile publishes capability versions; shop/link summaries are later work.

Android uses google_sign_in 7.2.0 and flutter_secure_storage 11.2.0, requires public API_BASE_URL and GOOGLE_SERVER_CLIENT_ID build configuration, and disables sign-in until configured. Role selection routes by server-confirmed account. Sign-out counts and preserves Pending rows, locks the old database and clears credentials. Offline sign-out explicitly reports unconfirmed cloud revocation. An uncertain refresh requires reauthentication without erasing the database.

| Check | Evidence |
|---|---|
| Worker tests | PASS: 51 runtime tests plus one Node configuration test; identity negative cases, subject/role, hashes, rotation/replay/race, expiry/logout, rate window, HTTP lifecycle and session SQL guards. |
| Worker coverage | PASS: 169/170 lines (99.41%), 107/131 branches (81.67%), all 80% gates. |
| Worker static/build/audit | PASS: typecheck, lint, dry-run Worker bundle, zero audit vulnerabilities. No deployment. Credential-pattern scan of tracked/new source and APK secret-file scan passed; this is a bounded scan, not exhaustive proof. |
| Local D1 migration | PASS: new immutable 0002 applies six commands over existing 0001; foreign_key_check empty. 0001 unchanged. 0002 not applied remotely. |
| Flutter tests | PASS: 34 tests, including Google action/cancellation/sign-out UI, actual SQLite Pending preservation and account B isolation, uncertain refresh and stalled profile regression. |
| Flutter coverage/static | PASS: 436/489 lines (89.16%), minimum 80%; formatting and analyze clean. |
| Android build | PASS: debug APK assembled with Gradle nonincremental/in-process Kotlin flags, avoiding Windows C:/D: Pub-cache root issue. Standard Flutter command initially failed on Kotlin caches; no release-signed build claimed. |
| Review | One fresh read-only reviewer, no Critical. Important stalled profile request fixed: regression failed first, shared GET timeout added, full 34-test suite passed. |

**Live gate / limitations:** Google registration, real Android account-picker/secure-storage/backup checks, release signing and Worker deployment need approved external setup. Full offline startup access/general financial refresh remain D12/later integration; storage encryption/physical extraction review stays D12. Session-history cleanup/retention stays D19. Real customer data was not used. D03 staging contains only its dedicated synthetic records.

**Resolved decisions:** new and existing Google exchange returns HTTP200 with the same session shape; API contract aligned (clients assuming201 must adjust). Retain app-private SQLite rather than introduce SQLCipher before the planned device review; compromised-device exposure remains a known release risk. Reviewer did not judge live/provider/hardware behavior: these remain explicit unverified gates, so local tests cannot establish a complete native Google A-to-B journey.

**Deferred minor:** native Google credential state is not explicitly cleared on sign-out; installed Android authenticate uses the explicit account-picker flow, so no switching blocker was demonstrated. Confirm this during live device testing and add native clearing if that flow requires it.

### D03 Cloudflare staging follow-up (2026-09-30)

User authorized staging migration. Database `udhaarkhata-staging` (`a9e24716-d05a-46f7-8189-1bf2d8b05c46`) is configured under the explicit Wrangler `staging` environment; default local binding remains unchanged. Remote `0001_initial.sql` applied successfully (44 commands); repeat application reported no migrations to apply. Remote inspection confirmed migration tracking plus 14 tables (including platform/migration tables), 12 named indexes and 19 triggers. No Worker deployment or real customer data was used.

Follow-up 2026-10-01: remote `PRAGMA foreign_key_check` passed on both empty and populated staging data. Dedicated synthetic owner/customer/shop/link records (`d03_test_*`) remain in staging: 50000 paise credit and 20000 paise cash payment produced balance 30000, version 2, two entries and reconciled ledger sum 30000. Attempted posted-entry update was rejected with `ENTRY_IMMUTABLE`; subsequent reconciliation stayed unchanged. This completes the added remote schema smoke gate; full synthetic invariant coverage remains in the existing local D1 runtime suite. No mobile/API end-to-end flow or Worker deployment is claimed.

Optional `PRAGMA integrity_check` was rejected by D1 with `SQLITE_AUTH`; no integrity-check success is claimed. Network requests remain intermittent; preferring IPv4 and disabling Node network family autoselection allowed successful checks. After a timed-out synthetic insert request, state was inspected before retrying; no duplicate entries were created.

### D03 evidence and implementation boundaries

The [D03 plan](01-foundation.md#d03--cloud-and-device-schemas) is implemented in [D1 migration 0001](../../services/api/migrations/0001_initial.sql), [receipt queries](../../services/api/src/db/queries.ts), [atomic receipt commit](../../services/api/src/db/transaction.ts), [device database](../../udhaarkhata/lib/core/db/database.dart), [local schema](../../udhaarkhata/lib/core/db/migrations.dart), and [local persistence adapter](../../udhaarkhata/lib/core/db/repositories.dart). Both use synthetic data only. The current checkout is on local branch `phase/d03-schemas`; no push or deployment was performed.

| Verification | Recorded result |
|---|---|
| `npm ci`, `npm run typecheck`, `npm run lint` | PASS; locked install and source/test static checks. |
| `npm test` | PASS; 43 Workers-runtime tests (17 D03 database tests plus 26 prior tests) and one Node configuration test. |
| `npm run test:coverage` | PASS; 102/102 Worker source lines, 45/46 instrumented branches; 80% gates passed. SQL is verified by runtime assertions, not included in TypeScript coverage. |
| `npm run db:migrate:local` | PASS; 0001 applied (44 SQL commands); second and subsequent runs report no migrations to apply. Zero placeholder database ID, `remote:false`, explicit `--local`. |
| `npm run db:check:local` | PASS; `PRAGMA foreign_key_check` returns no violations. Integration tests independently check FKs on populated synthetic rows. |
| Migration rehearsal | PASS; fresh creation and repeat, test-only additive upgrade preserving posted history, failed migration rollback, and failed entry/receipt batch rollback. D02 had no prior financial schema; future real migrations require their actual previous-version fixture. |
| `npm run build`, `npm audit --audit-level=high` | PASS; local binding dry-run bundle; zero reported vulnerabilities. |
| `flutter pub get --enforce-lockfile`, Dart format check, `flutter analyze` | PASS; locked sqflite 2.4.4, test adapter sqflite_common_ffi 2.4.3, existing crypto 3.0.7 promoted to direct dependency; no analyzer issues. |
| `flutter test --coverage` | PASS; 29 tests, no skips (13 D03 SQLite tests plus 16 prior tests). |
| `python scripts/check_coverage.py udhaarkhata/coverage/lcov.info` | PASS; 282/299 executed-source lines (94.31%), minimum 80%. |
| `flutter build apk --debug` | PASS; Android debug APK includes the SQLite plugin and extraction rules. Merged debug manifest inspection confirms backup disabled and extraction rules referenced. |
| Markdown navigation and links | PASS; 38 Markdown documents, all mapped and reachable. |

D1 tests prove exact positive/negative effects, payment and correction races, successive correction deltas, payment cancellation, balance overflow rejection, same-operation concurrent replay, changed-hash rejection, receipt immutability, entry update/delete/replace rejection, active ownership/link guards, QR uniqueness/rotation, dispute scope, and rollback of entries/projections on a failed later statement. They execute on the pinned Cloudflare Workers/D1 local runtime (Wrangler 4.144.0), rather than a substitute money model.

Device tests use real SQLite through the host adapter: original entry/outbox survives close/reopen; failed outbox and cache/cursor transactions leave no partial state; account A/B isolation and locks preserve old Pending data; maximum-length and case-distinct account IDs have separate safe filenames; malformed rows and command updates fail; unknown schema downgrade fails closed; acknowledgments preserve local identity and remove the outbox atomically; incomplete/mismatched acknowledgments preserve Pending; established server identity cannot change; restore/replay works without device operation IDs. Customer/new-device acknowledged cache rows may omit an operation ID; locally queued commands must retain their original UUID.

TDD evidence: the first 11 D1 tests failed with `no such table: users` before the migration; local tests first failed because the database adapter did not exist. Date/cursor edge tests then reproduced missing guards. A fresh whole-change reviewer found two Important local cache issues: mandatory operation IDs on restored rows and incomplete acknowledgment matching. Three regression tests reproduced those failures, then passed after the fixes; the full suites pass. No Critical findings were reported. This review is a code review, not completion of the later full security audit or device journeys.

**Decisions:** safe integer is the technical storage ceiling, with 120-character labels and 500-character notes/reasons; the smaller business amount cap remains D08. Opaque access credentials use `access_sessions` linked to hashed refresh sessions, consistent with the implementation index. Local balance is a SQLite view of stored entries, so the transaction also atomically determines synced/provisional totals without a second mutable projection. Android app-private storage and backup exclusions are in place; encryption/device review remains D04/D12.

**Unresolved / next phase:** D04 must implement Google verification, opaque access/rotating refresh credentials, lifetimes, secure storage and session revocation. One review minor is deferred to a new numbered D04 migration before credential issuance: align unused `access_sessions` hash-hex and timestamp upper-bound guards with the stricter refresh/financial tables. Live OAuth, physical Android backup/process-death tests, user-facing offline sync, and real-data backup/restore remain their assigned later gates. No real customer records or Google resources were used or changed; approved Cloudflare staging setup is recorded above. Workstation launch commands needed the bundled PowerShell and Node directories prepended to PATH; installed Flutter/Dart versions remained unchanged.

### D02 evidence and implementation boundaries

The [D02 plan](01-foundation.md#d02--architecture-skeleton-and-error-contracts) is implemented in [Flutter app/router](../../udhaarkhata/lib/app/router.dart), [session controller](../../udhaarkhata/lib/features/auth/session_controller.dart), [Worker router](../../services/api/src/http/router.ts), [schemas](../../services/api/src/http/schemas.ts), and [shared contract fixtures](../../contracts/d02-fixtures.json). Repository interfaces live under Flutter `core` and `features`; widgets contain no SQL or HTTP calls. Tests inject synthetic owner/customer identity through repository/authenticator interfaces. Production authentication fails closed and the Google button is disabled until D04.

| Verification | Recorded result |
|---|---|
| `flutter pub get --enforce-lockfile` | PASS; pinned Flutter dependencies resolve. |
| Dart format check and `flutter analyze` | PASS; no analyzer issues. |
| `flutter test --coverage` | PASS; 16 tests, no skips; 160/163 executed-source lines covered (98.16%). |
| `python scripts/check_coverage.py udhaarkhata/coverage/lcov.info` | PASS; minimum 80%. |
| `flutter build apk --debug` | PASS; Android debug APK built. |
| `npm ci`, `npm run typecheck`, `npm run lint` | PASS; source and test types checked. Lint tooling updated to supported ESLint 10. |
| `npm test` | PASS; 26 Workers-runtime tests plus one Node configuration test. |
| `npm run test:coverage` | PASS; 89/89 Worker source lines, 38/38 instrumented branches; minimum 80%. |
| `npm run build` | PASS; Wrangler dry-run bundles with no remote bindings; no deployment. |
| `npm audit --audit-level=high` | PASS; zero reported vulnerabilities. |
| Markdown navigation and links | PASS; all 38 Markdown files linked and mutually reachable. |

TDD record: the [welcome test](../../udhaarkhata/test/app_smoke_test.dart) first failed because the starter lacked the welcome screen; the first three [Worker tests](../../services/api/test/http.test.ts) failed because every request returned 503. RED checkpoint: `77ff8e7`; initial implementation checkpoint: `bf22b2b`. A second RED check caught body-limit/internal-error codes differing from the API specification (checkpoint `5e5e21e`); the final implementation uses `PAYLOAD_TOO_LARGE` and `SERVER_ERROR` and the same tests pass. [Router tests](../../udhaarkhata/test/router_test.dart) prove signed-out and cross-role deep-link denial, loading, retry, and disabled sign-in. [Contract tests](../../services/api/test/contracts.test.ts) and [Dart counterparts](../../udhaarkhata/test/contracts_test.dart) verify the same ID/paise/timestamp/cursor/envelope fixtures; telemetry tests use sentinels to detect private-data leaks.

The coverage numbers apply to executable D02 scaffold code, not to future ledger, D1, offline sync or identity implementations. Health is liveness only. Domain routes, Google authentication, local SQLite, tenant ownership checks, and live deployment are deliberately still governed by their later phase gates. No real customer records or Cloudflare/Google resources were changed. GitHub publication is explicitly authorized by the user's request for this phase.

### D01 evidence and remaining setup notes

- Toolchain: Flutter 3.47.4 / Dart 3.13.3; Node 24.11.1 / npm 11.6.2; Git 2.55.0; Android SDK 36.1.0 and JDK 21. `flutter doctor -v` found unaccepted Android licenses. Windows Visual Studio components are irrelevant to the Android-only release target.
- Flutter: `flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, and `flutter build apk --debug` passed. The smoke test launches the current starter app. A first optional release-build attempt was stopped after a prolonged Gradle run; no signed release artifact is claimed.
- Worker: `npm ci`, `npm run typecheck`, `npm run lint`, `npm test`, and `npm audit --audit-level=high` passed (zero reported vulnerabilities). Local `npm run dev` served a deliberate `503 NOT_IMPLEMENTED` response with `Cache-Control: no-store`; no remote binding/deployment exists.
- Secret and signing review: `.dev.vars`, Android `local.properties`, `node_modules` and build artifacts are ignored; lockfiles are not ignored. Android release Gradle block has no debug signing configuration. CI was added but cannot be claimed to have run on GitHub before a remote repository exists.
- Before D04 OAuth registration: verify publisher control of `com.udhaarkhata.app` and confirm the package ID. Before a release: accept Android SDK licenses on build machines, configure an approved release signing key, and run the full release build and device matrix. No Cloudflare or Google resources were changed.

For each completed phase, replace the placeholder with a row containing phase ID, `Done`/`In progress`/`Blocked`, completion date, changed file links, check commands and results, acceptance evidence, unresolved issues, and the next phase. Do not mark a phase Done because files merely exist. Note external approvals and actual environment IDs only in a safe local/private operations record; never put secrets here.

## Decision and deviation log

| Date | Phase | Decision or deviation | Documents/tests updated |
|---|---|---|---|
| 2026-09-29 | Plan | Existing Flutter path retained; milestone roadmap decomposed into daily phases. | This plan and `AGENTS.md`. |
| 2026-09-29 | D01 | Selected Android package `com.udhaarkhata.app`, minimum API 24, Node 24, and a local-only Worker config. Publisher ownership and pilot device compatibility are later gates, not claims of verification. | Root `README.md`, Android Gradle/manifest, Worker config, CI. |
| 2026-09-29 | Documentation | Added a full Markdown document map, top-of-file related links, and CI validation of file/anchor links and document connectivity. D02 implementation remains not started. | `DOCUMENT-MAP.md`, `AGENTS.md`, `scripts/update_doc_navigation.py`, `scripts/check_docs.py`, CI. |
| 2026-09-30 | D02 | Selected Riverpod 3.4.3 and go_router 18.0.2; retained the real Flutter path. Added 64 KiB streamed JSON bound, shared wire constraints, fail-closed auth adapter, Workers Vitest integration (4.1.11/plugin 1.3.3), and coverage gates. | API/LLD/HLD/SES/coding standards, shared fixtures, README, tests and CI. |
| 2026-09-30 | D03 | Local D1 triggers/batch receipts, account-isolated sqflite, hash filenames, computed local balance view, optional operation IDs on restored rows, complete acknowledgment matching and backup exclusions. Storage ceilings fixed now; business amount cap D08; access-session guard minor D04. | Database/API/SRS/PRD/security/HLD/LLD/SES, runbook, README, CI and persistence tests. |
