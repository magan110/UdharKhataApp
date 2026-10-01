# Udhaar Khata — Software Requirements Specification

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [Scope](SCOPE.md) · [PRD](PRD.md) · [SES](SES.md) · [Test plan](TEST-PLAN.md) · [QA cases](TEST-CASES-QA-CHECKLIST.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Release:** Android v1  
**Status:** Requirements baseline for phased implementation; unresolved items are listed in section 11  
**Related documents:** [Product Vision](PRODUCT-VISION.md) · [BRD](BRD.md) · [PRD](PRD.md) · [SES](SES.md)

## 1. Purpose and scope

This SRS states **what the software shall do** and how each requirement can be verified. The [PRD](PRD.md) describes the user experience and release priorities; the [SES](SES.md) describes architecture, database and API design. The first public release is a free Flutter Android app using Google sign-in, local storage for offline operation, and a Cloudflare Worker with D1 for cloud records.

The system supports one owner account and one shop per owner. Customers can be linked to multiple shops and can view only their own ledger in each shop. A customer presents a personal QR code; a shopkeeper scans it to find or add the customer and then records credit. The shopkeeper alone records credit, payments and corrections.

**Out of scope for v1:** supplier ledgers, staff, multiple shops per owner, bill photos, automatic messaging, verified payment collection, refunds and advances, inventory, invoicing, iOS/web, and currencies other than INR.

## 2. Conventions and definitions

| Term | Meaning |
|---|---|
| **Shall** | Mandatory first-release requirement unless explicitly marked as a phase-only gate. |
| **Shop/customer link** | The association that permits an owner to maintain a customer's ledger for one shop and the customer to see that ledger. |
| **Credit** | Goods/services given on credit; increases the amount the customer owes. |
| **Payment received** | Amount manually recorded by the owner; decreases the amount owed. It is not independently verified by a bank. |
| **Correction** | A new entry that reverses or adjusts a prior entry while preserving history. |
| **Pending** | Saved on the owner's device but not yet acknowledged by the server. |
| **Synced** | Acknowledged and committed by the server. |
| **Needs attention** | A pending operation that cannot currently sync without user action or later retry. |
| **Public QR ID** | Random account lookup value displayed as a QR; neither a secret nor authorization. |
| **Balance owed** | Sum of credit effects, correction effects and payment effects for one shop/customer ledger, in integer paise. |

Each requirement has a stable ID. Verification methods: **T** automated or manual test, **I** inspection, **D** demonstration, **A** analysis or reconciliation. Requirement text and acceptance conditions take precedence over implementation examples.

## 3. Actors and operating context

| Actor | Allowed scope |
|---|---|
| Owner | Own shop, linked customers, their entries and disputes, shop exports and deletion requests. |
| Customer | Own public QR and own ledgers in linked shops; own disputes and account/access requests. |
| Operator | Restricted operational access through separate procedures; not a normal app role. |

The Android app may be offline for extended periods. First sign-in/registration, first-time customer linking, cloud sync, new-device recovery and dispute submission need internet. Previously linked customers can be identified from a verified local cache and charged offline. Customer history can be read offline as a dated cached view.

## 4. Functional requirements

### 4.1 Sign-in and account setup

| ID | Requirement | Verification |
|---|---|---|
| SRS-F-001 | The system shall let an owner or customer sign in with Google and create or resume the corresponding account. | T: first and returning sign-in; cancelled/expired sign-in paths. |
| SRS-F-002 | The server shall verify the Google identity before issuing an app session and shall identify users by a stable Google subject, not by editable email or display name. | T/I: altered, expired, wrong-audience and valid identity tests. |
| SRS-F-003 | The system shall allow one active shop per owner in v1 and require a nonblank shop name. | T: create one shop; repeat create rejected or returns existing shop. |
| SRS-F-004 | The system shall permit a customer to have separate ledger links to multiple shops while preventing an owner from accessing another shop's customer data. | T: two shops sharing a customer; cross-shop access denied. |
| SRS-F-005 | The app shall isolate cached data and credentials when Google accounts change on one device. | T: sign out of account A, sign in as B, inspect all screens/local data. |

### 4.2 Customer QR and linking

| ID | Requirement | Verification |
|---|---|---|
| SRS-F-006 | After initial online registration, the customer app shall show a versioned QR containing only a random public lookup identifier and format information, with no name, email, phone, balance or credential. | I/T: decode QR and inspect payload; open cached QR offline. |
| SRS-F-007 | The customer shall be able to rotate/revoke the active QR identifier online; a revoked identifier shall not create a new shop/customer link. | T: rotate; attempt old and new online scans. |
| SRS-F-008 | An owner scan of a valid, unlinked customer QR while online shall show the customer's display label and offer **Add customer** before creating the link. | D/T: first visit flow. |
| SRS-F-009 | Adding a customer shall create at most one link for that shop/customer pair; repeated requests and scans shall resolve to the existing link. | T: repeated and concurrent link requests. |
| SRS-F-010 | Scanning a QR for a customer already linked to the shop shall open that customer's credit entry flow, including when the link is in the local cache and the device is offline. | D/T: online and airplane-mode repeat visit. |
| SRS-F-011 | Scanning an unknown QR while offline shall show that internet is needed to add the customer and shall not create an unverified link or entry. | T: unknown QR in airplane mode. |
| SRS-F-012 | Invalid, unreadable, unsupported-version and revoked QR codes shall produce distinct actionable errors; camera permission denial shall offer a retry path. | T: malformed codes, revoked code, denied camera permission. |
| SRS-F-013 | QR scanning alone shall never create a credit or payment entry. The owner shall see the customer's identity and amount before a transaction is submitted. | D/T: scan without submission leaves ledger unchanged. |

### 4.3 Ledger and balances

| ID | Requirement | Verification |
|---|---|---|
| SRS-F-014 | The owner shall be able to post a credit entry for a linked customer with a positive INR amount, optional note and optional due date. | T: valid/invalid amount, note/date and customer cases. |
| SRS-F-015 | The owner shall be able to record a positive payment received, marked Cash or UPI as an owner-entered method, no greater than the currently recorded amount owed. | T: partial, full, zero, negative and overpayment cases. |
| SRS-F-016 | The system shall store and calculate all monetary values in integer paise, and shall display INR to two decimal places. | T: arithmetic, large permitted amounts, locale formatting. |
| SRS-F-017 | For a ledger, balance owed shall equal the sum of credit effects plus signed correction effects minus payment effects. Both parties shall see the same result after syncing the same server version. | A/T: independent entry-sum reconciliation across owner/customer views. |
| SRS-F-018 | Each posted entry shall retain its type, magnitude, creator, applicable customer/shop, creation time, and unique operation identity. History shall show the effective amount and date in a stable order. | I/T: stored and displayed entry fields, tie-order tests. |
| SRS-F-019 | A repeated submit or network retry with the same operation identity shall create no additional ledger entry and shall return the original committed result. | T: double tap, response loss and concurrent retry. |
| SRS-F-020 | The owner shall be able to correct an entry through a new linked correction with a reason; the original entry shall remain visible and unchanged. | T: correction and cancellation flows; audit trail inspection. |
| SRS-F-021 | An ordinary user shall not directly delete or silently overwrite a posted ledger entry. | T/I: API authorization and UI inspection. |
| SRS-F-022 | The owner shall see a shop summary, linked customer list, per-customer balance and dated ledger. The customer shall see a list of linked shops and only their own balance/history in each. | T: role matrix, cross-customer and cross-shop tests. |
| SRS-F-023 | The system shall show an optional due date on an entry. It shall show an **overdue amount** only after a deterministic payment-allocation rule is specified and verified. | T/A: partial payment against multiple dated credits. |

### 4.4 Offline storage, sync and recovery

| ID | Requirement | Verification |
|---|---|---|
| SRS-F-024 | For a previously linked customer, the owner app shall save a valid credit/payment entry locally without internet and show the updated local ledger immediately. | T: airplane mode, app restart, local balance. |
| SRS-F-025 | A locally saved unsynced entry shall remain in a durable pending queue across app restart and transient network failure until acknowledged or explicitly resolved. | T: kill/restart app while pending; simulated network errors. |
| SRS-F-026 | When connectivity returns, the app shall retry pending operations using their original operation identities; the server shall recheck ownership and link permissions. | T: retry, revoked permission and duplicate prevention. |
| SRS-F-027 | Each owner entry shall visibly distinguish **Waiting to sync**, **Synced** and **Needs attention** states. The app shall not describe a pending entry as cloud-backed up. | D/T: online, offline, quota and rejected-operation states. |
| SRS-F-028 | The customer app shall allow viewing its last synced ledgers offline and display the last successful sync time. It shall not imply that unseen owner changes are already included. | T/D: offline customer view and stale-cache label. |
| SRS-F-029 | After sign-in on a replacement phone, the system shall restore server-acknowledged records. It shall explain that pending entries left only on a lost phone are not recoverable from the server. | T/D: restore drill with synced and pending records. |
| SRS-F-030 | A permanent sync rejection shall preserve the local entry for investigation/export and display a reason or support path; it shall not silently drop or post it. | T: permission loss and invalid payload responses. |

### 4.5 Disputes, reminders, exports and data controls

| ID | Requirement | Verification |
|---|---|---|
| SRS-F-031 | A customer shall be able to submit a dispute about an entry in their own ledger while online, with a reason and visible status. | T: own/other customer's entry; offline attempt; status view. |
| SRS-F-032 | The shop owner shall be able to view and resolve that dispute with a note. Filing/resolving a dispute shall not change ledger balance by itself. | T: dispute lifecycle and before/after balance. |
| SRS-F-033 | The owner shall be able to preview a reminder containing shop, customer and current known balance, then choose whether to send it via the Android share menu. The system shall not auto-send reminders in v1. | D/T: preview, cancel, share, offline/stale balance labeling. |
| SRS-F-034 | The owner shall be able to generate a customer PDF statement and CSV export for a selected period with opening balance, dated entries, corrections and closing balance that reconcile to the ledger. | A/T: compare export and independent ledger calculation. |
| SRS-F-035 | The owner shall be able to request a shop data export and account/shop deletion through a tracked workflow. A customer shall be able to remove app access to a shop and request account deletion. | T/D: request, status, authorization and user messaging. |
| SRS-F-036 | Customer access removal shall not silently erase the owner's historical posted ledger. Any later re-linking or removal of retained data shall follow the published privacy/retention policy. | T/I: access removal and retained-ledger behavior. |
| SRS-F-037 | Core UI text, errors, balance labels, sync states and reminder templates shall be available in English and Hindi. | I/D: language switch across critical journeys. |

## 5. Interface requirements

### 5.1 User interface

The app shall provide role-specific navigation for sign-in, owner home, shop setup, scanner, customer-link confirmation, transaction form, owner/customer ledgers, entry detail, disputes, reminders/exports and account settings. Required error and empty states include no customers, no linked shops, offline unknown QR, invalid/revoked QR, camera denied, sign-in failure, sync pending/rejected, cloud unavailable and account access removed. Balance polarity shall be explicit in words, not color alone: **Customer owes you ₹X** for an owner, **You owe [shop] ₹X** for a customer.

### 5.2 External interfaces

| Interface | Required behavior |
|---|---|
| Google identity | Authenticate account online; no Google password handled by Udhaar Khata. |
| Android camera | Scan customer QR after permission; provide permission-denied guidance. |
| Android share sheet | Let owner choose where a reminder or statement is sent; no automatic dispatch. |
| Cloudflare Worker API | Only remote endpoint used by the app for account, ledger and sync operations; all requests authenticated and authorized where applicable. |
| Cloudflare D1 | Server-side authoritative storage of acknowledged records; never accessed directly from the app. |
| Device SQLite | Persist cached account data and pending owner operations for offline use. |

Detailed API paths, schema and token handling are in the [SES](SES.md). This SRS does not mandate a particular Flutter package or Worker framework.

## 6. Data requirements and business constraints

| ID | Requirement | Verification |
|---|---|---|
| SRS-D-001 | Each shop/customer pair shall have a unique relationship and separate ledger from every other shop/customer pair. | T: duplicate link and multi-shop tests. |
| SRS-D-002 | Posted entries and their correction relationships shall preserve a reconstructable balance history. | A/T: replay entries and compare balance/export. |
| SRS-D-003 | User email/display name shall be treated as changeable profile fields, not ownership keys. | T/I: profile change leaves account/ledger ownership intact. |
| SRS-D-004 | QR payloads, application logs and analytics shall exclude credentials, financial values and transaction notes. | I: decode QR; inspect logs/telemetry samples. |
| SRS-D-005 | Production data migrations shall preserve existing posted entries, operation IDs and link relationships or provide a tested recovery path. | T: upgrade from representative prior schema. |
| SRS-D-006 | The system shall retain request and audit data needed to investigate duplicate, correction, dispute and deletion events for the period published in its privacy/retention policy. | I/T: sample audit trail and retention configuration. |

No exact retention duration is specified yet. It must be decided and published before launch after appropriate review. All cloud-acknowledged financial records require an operational backup and tested restore procedure before live public use.

## 7. Nonfunctional requirements

| ID | Quality | Requirement and measurable acceptance |
|---|---|---|
| SRS-N-001 | Security | The Worker shall validate authentication, role, shop ownership and customer relationship on every protected operation. Cross-shop, cross-customer and unlinked-user access tests shall fail closed. |
| SRS-N-002 | Transport/storage | API traffic shall use TLS; session credentials shall use device secure storage; D1 bindings and server credentials shall never ship in the app. Verify release artifact/configuration and network trace. |
| SRS-N-003 | Privacy | The app shall request no contacts permission in v1 and collect only information necessary for accounts, shop identity and ledgers. Inspect Android manifest, onboarding and telemetry. |
| SRS-N-004 | Reliability | Valid local entries shall survive app restart, transient network failure and sync retry without duplication or silent loss. Test with fault injection and restart cycles. |
| SRS-N-005 | Recoverability | Before public release, a documented backup/restore drill shall recover a production-like acknowledged dataset in a separate environment and reconcile entry counts and balances. |
| SRS-N-006 | Performance | In pilot tests on a defined supported low-end Android device, linked scan-to-local-save median shall be under 15 seconds. Local ledger display shall not wait for an API response. Record device and sample details with results. |
| SRS-N-007 | Accessibility | Critical actions shall have screen-reader labels, text equivalents for color/state, readable type and appropriately sized tap targets; check with Android accessibility tools and manual review. |
| SRS-N-008 | Localization | English and Hindi critical paths shall be reviewed by speakers for clarity of debt direction, payment status and errors. Currency and dates shall render consistently. |
| SRS-N-009 | Observability | Operations shall expose request/error rates, sync failures/queue age, D1 reads/writes/storage and Worker usage without logging amounts, notes or identities in analytics. Inspect dashboards with test traffic. |
| SRS-N-010 | Quota behavior | On cloud quota or service errors, the app shall keep previously linked owner writes locally pending, label them clearly, and prevent first-time linking. Test simulated quota failures. |
| SRS-N-011 | Compatibility | Supported Android versions and devices shall be fixed in phase 0 and tested before launch, including camera permission denial and intermittent connectivity. |
| SRS-N-012 | Cost control | The pilot shall have documented alert thresholds and a response plan for D1/Worker free-tier usage before admitting real users. Review configuration and rehearse one quota incident. |

## 8. Core system states and transitions

### Owner entry

`Draft → Local Pending → Server Synced`

`Local Pending → Needs attention → Local Pending` after user action or retry. A draft has no ledger effect. A local pending entry affects the owner's local balance and is visibly provisional. A server synced entry affects the authoritative ledger and becomes visible to the customer after their sync. Failed operations remain inspectable until resolved.

### Shop/customer link

`Unknown → Resolved online → Linked`. Re-scanning `Linked` returns the same relationship. `Unknown` cannot transition to `Linked` offline. A QR can become `Revoked`; revocation prevents new online links, while existing relationships remain tied to the customer account subject to access policy.

### Dispute

`Open → Resolved`. The dispute does not affect the amount owed. The owner may post a separate correction if an entry was wrong; both the dispute and correction remain visible in history.

## 9. Verification scenarios

| Scenario | Steps | Expected result |
|---|---|---|
| V-01 New customer | Customer signs in, presents QR; owner scans online, links and posts ₹500 | One link, one ₹500 credit; both views show ₹500 after sync. |
| V-02 Repeat offline | Owner scans previously linked QR in airplane mode, posts ₹150, restarts app, reconnects | Local pending entry survives; cloud receives one ₹150 entry; customer later sees it. |
| V-03 Partial payment | Starting at ₹500, owner records ₹200 cash | Balance is ₹300 in both synced views; payment is marked manually recorded. |
| V-04 Duplicate response loss | Server commits entry but app misses response and retries same operation | Only one posted entry and one balance effect. |
| V-05 Unknown QR offline | Owner scans new customer's QR without internet | Clear online-needed state; no unverified link or charge. |
| V-06 Privacy | Customer A requests customer B's ledger; owner A requests owner B's shop | Both denied; no private details in response. |
| V-07 Correction | Owner corrects mistaken ₹500 credit to ₹450 with reason | Original and correction visible; final amount owed ₹450. |
| V-08 Dispute | Customer reports their entry; owner resolves with note | Status visible; balance unchanged until a separate correction. |
| V-09 Device loss | Owner has one Synced and one Pending entry, then restores on new phone | Synced entry restored; Pending entry absent with clear recovery boundary. |
| V-10 Quota outage | Simulate D1 write limit/service unavailable | Existing linked writes remain Pending; new link unavailable; no false backup claim. |
| V-11 Export | Export a date range containing credit, payment and correction | Opening plus signed entries equals closing balance in PDF and CSV. |

## 10. Requirement traceability and phase gates

| Phase | SRS requirements | Related PRD requirements | Gate |
|---|---|---|---|
| 0 Foundation | F-001–005, N-001–003, D-003 | PR-01–02 | Sign-in, shop ownership and cross-account privacy verified. |
| 1 Online ledger | F-006–019, F-022, D-001–002 | PR-03–08 | QR/link/credit/payment/balance journey and duplicate tests pass. |
| 2 Offline and trust | F-020–021, F-024–032, N-004, N-010 | PR-09–12 | Offline replay, correction, dispute, recovery and privacy tests pass. |
| 3 Release features | F-023, F-033–037, N-005, N-007–009, D-004–006 | PR-13–18 | Reports, language, accessibility, export/deletion and backup drill pass. |
| 4 Pilot/launch | N-006, N-011–012 and all prior requirements | All | Field performance, quota readiness and full regression accepted. |

The [BRD](BRD.md) contains the business rules and the [PRD](PRD.md) contains the detailed screen behavior. Requirement IDs in this document are the baseline for test cases and change control.

D03 implements local D1/SQLite schema guards with safe integer money and versioned storage text ceilings (120-character labels, 500-character notes/reasons). These storage ceilings do not close the smaller product transaction-limit decision. Account-isolated databases and atomic entry/outbox and page/cursor writes are tested at the persistence boundary; complete user journeys remain in their assigned phases. See [progress](docs/implementation/PROGRESS.md).

## 11. Open decisions and change control

The following must be resolved before their affected phase exits:

1. **Due-date allocation:** Confirm oldest-unpaid-credit-first (then entry ID for ties) or choose another deterministic rule before showing aggregate overdue amounts.
2. **Amount and input limits:** D08 sets the approved pilot credit limit to ₹1,00,000 per entry and note limit to 500 UTF-16 code units. Dispute reason length and export range remain to be fixed before pilot.
3. **Deletion and retention:** Define published duration, customer access removal/re-link behavior, shop deletion handling and support process before public release.
4. **Backup destination and restore owner:** Choose encrypted operational backup location, key custody and restore schedule before live financial records.
5. **Supported devices:** Set minimum Android version and pilot hardware list in phase 0.
6. **Customer onboarding friction:** If field research shows that mandatory customer app installation prevents adoption, revisit QR-first scope in the BRD/PRD before implementing a fallback.

Changes to a requirement shall update its ID/versioned text, acceptance tests, and affected PRD/SES sections together. No unverified market claim or provider free-tier limit is a software guarantee.

### D04 implementation checkpoint

Local auth verifies Google identity using trusted JWKS, maps immutable subject and role, issues hashed 15-minute opaque access credentials and rotating refresh credentials capped at 30 days from initial issue, and revokes the session on spent-token replay/logout. Android secure storage and role selection/sign-out are wired; Pending records stay account-isolated and locked on sign-out. See the API session policy, security requirements and implementation progress for checks and limits. Live Google configuration, device evidence and deployment remain pending; this is not a public-release claim.

### D06 implementation checkpoint

Customer QR uses exactly `udhaar://customer/v1/{publicId}` with a 256-bit random lowercase hex lookup ID and no personal, financial or credential fields. Own-QR read and online rotation enforce the customer session. Rotation revokes the old mapping atomically, preserves internal links and permits at most three attempts per customer per ten minutes. The customer screen renders a readable QR with account label and explains that it does not authorize payment. Account-specific secure-storage cache labels saved codes as unverified; uncertain rotation persists a recovery marker and hides the old code until online confirmation. Offline presentation works in an already verified open session, even if an attempted auth renewal fails: credentials are discarded and the account database is locked, while only the cached public QR remains with a Sign in again action. This confers no cloud or ledger authorization. Failed rotations retain an explicit failure notice after recovering the current QR. Full offline session restoration after cold startup remains D12. D07 owner resolution/linking and physical-device QR scanning remain separate gates. Synthetic authorization/rotation/cache/UI and independent rendered-image decoding evidence is recorded in implementation progress.


### D07 implementation checkpoint

Owner scanning accepts only the bounded exact `udhaar://customer/v1/{publicId}` format, requests camera permission only on scan, and provides permission retry/settings and invalid/version/revoked/internet-needed states. An online lookup authorizes the shop before displaying minimal customer identity and makes no link or financial change. Explicit Add customer creates one active relationship using an atomic, scoped D1 batch and operation receipt; same-ID/body retries replay, changed bodies conflict, and concurrent different IDs for the same shop/customer return the existing link. Live QR/ownership/customer predicates are checked at commit. Removed access is not restored by scanning. Original confirmed command bodies are saved in account/shop-specific secure storage before POST and retained after response loss/restart; new scans cannot replace an unresolved confirmation. The bounded customer list states overflow and returning customers open an authorized ledger screen. Credit/payment/history and complete pagination remain D08-D10; owner offline cache/sync remain later gates. Physical camera/device and remote D07 deployment evidence are recorded separately in implementation progress.

### D08 online credit implementation contract (2026-10-01)

Approved pilot limits v1: positive credit ₹0.01–₹1,00,000.00 (1–10,000,000 integer paise), optional trimmed note up to 500 UTF-16 code units, valid optional YYYY-MM-DD due date, financial JSON body at most 4,096 bytes, and existing first-100 list ceiling. General JSON/auth bodies retain the 65,536-byte ceiling. The Worker validates strict credit fields and canonical UUID v4 operation identity; unknown/forged effect fields and payment/correction variants are rejected in D08. A first online command accepts device occurrence time from 24 hours before server time to 5 minutes ahead. Receipt replay precedes this mutable clock check. Payments, corrections, full history/pagination and offline local ledger remain their later phases.

The owner opens a linked customer, enters amount/note/date, reviews customer identity and the explicit Customer owes you direction, then confirms. Review has no financial effect. The app durably saves an account/shop/link-specific command before POST and never generates a replacement ID after uncertainty. Reopening the form recovers that body with Check same credit; a response must match shop, link, type, amount/effect, note/date, occurrence time and sequence before acknowledgement. Unverified responses, storage failures, auth/network failure and rejected requests retain the saved record for recovery; it is not silently discarded. This online recovery record is not the D11 offline ledger/outbox, and does not provisionally change the visible balance.

The Worker uses the existing immutable ledger triggers and atomic entry-plus-receipt batch; live authorization is rechecked at commit and replay requires current access. Receipt retries return the original committed balance/version even after later entries, explicitly labeled as the balance when this credit was recorded. Owner link/list reads refresh the current balance. Customer My shops receives its own active link balances/versions from the same profile query and can refresh them. New minimal balance reads authorize the entire current snapshot in one SQL query; no history page or aggregate overdue total is inferred. No new migration is needed.

### D09 payment implementation checkpoint (2026-10-01)

SRS-F-015–019 online payment behavior is implemented locally: owner reviews the linked customer, positive amount and Cash/UPI method, then explicitly confirms payment received. Amounts use the D08 ₹0.01–₹1,00,000 cap and integer paise. Methods are manually entered; no bank verification or money transfer is implied. The atomic server guard rejects overpayment and concurrent overdraw. Current owner/customer authorized reads reconcile to signed immutable effects. Payment due dates/notes are not offered by this strict initial variant.

Saved payment requests survive restart and retry with the original body/ID. An unresolved credit or payment blocks a new confirmation for the same relationship. Only verified success clears an uncertain request. Explicit balance rejection remains visible; correction requires user review and archives the original before a new draft. Amounts are never silently reduced. Full dated history is D10; offline local posting and sync remain D11–D13. Local evidence and deployment/phone gates are in implementation progress.
