# Udhaar Khata — Test Plan

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [SRS](SRS.md) · [Security requirements](SECURITY-REQUIREMENTS.md) · [QA cases](TEST-CASES-QA-CHECKLIST.md) · [Roadmap](PROJECT-PLAN-ROADMAP.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Release:** Android v1  
**Status:** Release verification plan; local D01?D03 checks are evidenced in implementation progress  
**Baseline:** [SRS](SRS.md) · [PRD](PRD.md) · [Project Plan](PROJECT-PLAN-ROADMAP.md) · [API Specification](API-SPECIFICATION.md) · [Security Requirements](SECURITY-REQUIREMENTS.md)

## 1. Purpose and test objective

This plan explains **how, when and with what evidence** the first public release of Udhaar Khata will be verified. The app is a free Flutter Android customer-credit ledger: a customer signs in with Google and shows a QR; the shop owner scans, links online if new, and records credit or manually received cash/UPI payment. Previously linked customers can be served offline through a durable local outbox. D1 is authoritative only for acknowledged transactions. Both sides see their authorized history, while the owner can correct entries and the customer can dispute them.

The most important release claims are exact balance, no duplicate posting on retry, cross-shop/customer privacy, no silent loss of local Pending records, and honest recovery language. A green build alone is insufficient. Each SRS requirement needs a mapped test or inspection record, and every high-risk failure mode needs evidence from the relevant boundary—especially D1 concurrency and a real Android device.

This plan is separate from the next **Test Cases / QA Checklist** document, which will list executable case IDs and step-by-step checks. Release cases remain planned until their individual phase evidence is recorded; local D01?D03 results are in [implementation progress](docs/implementation/PROGRESS.md).

## 2. Scope and exclusions

| In scope | What to prove |
|---|---|
| Identity, role and shop setup | Valid Google sign-in; immutable subject mapping; one shop per owner; account isolation. |
| QR and linking | Versioned random QR, online new-link confirmation, existing-link repeat flow, invalid/revoked/offline unknown states. |
| Ledger | Integer paise, credit/payment/correction effects, nonnegative balance, immutable history, due dates, stable ordering. |
| Offline and sync | Atomic local save, restart survival, retry with original operation ID, reconciliation, conflicts and quota outage. |
| Customer trust | Authorized customer view, dispute and owner resolution, Pending visibility rules. |
| Release features | Reminder preview/share, PDF/CSV reconciliation, English/Hindi, accessibility, data requests. |
| Operations/security | Session lifecycle, tenant isolation, secrets/log redaction, backup/restore, migration, quota and device compatibility. |

Out of v1 scope: actual UPI/bank payment verification, payment gateway, inventory, invoicing, automatic messaging, staff roles, iOS/web, multiple shops per owner, advances/negative balances and supplier ledgers. Tests must still check that the UI does not **claim** those capabilities. A due date can appear on a credit, but aggregate overdue amount is excluded until a payment-allocation rule is approved and verified. Retention/deletion timelines are a pre-launch decision; tests should verify the implemented and published policy once fixed, not invent a legal period.

## 3. Verification principles and traceability

1. Use [SRS requirement IDs](SRS.md#4-functional-requirements), [SEC IDs](SECURITY-REQUIREMENTS.md) and PRD acceptance criteria as test sources. Create a traceability matrix with requirement → case ID → run ID → evidence → defect/status. A requirement with no evidence is **Not verified**, never silently Passed.
2. Assert observable behavior and database invariants. Tests that only reproduce a helper's algorithm do not prove the app's financial behavior. Reconcile independently: `SUM(committed effectPaise) = ledger_accounts.balance_paise` for every link in the test dataset, and opening + date-range effects = closing in each statement.
3. Separate **local provisional** from **server acknowledged** assertions. Owner Pending may affect a clearly labeled local balance; customer API/history and new-device restore contain acknowledged entries only.
4. Use negative authorization tests with two owners and multiple customers on shared and different shops. A successful same-user path alone does not establish privacy.
5. Inject failures at each write boundary: before local commit, after local commit/before send, after D1 commit/before response, during retry, and during local acknowledgment. Preserve the original operation ID and check exactly one cloud effect.
6. Capture a reproducible build, schema migration version, Worker version, test data seed and environment for each significant run. Sensitive names, amounts and tokens must not enter routine logs or public artifacts; synthetic fixtures are used in test evidence.

## 4. Test levels and ownership

| Level | Primary owner | Focus | Typical execution |
|---|---|---|---|
| Static review | Engineers + reviewer | Types, formatting, secret scan, SQL scope, migrations, localization keys and Android manifest | Every change/CI. |
| Dart domain unit | Flutter engineer | Decimal input to paise, bounds, signed effects, QR parser, retry classification | Every change/CI. |
| Flutter widget | Flutter engineer + QA | Confirm identity/amount, owner/customer wording, status labels, accessibility semantics, Hindi/English critical paths | Every UI change/CI. |
| Local SQLite integration | Flutter engineer | Atomic outbox, restart, account partition, cache/cursor migration | Every persistence change/CI. |
| Worker unit/API contract | Worker engineer | JSON schema, Google claim rejection, role policy, status codes and response shape | Every API change/CI. |
| D1 integration/concurrency | Worker engineer + QA reviewer | FK/trigger/batch rollback, duplicate receipts, payment and correction races, reconciliation | Every ledger/schema change, release candidate. |
| Android end-to-end | QA + Flutter engineer | Real sign-in, camera permission, first/repeat QR, offline/reconnect, share/export and device restore | Each phase exit, release candidate. |
| Security/privacy review | Independent reviewer when possible | Cross-tenant matrix, token handling, backup rules, data minimization, rate limits | Phase 0 and full release review. |
| Pilot acceptance | Product owner + participating shops | Speed, comprehension, QR adoption, disputes, sync and support | Phase 4, consented real-world pilot. |

One person can hold several roles, but a separate reviewer should examine changes to money, authorization, idempotency, migrations and recovery before real financial data is admitted. CI does not replace manual device and operational drills.

## 5. Environments, builds and devices

| Environment | Data and purpose | Restrictions |
|---|---|---|
| Local developer | Generated synthetic accounts and throwaway local D1/SQLite; rapid unit/integration work | No production credentials or copied user ledgers. |
| Staging | Separate Google OAuth client, Worker, D1, signing keys and telemetry; near-release integration and recovery drills | Synthetic or explicitly consented data; never points at production D1. |
| Private pilot | Release-like signed Android build and controlled real shops after security/backup gates | Consent, privacy notice, support contact and rollback plan. |
| Production | Public app and live D1 | Smoke tests use prearranged test accounts; no destructive test data or fault injection. |

At phase 0, record the minimum supported Android version, two representative low-end phones, one mid-range phone, and at least one device with a different screen size/camera. Test on the exact OS/device matrix that will be supported; emulator-only results do not prove camera, secure storage, backup rules or performance. Capture app version/build hash, Worker deployment ID, D1 migration number, Flutter/Dart/TypeScript/Wrangler versions and locale with each phase-gate run. Android release signing and Google OAuth fingerprints must be tested in staging before pilot.

Use a controllable network layer or proxy in staging for airplane mode, slow/intermittent connection, timeout, 429, 5xx and response-loss injection. D1 concurrency tests must use the pinned Cloudflare D1 runtime or staging D1, not only an in-memory SQLite substitute. Quota exhaustion should be simulated safely in staging; do not intentionally consume production free-tier quota.

## 6. Test data and privacy

Prepare deterministic synthetic fixtures: owner A/shop A, owner B/shop B, customer A linked to both shops, customer B linked only to shop A, and unlinked customer C. Include active/revoked QR IDs, one credit with due date, partial/full payment, repeated corrections, open/resolved dispute, and Pending/Needs attention local operations. Test with Indian rupee examples such as ₹500 credit and ₹200 payment, yielding ₹300 owed. Include boundary values: zero, negative, smallest positive paise, maximum approved entry amount, one above maximum, unsafe integer, huge note, invalid date and malformed QR.

Every run starts from a known seed or documented snapshot. Do not use actual customer names, Google tokens or live ledger data in screenshots, CI logs or bug attachments. If a pilot issue requires real data, collect only the minimum with consent and restricted support access. The actual maximum amount, text caps and retention rules remain open decisions; record them in the test-data version once approved, then rerun boundary tests.

## 7. Phase test plan and gates

| Phase | Planned suites | Exit evidence |
|---|---|---|
| **0 Foundation** | Google ID-token positive/negative claims; owner/customer role; one shop; account switch; initial D1/local migrations; authorization smoke; secrets/manifest review | SRS F-001–005, N-001–003, D-003 and SEC identity/session baseline mapped and passed; staging isolated from production. |
| **1 Online ledger** | QR payload/rotation, new link and repeat scan; credit/payment; owner/customer list/history; idempotency and cross-shop matrix; exact paise | New link once, ₹500–₹200=₹300 in both synced views, same operation ID posts once; SRS F-006–019, F-022, D-001–002 covered. |
| **2 Offline and trust** | Airplane-mode known/unknown QR, atomic outbox/restart, lost acknowledgment, conflicts, account isolation, correction revision, dispute and new-device restore | One synced effect after retry, Pending truthfully labeled, customer privacy intact; SRS F-020–021, F-024–032, N-004, N-010 covered. |
| **3 Release completeness** | Due date, preview/share, PDF/CSV totals, Hindi/English, accessibility, request tracking, backup/restore, logs and quota alerts | Reports reconcile, critical translations/accessibility pass, policy and restore drill approved; SRS F-023, F-033–037, N-005, N-007–009, D-004–006 covered. |
| **4 Pilot/launch** | Full regression, low-end device speed, supported OS matrix, long-running sync/quota profile, security review, shop observations and incident rehearsal | SRS N-006, N-011–012 and all prior requirements evidenced; go/hold decision recorded. |

Do not start a real-user pilot until identity, tenant isolation, ledger integrity, local data protection, quota behavior and backup/restore gates pass. A phase may proceed with a clearly documented lower-priority defect only if it cannot affect money, privacy, outbox durability or recovery claims. Public launch requires a fresh regression after the last release-candidate change.

## 8. Critical end-to-end and fault journeys

The [SRS verification scenarios V-01–V-11](SRS.md#9-verification-scenarios) are mandatory journey anchors. The next QA Checklist will give exact steps and expected values. Minimum fault matrix:

| Fault point | Expected result and evidence |
|---|---|
| Before local SQLite commit | No “saved” confirmation and no orphan outbox/entry row. |
| After local commit, before network send | Entry and operation ID survive restart as Pending. |
| After D1 commit, before HTTP response | Retry with same ID returns original receipt, no extra balance effect. |
| Duplicate key with changed body | `IDEMPOTENCY_CONFLICT`, original entry unchanged. |
| Two payments against same balance | Commit-time guard allows no overdraw; rejected item remains Needs attention locally. |
| Two corrections at same expected revision | One succeeds, one `REVISION_CONFLICT`; history and projection reconcile. |
| Link revoked/owner access lost while offline | Queued write denied on sync, retained for investigation, no unauthorized D1 row. |
| D1/Worker quota unavailable | Known-link owner write stays Pending; unknown-link onboarding blocked; no false backup claim. |
| Phone lost with one Synced and one Pending | New phone retrieves Synced only and explains Pending absence. |
| Cursor page/crash between cache and cursor | No skipped acknowledged entry on next pull. |
| QR copied or malformed | Scan alone posts nothing; malformed/unsupported/revoked states actionable. |

Failure injection should observe the API and D1 state independently of the UI. Record entry count, receipt count, per-link sum and version before/after. Repeating the same fault test without cleaning or versioning fixtures can hide data contamination; each run identifies its seed.

## 9. Nonfunctional verification

| Area | Method and acceptance |
|---|---|
| Performance | On defined low-end pilot phone, measure linked scan-to-local-save median under **15 seconds** from at least 30 timed attempts across representative lighting/network conditions; report median, p90, device, OS and sample. Local ledger opening does not await API. This is the SRS pilot target, not a cloud-response promise. |
| Capacity/cost | Load representative shops/customers/history; record Worker requests, D1 rows read/written and storage per journey. Set alert thresholds below current free-tier limits; rehearse the quota response before pilot. Recheck provider terms at launch. |
| Accessibility | Manual TalkBack journey for sign-in, QR, scan, amount, status, dispute and export; automated semantics checks; inspect tap targets and text scaling. Debt direction and sync state must be clear without color. |
| Localization | English/Hindi speaker review of balance polarity, payment wording, correction/dispute, Pending and error messages. Check ₹ formatting, date format, truncation and mixed-script layouts. |
| Security/privacy | Execute [SEC-01–20](SECURITY-REQUIREMENTS.md) verification, including altered Google tokens, cross-tenant routes, QR enumeration, secret scan, release manifest, redacted telemetry and export injection. |
| Recovery | Apply migrations from previous schemas on representative data; restore encrypted D1 backup into isolated staging; compare IDs, entry counts, receipts, foreign keys and balances. No real-user release before pass. |
| Reliability | App kill/restart, OS process death, network flapping, token expiry, clock skew, long Pending queue and account switch; no silent entry loss or duplicate cloud effect. |

Performance and quota results must include actual build, data volume and environment. A test on a fast emulator with empty history cannot prove a low-end shop-phone target or free-tier viability.

## 10. Entry, exit and defect policy

**Test-cycle entry:** requirements and expected behavior reviewed; build and migration version identified; test environment healthy; synthetic seed ready; necessary fault controls available; no known blocker that invalidates the run. Mark unavailable features **Not tested**, not Failed or Passed.

**Test-cycle exit:** planned cases for that phase executed or explicitly deferred with reason; failures linked to defects; regressions rerun after fixes; evidence attached to the phase packet. Required gates cannot be waived by a passing aggregate percentage.

| Severity | Definition and examples | Release treatment |
|---|---|---|
| **P0 Critical** | Cross-tenant data leak, wrong balance/duplicate charge, lost accepted or locally saved entry without warning, hardcoded production secret, irrecoverable backup failure | Stop pilot/release; fix and rerun full affected regression. |
| **P1 High** | Known customer cannot transact reliably, sync stuck without recovery, customer sees misleading status, broken account isolation, export totals wrong, mandatory privacy path absent | Block public launch; pilot only if no real data risk and product/security owners explicitly accept a contained workaround. |
| **P2 Medium** | Noncritical workflow error with a safe workaround, localized copy/format issue, limited device-specific UI defect | May defer with owner, impact, workaround and target release; retest before closure. |
| **P3 Low** | Cosmetic issue without debt-direction, accessibility or trust impact | Track for later release. |

Any issue that changes money, authorization, idempotency or recovery claims is at least P1 and commonly P0. Defect records include build/environment, reproducible steps, expected/actual result, synthetic IDs, request ID, sanitized evidence, requirement IDs, severity and owner. A fix closes only after reproduction fails and affected tests pass; do not close on code review alone.

## 11. Evidence, reporting and approval

Store the following for each test run: run ID/date, tester, build hash, Worker version, D1 migration number, device/OS/locale, test-data seed, case IDs, result, defect links and sanitized logs/screenshots. A phase-gate packet includes the requirement traceability matrix, pass/fail/not-tested counts, P0/P1 status, D1 reconciliation output, security findings, performance/quota measurements and unresolved decisions. No actual customer ledger content belongs in routine test artifacts.

The Flutter and Worker engineers own automated suites and repair. QA verifies independent behavior and device journeys. A security reviewer inspects identity, authorization, secrets and data lifecycle. Operations owns backup/restore and quota incident evidence. Product owner accepts phase results and decides launch/hold/revise. Public deployment or distribution is a separate decision after the packet is reviewable.

## 12. Risks, dependencies and next document

This plan depends on phase-0 choices for supported Android devices, package/runtime versions, input caps and environments; phase-3 choices for overdue allocation, export Pending behavior and retention/deletion policy; and a working backup destination before real users. Record an unresolved choice as a **blocked test condition** for its affected feature, not as an implicit pass. If pilot research changes the QR-first product scope, update BRD/PRD/SRS, then revise this plan and its test cases.

The next [Test Cases / QA Checklist](TEST-CASES-QA-CHECKLIST.md) will turn this strategy into executable cases with IDs, prerequisites, steps, expected results and traceability. Before implementation, translate the planned CI commands and environment setup in [Coding Standards](CODING-STANDARDS-DEVELOPMENT-GUIDELINES.md) into repository scripts; until then, this plan records intent rather than completed test evidence.


### D11 local ledger/outbox checkpoint (2 October 2026)

D11 verification uses real host SQLite for rollback, idempotent local replay, concurrent payments, complete-cache reconciliation, account locking and v1→v2 migration. A separate Flutter process commits a synthetic command, signals its PID and is SIGKILLed without closing SQLite; reopening verifies original UUID/body, Pending entry, balance and foreign keys. Widget tests use SQLite FFI without a separate isolate to work with Flutter simulated time; production storage is unchanged. Android airplane-mode/force-stop behavior and offline cold-start policy remain explicit device/D12 gates.
