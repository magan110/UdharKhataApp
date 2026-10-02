# Udhaar Khata — Test Cases / QA Checklist

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [SRS](SRS.md) · [Use cases and stories](USE-CASES-USER-STORIES.md) · [Test plan](TEST-PLAN.md) · [Security requirements](SECURITY-REQUIREMENTS.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Release:** Android v1  
**Status:** Planned release cases; local D01?D03 evidence is in implementation progress, and the release checkboxes remain unverified  
**Baseline:** [Test Plan](TEST-PLAN.md) · [SRS](SRS.md) · [API Specification](API-SPECIFICATION.md) · [Security Requirements](SECURITY-REQUIREMENTS.md)

## 1. How to run and record results

Use these case IDs in CI, manual run sheets and defects. Every run records **Pass / Fail / Blocked / Not run**, build hash, Worker deployment, D1 migration, Android device/OS, locale, test-data seed, tester, date, sanitized evidence and defect ID. “Blocked” means the prerequisite or approved product decision is absent; it is never counted as Pass. A case passes only when **all** expected observations in its row are true. Run against staging and synthetic data unless a phase-4 pilot explicitly requires consented real data. Never attach Google tokens, real names, QR IDs, notes or financial statements to routine bug reports.

Unless a case overrides it, the fixture has owner **O1** with shop **S1**, owner **O2** with shop **S2**, customer **C1** linked to both, customer **C2** linked only to S1, and unlinked customer **C3**. The owner and customer devices have separate authenticated app sessions. Reset or version the fixture between destructive cases. Use the independent D1 reconciliation query from the [Database Design](DATABASE-DESIGN-ERD.md): for each link, committed entry effects sum to the stored balance. A server result means a D1-acknowledged result; a local Pending item is not server posted.

Test levels: **A** API/Worker, **D** D1 integration, **L** local SQLite, **M** Android manual/device, **W** widget, **I** inspection, **O** operational drill. The next table rows use compact procedures; testers should capture the actual response/request IDs and relevant row counts with each run. Do not use production fault injection or delete live user data.

## 2. Identity, sessions and shop foundation

| ID / level | Setup and steps | Expected result | Trace |
|---|---|---|---|
| **TC-001 A/M** | On clean device, sign in once as new O1, sign out, sign in again with same Google account. Repeat for new C1. | Stable internal user ID and role on return; owner/customer routes differ; no duplicate account. | F-001, F-002, SEC-01, SEC-02 |
| **TC-002 A** | Send valid Google ID token, then variants with altered signature, wrong issuer, wrong audience, expired token and empty subject. | Only valid token issues an app session; others fail without creating user/session rows or exposing token. | F-002, N-001, SEC-01 |
| **TC-003 A/D** | Change C1 Google display name/email while keeping same `sub`; attempt to register O1's subject with customer role. | Identity and ledgers remain attached to same internal ID; role switch is denied. | D-003, SEC-02 |
| **TC-004 A/M** | O1 creates shop with nonblank name; retry; submit blank name; O2 creates separate shop. | O1 has one shop; repeat returns owned shop or defined conflict; blank rejected; O2 cannot access S1. | F-003, N-001, SEC-05 |
| **TC-005 A** | Rotate refresh token, replay old refresh, expire access token, logout, then call protected ledger route; inject lost refresh response. | Old token denied; expired/revoked access denied; app can reauthenticate without deleting Pending outbox. | F-001, SEC-03, SEC-04 |
| **TC-006 M/L** | O1 saves Pending entry; sign out and sign in as O2 on same device; inspect home, SQLite namespace and secure storage; return as O1. | O2 sees no O1 cache/credentials; Pending count was shown before switch; O1 item remains recoverable. | F-005, N-003, SEC-13, SEC-14 |

## 3. QR, new customer and repeat visit

| ID / level | Setup and steps | Expected result | Trace |
|---|---|---|---|
| **TC-007 M/I** | Register C3 online, display QR, decode its bytes, then open cached QR in airplane mode. | Payload is supported version plus random public lookup ID only; no name, email, phone, balance or credential; cached QR displays offline. | F-006, D-004, SEC-07 |
| **TC-008 A/M** | Rotate C3 QR online; scan old and new IDs as O1 before any link; lose rotation HTTP response and fetch current QR. | Old ID cannot create a link and shows revoked state; new ID resolves; GET recovers one current active QR. | F-007, F-012, SEC-07 |
| **TC-009 M/A** | O1 scans valid unlinked C3 QR online; stop at preview, then tap Add customer. | Preview shows minimum display label and explicit Add action; scan alone creates no link/entry; confirmation creates one S1–C3 link. | F-008, F-013, SEC-06 |
| **TC-010 A/D** | Reset C3 to unlinked; concurrently send same link command twice, then another operation ID for same S1/C3 pair; rescan QR. | One link row and one zero balance; same-ID replay returns original; different-ID duplicate returns existing link. | F-009, D-001, SEC-08 |
| **TC-011 M** | Scan linked C1 QR online, then turn on airplane mode and rescan from verified cache. | Both scans open C1 credit form with correct shop/customer; no new link and no automatic financial entry. | F-010, F-013, SEC-06 |
| **TC-012 M/L** | In airplane mode on O1 device, scan never-seen C3 QR and attempt Add/credit. | Internet-needed message; no placeholder link, outbox command or ledger entry. | F-011, SEC-07 |
| **TC-013 M/A** | Scan unreadable code, wrong URI scheme, unsupported version, oversized payload and revoked ID; deny camera permission and retry. | Distinct actionable invalid/version/revoked/permission states; no app crash, external link launch or ledger mutation. | F-012, SEC-10 |
| **TC-014 A/I** | From O1 run repeated QR lookups with valid/invalid IDs through rate-limit boundary; inspect responses and logs. | Minimal customer label only for authorized lookup; throttling activates without leaking identity/QR value in logs; shared-network false positives reviewed. | N-009, SEC-07, SEC-15, SEC-19 |

## 4. Ledger, balance, correction and authorization

| ID / level | Setup and steps | Expected result | Trace |
|---|---|---|---|
| **TC-015 M/A/D** | Continue from TC-009 with newly linked C3; O1 reviews identity/₹500 amount, submits credit; sync C3 app. | One `+50000` paise entry, one operation receipt, ₹500 owed in owner/customer synced views; scan without Submit would leave zero. | F-013, F-014, F-017–019, V-01 |
| **TC-016 A/W** | Submit 1 paise; then zero, negative, decimal JSON, noninteger, unsafe integer, one above approved max, invalid due date and oversized note. | 1 paise accepted; invalid variants rejected before D1 effect with field-level errors; no floating-point rounding. | F-014, F-016, SEC-10 |
| **TC-017 M/A/D** | Start at ₹500 owed; O1 records ₹200 Cash, then ₹300 UPI on the same ledger; inspect customer view after each. | Balances are ₹300 then ₹0; methods say manually recorded and do not imply bank verification. | F-015, F-017, V-03 |
| **TC-018 A/D** | Against ₹300 owed, try ₹301, ₹0 and negative payment; concurrently submit two ₹200 payments against ₹300. | Invalid/overdraw requests fail; at most one concurrent ₹200 commits; D1 balance remains nonnegative and reconciles. | F-015–017, SEC-09 |
| **TC-019 A/D** | Post same credit twice with same operation ID/body; simulate D1 commit followed by lost HTTP response, retry. | One ledger effect and receipt; replay returns original entry ID and original committed balance/version, not a new current balance. | F-019, F-025–026, SEC-08, V-04 |
| **TC-020 A/D** | Reuse accepted operation ID with changed amount/customer/kind; issue two simultaneous requests with same ID. | Changed body gives `IDEMPOTENCY_CONFLICT`; same body yields one committed effect; receipt hash and row count stable. | F-019, SEC-08 |
| **TC-021 M/A/D** | Correct original ₹500 credit to ₹450 with reason and expected revision 0; sync both views. | Original +₹500 remains, correction −₹50 appears, final owed ₹450, creator/time/reason retained. | F-018, F-020–021, D-002, V-07 |
| **TC-022 A/D** | Correct same original from ₹450 to ₹400 at revision 1; concurrently send another revision-1 correction; try correction of another link's entry. | First delta is −₹50, stale correction conflicts, cross-link target denied; history and projection reconcile. | F-020, D-002, SEC-09 |
| **TC-023 A/D** | Cancel original credit with target zero when no payments; then try reducing a paid credit below already paid total; attempt direct `PATCH`/`DELETE` of posted row. | Valid cancellation is appended as correction; negative-balance correction rejected; no ordinary route overwrites/deletes posted entry. | F-020–021, SEC-09 |
| **TC-024 A/M** | O1 requests S2/customer B rows and O2 requests S1; C1 changes route ID to C2 entry; C3 requests C1 history. | Cross-owner, cross-customer and unlinked access denied with no private amount/name in response; authorized C1 may see only own S1/S2 ledgers. | F-004, F-022, N-001, SEC-05, V-06 |
| **TC-025 A/D** | Seed entries with same occurred time and different server sequence; page owner and customer history; reconcile all link balances. | Stable ordering, no duplicate/skipped entry, each view has correct signed effect and same balance after same server version. | F-017–018, F-022, D-002 |
| **TC-026 M/A** | Add due date to credit; make partial payment across multiple dated credits while no allocation rule is approved. | Due date displays on its entry; aggregate overdue amount is absent until policy and allocation tests are approved. | F-023 |

## 5. Offline outbox, sync, conflicts and recovery

| ID / level | Setup and steps | Expected result | Trace |
|---|---|---|---|
| **TC-027 M/L** | For previously linked C1, enable airplane mode, scan QR, save ₹150 credit, kill/restart app. | Local entry/outbox survive, local provisional balance updates immediately, status says Waiting to sync; customer server view unchanged. | F-024–025, F-027, N-004, V-02 |
| **TC-028 L** | Inject SQLite failure after entry insert but before outbox commit, then failure after outbox insert; restart. | Whole Submit transaction rolls back; no orphan local entry/outbox and no false saved confirmation. | F-024–025, N-004 |
| **TC-029 M/A/D** | Resume network after TC-027, inject timeout before send and lost response after D1 commit, retry original payload. | Exactly one +₹150 server effect, original operation ID retained, local state transitions to Synced, customer sees entry after refresh. | F-026–027, F-019, N-004, SEC-08 |
| **TC-030 M/A** | While offline queue payment based on stale ₹300 local balance; change server balance so payment now exceeds owed; reconnect. | Server returns BALANCE_CONFLICT; item remains visible Needs attention with resolution path and is not counted as synced balance. | F-015, F-026–027, F-030, SEC-09 |
| **TC-031 M/A** | Queue valid write offline, then revoke shop ownership/link in staging before reconnect. | Worker rechecks permission and rejects; full local record remains Needs attention; no unauthorized D1 row or blind retry loop. | F-026, F-030, SEC-05 |
| **TC-032 M/A** | Simulate Worker/D1 503, 429 with Retry-After and capacity outage while existing C1 linked; scan new C3 QR during outage. | C1 write stays Pending with honest warning/backoff; new link unavailable; no data dropped or cloud-backup claim. | F-025, F-027, N-010, N-012, SEC-15, V-10 |
| **TC-033 L/A** | Pull two ledger pages, crash between cache insert and cursor advance; restart/pull again. | Atomic cache+cursor prevents skipped rows; upsert does not duplicate entries; scope cannot be reused for other account. | F-025–028, N-004 |
| **TC-034 M** | Customer C1 syncs, then goes offline while O1 posts a new server entry. | C1 sees last synced history and time, no unseen new entry or claim of current balance; refresh later converges. | F-028 |
| **TC-035 M/A** | O1 has one Synced and one phone-only Pending entry; sign in on replacement phone. | Only Synced item restores from D1; UI explains old phone Pending cannot be recovered from cloud. | F-029, SEC-14, V-09 |
| **TC-036 M/L** | Force permanent validation rejection during sync, then app restart and attempted sign-out. | Full rejected command remains inspectable/locally exportable, status Needs attention, reason/support path and Pending warning shown; no silent delete or post. | F-027, F-030, SEC-14 |
| **TC-037 A/M** | Pull ledger with valid cursor, then alter its scope/signature and try it as another account; rotate cursor key in staging. | Altered/cross-account cursor rejected; reset fetches only authorized rows and preserves local outbox. | F-022, F-028, SEC-05, SEC-10 |

## 6. Disputes, reminders, exports and data requests

| ID / level | Setup and steps | Expected result | Trace |
|---|---|---|---|
| **TC-038 M/A** | C1 files reasoned dispute for own acknowledged entry, retries while open; C2 tries C1 entry; C1 tries offline submit. | C1 sees one open dispute; duplicate returns it; C2 denied; offline cannot claim submitted. Balance unchanged. | F-031, SEC-05 |
| **TC-039 M/A/D** | O1 views and resolves C1 dispute with note; C1 refreshes; compare balance before/after. | Resolved status/note visible to authorized parties; balance unchanged until a separate correction. | F-032, D-002, V-08 |
| **TC-040 M** | O1 opens reminder preview for C1, checks shop/customer/balance, cancels; repeat and choose share; repeat offline with stale data. | Cancel sends nothing; Android share menu opens only after owner choice; stale/provisional balance clearly labeled; no auto-message. | F-033 |
| **TC-041 A/M/D** | Export period with opening ₹500, ₹200 payment, ₹50 correction; inspect CSV and PDF line items and totals. | Opening + signed entries = closing independently; correction history shown; correct shop/customer/period; no unlabeled Pending row. | F-034, D-002, V-11 |
| **TC-042 A/M** | Place formula-like text in note/nickname, export CSV/PDF; request another shop's export; inspect temp files and response headers. | Spreadsheet formula is inert in user-facing CSV, PDF safely renders text; cross-shop export denied; no-store and private temporary storage. | F-034, SEC-05, SEC-11–13 |
| **TC-043 M/A** | O1 requests shop export/deletion; C1 requests access removal/account deletion; C2 requests C1 shop action. Check status tracking. | Only authorized requests created, visible status/ID returned, no immediate cascade deleting posted ledger; C2 denied. | F-035, SEC-05, SEC-20 |
| **TC-044 M/D/I** | Complete C1 access-removal workflow under approved policy, inspect O1 historical ledger, then try C1 view/re-link. | Owner history remains; C1 access and re-link behavior exactly match published policy; any retained-data removal follows approved timeline. | F-036, D-006, SEC-20 |
| **TC-045 W/M** | Switch English/Hindi across owner/customer onboarding, balance, Pending, errors, reminder and dispute; run TalkBack and text scaling. | Debt direction and state readable without color, correct ₹/date formatting, translated critical paths, accessible controls with no blocking clipping. | F-037, N-007–008 |

## 7. Security, operations, compatibility and performance

| ID / level | Setup and steps | Expected result | Trace |
|---|---|---|---|
| **TC-046 A/I** | Fuzz JSON types, huge body, unknown mutation fields, malformed QR/UUID/date/cursor; inject SQL characters in all text/IDs. | Stable 4xx errors with no DB change, SQL error, stack trace or cross-tenant data; prepared statements used. | N-001, SEC-10–11 |
| **TC-047 I/M** | Inspect release APK/manifest/network trace, secure-storage records, Android Auto Backup/device transfer rules and app-private files. | No embedded secret, HTTP cleartext, contacts/location permission or token in SQLite/backup; local ledger/outbox excluded from backup per approved design. | N-002–003, SEC-12–14, SEC-16 |
| **TC-048 I/A** | Send synthetic sentinel token, QR, name, note and amount through success/error/crash paths; inspect logs, analytics and API error bodies. | No sensitive sentinel in routine telemetry; request ID, route template, status and usage present; no stack trace in response. | D-004, N-009, SEC-19 |
| **TC-049 D/O** | Apply migrations to empty and previous-version staging data, run `foreign_key_check`, reconcile all links/receipts; restore encrypted backup into isolated environment. | Existing IDs/history and operation receipts retained; FK check clean; restored balances/entry counts match snapshot; retry returns original result. | D-005–006, N-005, SEC-17 |
| **TC-050 O/I** | Review named operator roles/MFA, staging-production bindings and secrets, deployment audit, backup key access and privacy policy. | Least privilege and separation documented; sensitive maintenance audited; policy matches actual data/request handling. | SEC-16–18, SEC-20 |
| **TC-051 A/O** | Load representative link/history volume; exercise QR, owner home, sync and export; force threshold/429/quota condition in staging. | D1 row reads/writes/storage and Worker usage recorded; alerts fire before configured limits; 429/backoff/incident route works without losing Pending entries. | N-009–010, N-012, SEC-15 |
| **TC-052 M** | On approved low-end phone(s), time at least 30 linked scan-to-local-save attempts in representative conditions; open cached ledger offline. | Median <15 s; p90 and sample/device recorded; local ledger opens without waiting for API. | N-006 |
| **TC-053 M/I** | Execute core flows on the approved minimum Android version and device matrix, including camera denial, background/foreground, intermittent network and release signing. | No unsupported-device blocker; sign-in, camera, secure storage and sync behave as specified; matrix evidence attached. | N-011 |

## 8. Requirement coverage and mandatory journey map

The table gives the minimum planned coverage; the run record must add status and evidence per requirement. `F-`/`D-`/`N-` abbreviate `SRS-F-`/`SRS-D-`/`SRS-N-`. The security requirements `SEC-01–20` are covered across TC-001–053 and require the dedicated pre-release review in [Security Requirements](SECURITY-REQUIREMENTS.md#8-required-security-tests-and-release-gates).

| Requirement range | Primary case IDs |
|---|---|
| F-001–005 | TC-001–006, TC-024 |
| F-006–013 | TC-007–014 |
| F-014–023 | TC-015–026 |
| F-024–030 | TC-027–037 |
| F-031–037 | TC-038–045 |
| D-001–006 | TC-003, TC-010, TC-021–025, TC-041, TC-044, TC-047–049 |
| N-001–012 | TC-002, TC-004–006, TC-014, TC-024, TC-027–036, TC-045–053 |

| SRS journey | Primary case |
|---|---|
| V-01 New customer | TC-009 + TC-015 |
| V-02 Repeat offline | TC-011 + TC-027 + TC-029 |
| V-03 Partial payment | TC-017 |
| V-04 Response loss | TC-019 + TC-029 |
| V-05 Unknown QR offline | TC-012 |
| V-06 Privacy | TC-024 |
| V-07 Correction | TC-021 |
| V-08 Dispute | TC-038 + TC-039 |
| V-09 Device loss | TC-035 |
| V-10 Quota outage | TC-032 + TC-051 |
| V-11 Export | TC-041 |

## 9. Phase exit checklist

Mark each item **Pass / Fail / Blocked / Not run**, with evidence link and approver. No check mark is implied by its appearance here.

- [ ] Phase-0 identity, role, account isolation and migration cases pass; supported devices/input bounds chosen.
- [ ] Phase-1 new/repeat QR, exact money, duplicate and cross-tenant cases pass on Worker/D1 and device.
- [ ] Phase-2 offline outbox, lost response, conflicts, customer cache, corrections, disputes and recovery cases pass.
- [ ] Phase-3 statement reconciliation, sharing, Hindi/English, accessibility, data controls and backup restore pass.
- [ ] Phase-4 performance/device matrix, quota/alerts, security review and full regression pass.
- [ ] No open P0/P1 defect affecting balances, privacy, idempotency, local durability, recovery or required user flows.
- [ ] Every SRS/SEC requirement has a linked passed case, inspection or approved decision; no required item is merely “not failed.”
- [ ] Privacy/retention policy, backup owner/destination, export Pending behavior and due-date allocation decisions are closed where their feature depends on them.
- [ ] Product owner, QA/security reviewer and operations owner sign the launch/hold packet based on actual run evidence.

The [Test Plan](TEST-PLAN.md#10-entry-exit-and-defect-policy) defines severity and evidence rules. These cases should be automated where practical, but manual Android and operational checks remain necessary. A public release is not ready merely because this checklist exists; it must be executed against a traceable release candidate.

### D06 implementation checkpoint

Customer QR uses exactly `udhaar://customer/v1/{publicId}` with a 256-bit random lowercase hex lookup ID and no personal, financial or credential fields. Own-QR read and online rotation enforce the customer session. Rotation revokes the old mapping atomically, preserves internal links and permits at most three attempts per customer per ten minutes. The customer screen renders a readable QR with account label and explains that it does not authorize payment. Account-specific secure-storage cache labels saved codes as unverified; uncertain rotation persists a recovery marker and hides the old code until online confirmation. Offline presentation works in an already verified open session, even if an attempted auth renewal fails: credentials are discarded and the account database is locked, while only the cached public QR remains with a Sign in again action. This confers no cloud or ledger authorization. Failed rotations retain an explicit failure notice after recovering the current QR. Full offline session restoration after cold startup remains D12. D07 owner resolution/linking and physical-device QR scanning remain separate gates. Synthetic authorization/rotation/cache/UI and independent rendered-image decoding evidence is recorded in implementation progress.


### D07 local verification scope

Synthetic API/D1 tests cover TC-009/010/012/013 portions: read-only resolution, minimal responses, explicit link, same/different-ID concurrency, conflict, revoked IDs and receipt recovery after rotation, body/shop/account tampering, removed/deleted relationships, commit-time QR revocation, rollback and hashed owner/network lookup limits. Flutter tests cover exact QR parsing, permission denial/retry, no Add before identity, no POST before confirmation, durable same-body retry after recreation, storage failure before POST, invalid response retention, offline internet-needed, returning link opening, duplicate taps and disposal before delayed identity. Physical-device first/repeat scan, copied/rotated QR, permission settings return and link-list refresh remain D07 deployment/device gates. TC-011 offline cached owner entry stays with offline work.

### D08 online credit implementation contract (2026-10-01)

Approved pilot limits v1: positive credit ₹0.01–₹1,00,000.00 (1–10,000,000 integer paise), optional trimmed note up to 500 UTF-16 code units, valid optional YYYY-MM-DD due date, financial JSON body at most 4,096 bytes, and existing first-100 list ceiling. General JSON/auth bodies retain the 65,536-byte ceiling. The Worker validates strict credit fields and canonical UUID v4 operation identity; unknown/forged effect fields and payment/correction variants are rejected in D08. A first online command accepts device occurrence time from 24 hours before server time to 5 minutes ahead. Receipt replay precedes this mutable clock check. Payments, corrections, full history/pagination and offline local ledger remain their later phases.

The owner opens a linked customer, enters amount/note/date, reviews customer identity and the explicit Customer owes you direction, then confirms. Review has no financial effect. The app durably saves an account/shop/link-specific command before POST and never generates a replacement ID after uncertainty. Reopening the form recovers that body with Check same credit; a response must match shop, link, type, amount/effect, note/date, occurrence time and sequence before acknowledgement. Unverified responses, storage failures, auth/network failure and rejected requests retain the saved record for recovery; it is not silently discarded. This online recovery record is not the D11 offline ledger/outbox, and does not provisionally change the visible balance.

The Worker uses the existing immutable ledger triggers and atomic entry-plus-receipt batch; live authorization is rechecked at commit and replay requires current access. Receipt retries return the original committed balance/version even after later entries, explicitly labeled as the balance when this credit was recorded. Owner link/list reads refresh the current balance. Customer My shops receives its own active link balances/versions from the same profile query and can refresh them. New minimal balance reads authorize the entire current snapshot in one SQL query; no history page or aggregate overdue total is inferred. No new migration is needed.

### D09 local verification checkpoint (2026-10-01)

Automated D1/HTTP payment coverage proves ₹500 credit − ₹200 Cash = ₹300 in both authorized reads and independent entry sums; full UPI payment reaches zero; zero/negative/fractional/oversized/forged bodies are rejected; concurrent payments cannot overdraw; duplicate and lost-response replay produce one effect and original receipt; changed method conflicts; cross-shop/customer/removed access is denied; receipt failure rolls back projections. Mobile tests cover review without mutation, received/manual wording, Cash/UPI selection, double-tap guard, restart/body identity, account isolation, credit/payment replacement prevention, and explicit rejection correction retaining the original body. Phone validation, stable cloud artifact and staging deployment remain separate gates in progress.

### D10 online history checkpoint (2 October 2026)

D10 local API tests cover ₹500 credit/₹200 payment/retry → ₹300 history for both roles, independent effects replay, new entries between pages, >100-customer traversal, list insertion exclusion, shared customer in two shops, account/route/link cursor reuse, tampering/expiry/key rotation, denied/deleted/removed access and invalid queries. Flutter tests cover dated entry cards/notes/due dates, both role routes, totals/Load more, empty versus failure, page retry, changed snapshot rejection, permission-loss hiding and stale in-flight account replacement. Phone acceptance still must exercise these screens on the approved deployed/stable-key APK; local tests do not supply device evidence.


### D11 local ledger/outbox checkpoint (2 October 2026)

Automated D11 scenarios cover inert review, double-tap local confirmation, no new-command HTTP, Pending-only-device wording, local overpayment/concurrent-payment rollback, outbox insertion failure, queue/body persistence after reopen and forced process termination, account separation, active-link/shop/role guards, complete paged history reconciliation, denied access preserving pending money, cache-size bound, and v1 migration retaining original outbox bytes. Owner saved history labels Synced and Pending separately; customer acknowledged-only reads keep prior regressions. Phone airplane-mode/force-stop and D12 sync fault cases remain unchecked until their own evidence.
