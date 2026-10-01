# Udhaar Khata — Product Requirements Document

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [Scope](SCOPE.md) · [Personas](USER-PERSONAS.md) · [User journeys](USER-JOURNEY-USER-FLOW.md) · [SRS](SRS.md) · [UI/UX spec](UI-UX-DESIGN-SPEC.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Product owner:** To be assigned  
**Target release:** Android public release after private test and shop pilot  
**Related:** [Product Vision](PRODUCT-VISION.md) · [BRD](BRD.md) · [SES](SES.md) · [Market Research](MARKET-COMPETITOR-RESEARCH.md)

## 1. Product summary

Udhaar Khata is a free Android app for recording customer credit at small shops. The customer signs in with Google and presents a personal QR code. The shopkeeper scans it, links a new customer when needed, enters the credit amount, checks the customer and amount, and submits. The shopkeeper records payments in the same ledger. Both parties can read the dated history for their shared account.

The app must keep serving previously linked customers without internet. It stores pending owner entries on the phone and syncs them through a Cloudflare Worker to D1 later. A new customer cannot be verified or linked offline. Cloud-acknowledged records can be recovered on a new phone; unsynced records cannot be recovered from D1 if the original phone is lost.

## 2. Problem and opportunity

Shop credit is often recorded in paper books or a private app. Searching for a customer, correcting mistakes, explaining a balance, and recovering lost records can cost time and trust. A customer rarely sees the same record at the moment credit is given.

The product hypothesis is that **customer-presented QR identification** will make repeat credit entries quick while a shared, dated ledger reduces confusion. Existing products already offer free ledgers, offline entry, reports and customer visibility; the QR workflow and customer adoption must be validated in a real shop pilot. [Research findings](MARKET-COMPETITOR-RESEARCH.md)

## 3. Goals and success measures

| Goal | Pilot metric | Proposed gate |
|---|---|---|
| Quick repeat entry | Time from successful scan to local save for a linked customer | Median under 15 seconds on supported pilot phones; capture baseline against shop's current method |
| Correct ledger | Difference between displayed balance and sum of posted entries | Zero unexplained differences |
| Reliable sync | Duplicate postings and unresolved pending-operation age | Zero duplicate charges; all retryable test operations eventually sync after service/network recovery |
| Customer transparency | Customer onboarding completion, history views and dispute discoverability | Measure in pilot and set adoption gate from observed baseline, rather than inventing a conversion target |
| Low operating cost | D1 rows read/written/storage and Worker requests | Stay within the pilot's approved free-tier budget with alerts before limits |
| Recovery clarity | Ability to restore cloud-acknowledged entries and user understanding of pending entries | Restore drill passes; tested users can distinguish Synced from Waiting to sync |

Targets are proposed acceptance gates, not achieved results. The product is free for owners and customers in the first release; provider free tiers are finite.

## 4. Users, roles, and access

| Role | First-release access |
|---|---|
| Shop owner | One Google account owns one shop; links customers, records credit/payments/corrections, resolves disputes, sees shop totals and customer histories, shares reminders and exports data. |
| Customer | One Google account can belong to several shops; presents QR, sees only their own shop balances and histories, and reports disputes. Cannot post or edit shop transactions. |
| Operator | Restricted support, monitoring, backup and deletion procedures outside the ordinary user interface. |

One shop cannot view another shop's records. A QR is an account lookup identifier, never proof of payment, consent to an amount, or access authorization. The app shows identity and amount before the owner submits.

## 5. Release scope and priorities

**P0** means required before public release. **P1** means included in the currently agreed first release, but developed after the core P0 ledger in the phased plan. P1 items still block public release unless the BRD is explicitly revised. **Later** is outside first-release scope.

| Priority | Capability |
|---|---|
| P0 | Google sign-in, shop setup, customer registration and QR, scan/link, credit sale, payment received, balance/history, cross-account privacy, exact money arithmetic, duplicate prevention, offline owner entry for linked customers, visible sync state, customer read view, recovery of acknowledged entries. |
| P1 | Corrections with audit history, customer disputes, optional due dates, manually shared reminders, PDF statement, CSV export, Hindi interface, accessibility, data export/deletion request flow, operational backup and quota monitoring. |
| Later | Supplier ledgers, staff, multiple shops per owner, bill photos, automatic messages, payment collection/verification, refunds/advances, inventory, invoices, iOS/web, more currencies/languages. |

## 6. End-to-end user journeys

### 6.1 First-time customer and shop link

1. Customer installs app, chooses Customer, signs in with Google and sees a personal QR and display label. Initial registration needs internet.
2. Customer shows QR to a shopkeeper. Owner scans it while online.
3. App resolves the QR. If not linked to this shop, it shows the customer's label and **Add customer**. Owner confirms, optionally chooses a shop nickname, and opens the credit amount screen.
4. Owner enters amount, optionally note/due date, reviews identity and amount, and submits.
5. Customer sees the shop and posted entry after sync/refresh.

**Acceptance:** Repeating the same link action produces one shop/customer relationship. An invalid, revoked or unknown QR cannot create a relationship. A new QR scanned offline shows **Internet needed to add this customer** and does not create an unverified account.

### 6.2 Returning customer credit

1. Customer opens QR; a previously issued QR remains available offline.
2. Owner scans; a locally known shop/customer match opens the credit form, including offline.
3. Owner enters amount and taps **Submit** after reviewing customer and amount.
4. App saves locally at once. It shows **Synced** after server acknowledgment or **Waiting to sync** while offline.

**Acceptance:** Double tapping or retrying a request after losing the response creates exactly one posted credit entry. The owner's visible balance updates from the saved local entry; customer balance updates once the server and customer app have synced.

### 6.3 Payment and balance

1. Owner opens or scans the linked customer and chooses **Payment received**.
2. Owner enters a positive amount and selects Cash or UPI as a manual label.
3. App saves the payment; the balance reduces exactly once and history shows date, amount, method and sync state.

**Acceptance:** Example: ₹500 credit followed by ₹200 payment yields ₹300 owed. The app never labels a manually entered UPI payment as bank-verified. Handling overpayment/advance is outside first-release scope; the form must prevent a payment exceeding the currently recorded owed balance unless the BRD is changed.

### 6.4 Review, correction and dispute

1. Owner and customer can open a dated entry from the shared ledger.
2. Owner selects **Correct entry**, enters a reason and replacement amount or cancellation. The original remains visible alongside the correction.
3. Customer selects **Report a problem** on a synced entry, enters a short reason, and sees an Open status. Owner can mark it Resolved with a note. Reporting or resolving a dispute does not itself change the balance.

**Acceptance:** A corrected entry changes the displayed balance exactly by the correction's effect. The history still shows original and correction. A customer cannot correct an entry or see another customer's dispute. Dispute submission needs internet; cached history remains readable offline.

### 6.5 Reminder, statement and recovery

1. Owner reviews the customer's balance and optional due date. They preview a polite reminder and choose a destination through Android sharing; no automatic message is sent.
2. Owner selects a customer/date range and generates a PDF statement or CSV. Reports include opening balance for the range, dated entries, corrections and closing balance.
3. On a new phone, the user signs in and downloads acknowledged records. The app shows the last sync time and explains that entries still pending on a lost phone are not present in the cloud.

**Acceptance:** Export totals reconcile with the ledger. A reminder shows the correct shop, customer and current known balance, and the owner initiates sending. Recovery restores acknowledged records without multiplying them.

## 7. Feature requirements and acceptance criteria

| ID | Priority / phase | Product requirement | Key acceptance checks |
|---|---|---|---|
| PR-01 | P0 / 0 | Google sign-in for owner and customer; role-specific start screen. | A user reaches only their own role's data; cloud actions require a valid session. |
| PR-02 | P0 / 0–1 | Owner creates one shop with a required name. | Same owner cannot create a second active shop in v1; shop data belongs to that owner. |
| PR-03 | P0 / 1 | Customer QR screen with readable label and share-safe identifier. | QR works from cached registration; no balance, email, token or phone number in QR payload. |
| PR-04 | P0 / 1 | QR scanner distinguishes linked, unlinked, invalid and revoked identities. | Linked opens entry; unlinked online offers Add customer; unlinked offline gives clear error; invalid/revoked cannot link. |
| PR-05 | P0 / 1 | Create one shop/customer relationship. | Repeated scans/link requests return the same ledger; customer can be linked to another shop independently. |
| PR-06 | P0 / 1–2 | Record credit in integer paise and show a running balance. | Positive INR amount required; confirmed customer/amount displayed; duplicate submit/sync posts once. |
| PR-07 | P0 / 1–2 | Record a manual payment received. | Positive amount no greater than owed balance; Cash/UPI label is user-entered; balance decreases once. |
| PR-08 | P0 / 1–2 | Owner and customer ledger screens. | Owner sees own shop/customers; customer sees only own ledgers per shop; entries show type, amount, time, note and status as applicable. |
| PR-09 | P0 / 2 | Offline repeat scan and entry queue. | Owner can post for cached linked customer in airplane mode; first-time QR link cannot proceed; pending entry survives app restart. |
| PR-10 | P0 / 2 | Sync status, retry and recovery messaging. | Pending/Synced/Needs attention states visible; retry does not duplicate; last successful sync displayed; cloud restore excludes unacknowledged entries. |
| PR-11 | P1 / 2 | Correct an entry without deleting history. | Original, correction and reason remain visible; one correction operation changes balance exactly once. |
| PR-12 | P1 / 2 | Customer dispute and owner resolution. | Dispute refers to one entry; owner sees it; status changes have a visible history; amount unchanged unless corrected separately. |
| PR-13 | P1 / 3 | Optional due date on credit entry. | Date is optional and shown in entry detail; overdue wording is shown only when outstanding credit is attributable to that due date. |
| PR-14 | P1 / 3 | Owner-previewed reminder via Android share menu. | No automatic dispatch; owner can edit/cancel before sending; message uses known balance and due information. |
| PR-15 | P1 / 3 | PDF statement and CSV export. | Date-range totals reconcile with entry history, including corrections; exports are scoped to authorized shop/customer. |
| PR-16 | P1 / 3 | English and Hindi user interface. | Critical flows, errors, balance direction, sync status and reminder templates have reviewed translations. |
| PR-17 | P1 / 3 | Data controls and help. | Owner can export and request deletion; customer can remove app access and request deletion; user sees request status and support path. |
| PR-18 | P1 / 3–4 | Accessibility and operational readiness. | Readable amounts and labels, screen reader support, appropriate touch targets; quota, failures and backup/restore monitored and rehearsed. |

## 8. Screen and content requirements

| Screen | Main content and action | Required states |
|---|---|---|
| Welcome/role | Choose Owner or Customer; Google sign-in | Loading, cancelled, sign-in error, no internet |
| Shop setup | Shop name, confirmation | Duplicate shop, validation error, save failure |
| Owner home | Total owed, customer list/search, Scan QR, sync indicator | Empty, offline cache, loading, sync failure |
| Customer QR | Personal QR, display label, explanation of use | Registration needed, cached/offline, revoked QR |
| Scanner | Camera view, permission explanation, manual retry | Permission denied, unreadable/invalid QR, offline unknown QR |
| Link customer | Profile label, optional nickname, Add customer | Already linked, stale/revoked QR, network error |
| Credit/payment form | Customer identity, amount, type, optional note/date/method, Submit | Invalid amount, double tap, offline save, server rejection |
| Customer ledger | Balance, entries, payment/correction actions, share/export | Empty, paginated history, pending entry, dispute marker |
| Customer app home | Linked shops and per-shop balances, last sync | No linked shops, stale cache, refresh error |
| Entry detail/dispute | Entry facts, correction trail, dispute status | Permission denied, report validation, offline report unavailable |
| Settings/help | Language, account, data export/deletion, support, last sync | Request pending/complete/error |

Use explicit labels: **Customer owes you ₹X** for the owner and **You owe [shop] ₹X** for the customer. Pair color with text. A QR scan never posts an amount automatically. Confirmation may be presented within the amount form; avoid unnecessary extra screens during the counter flow.

## 9. Product rules and edge cases

- **Money:** INR only. Store exact integer paise; do not use floating-point balance arithmetic. Reject zero, negative, malformed and out-of-range amounts with useful messages. D03 enforces the safe integer storage ceiling and 120-character label/500-character note and reason ceilings; the smaller business maximum per transaction will be fixed in D08 and validated before pilot.
- **Balance:** Credit adds to amount owed; payment subtracts; correction has a signed effect. Owner and customer views must agree after both are synced. Never trust a client-supplied balance as the source of truth.
- **Due dates:** A payment may cover multiple credit entries. The first-release product must define a deterministic allocation rule before displaying overdue amounts; proposed rule is oldest unpaid credit first, then by entry ID for ties. Until implemented and tested, show due dates on entries without an aggregate overdue claim.
- **Duplicate action:** Same shop/customer link or transaction operation may be retried; the result is the existing link/entry, not another one. Show a clear saved result after uncertain network responses.
- **Connectivity:** Initial registration, unknown QR lookup/link, dispute submission, Google reauthentication, new-phone restore and cloud sync need internet. Repeat scan/post for locally linked customers and cached history work offline.
- **QR misuse:** QR reveals only a lookup identifier. A copied image can be presented by someone else, so owner confirms the displayed person. A revoked QR cannot create a new link online; cached link behavior is governed by server permissions at sync.
- **Removal:** A customer can stop viewing a shop in their app and request account deletion. This does not automatically erase the owner's historical ledger; exact retention and re-linking behavior must be specified in the launch privacy policy.
- **Account switch:** Sensitive local data for one Google account must not appear under another. Pending operations need a safe recovery/export path before local clearing.
- **Quotas/outage:** If D1 or Worker limits interrupt service, previously linked owner entries can remain locally pending with an unmistakable warning. New customer linking stops; the app must not imply pending data is backed up.
- **No bank proof:** Cash and UPI are manual entry labels. No UPI collection, payment gateway or payment verification is in this release.

## 10. Nonfunctional product requirements

- **Privacy and trust:** No contacts permission in v1. Customer data visible only to the owner of that shop and that customer. No personal or financial information in QR payload, logs or analytics. Privacy notice and retention policy reviewed before launch.
- **Reliability:** No silent loss of locally saved entries. Reinstall/new phone recovery promise applies only to server-acknowledged data. Migrations and backup restoration are tested before public release.
- **Usability:** Large tap targets, visible account identity and amount before submission, readable Hindi/English labels, screen reader descriptions for QR and balance state.
- **Performance:** The owner home and existing customer ledger load from local data without waiting for network. Paginated history; pilot timing target in section 3.
- **Cost:** Monitor D1 reads/writes/storage and Worker requests. Free access for users is the intended product policy; operational costs may grow with use.
- **Support:** Give users a way to report incorrect entries, QR problems, sync failures, lost phone, and export/deletion requests.

## 11. Analytics and learning plan

Collect privacy-preserving event counts, with no amounts, customer names, notes, Google tokens or QR identifiers in analytics:

| Event or measure | Why it matters |
|---|---|
| Owner/customer onboarding started and completed | Quantify two-sided adoption friction |
| QR scan outcome: linked, new, invalid, offline unknown | Find failures in the main flow |
| Time from successful linked scan to local save | Test the speed hypothesis |
| Credit/payment saved and later acknowledged | Track sync success without recording financial values in analytics |
| Pending queue age and retry/error category | Detect reliability risk |
| Customer history viewed and dispute started/submitted | Test whether shared visibility is actually used |
| Export/reminder generated; share menu opened | Understand supporting-feature use without tracking recipients |
| D1/Worker quota usage, API errors, crashes | Keep the service available and within budget |

Pilot observation and voluntary interviews should supplement analytics. Do not infer trust or satisfaction solely from app-open counts.

## 12. Phased delivery and release gates

| Phase | Product milestone | Exit criteria |
|---|---|---|
| 0 — Foundation | Flutter app shell, Google sign-in, owner/customer identity and shop setup; test Worker/D1 | Correct role routing and account isolation demonstrated; design of money and sync states reviewed. |
| 1 — Online ledger | QR generation, scan/link, credit, payment, balances and history | Shopkeeper completes full online journey; exact amounts and duplicate-action tests pass. |
| 2 — Offline and trust | Local queue, sync/recovery labels, customer view, correction and dispute | Existing QR works offline, unknown QR is blocked offline, reconnect posts once, and privacy tests pass. |
| 3 — First-release completeness | Due dates, share reminder, PDF/CSV, Hindi, data controls, accessibility | Reports reconcile; critical translations and deletion/export paths reviewed; no unresolved P0/P1 release blocker. |
| 4 — Pilot and launch | Private test, small shop pilot, fixes, public Android release | Recovery drill, security/privacy review, quota monitoring, pilot feedback and success gates pass. |

Engineering details and test evidence live in [SES.md](SES.md). Public deployment and distribution are separate actions requiring explicit authorization under the workspace instructions.

## 13. Dependencies and unresolved launch decisions

- **Google and Cloudflare setup:** OAuth client, Android signing identities, Worker/D1 environments, domains if required, credentials and monitoring must be configured before live testing.
- **Operational backup:** Define encrypted backup destination, ownership and restore runbook before live financial data is accepted. PDF/CSV exports do not replace system backup.
- **Privacy and retention:** Set actual deletion/retention timelines and public wording after appropriate review; do not invent a legal period.
- **Due-date allocation:** Confirm the oldest-credit-first rule in user research before implementing overdue totals.
- **Transaction bounds:** Set amount, note-length, rate-limit and export limits before pilot from realistic shop examples and abuse testing.
- **Customer adoption:** The QR flow requires customer installation and Google sign-in. Pilot evidence may justify a separate onboarding fallback, but that would change the currently approved first-release scope.
- **Provider capacity:** Verify current free-tier terms and plan an operational response if D1/Worker usage approaches limits.

## 14. Traceability

The [Product Vision](PRODUCT-VISION.md) states why the product exists. The [BRD](BRD.md) records business rules and the agreed feature scope. This PRD defines user-visible behavior and release acceptance. The [SES](SES.md) defines implementation, API, data and test design. The [Market Research](MARKET-COMPETITOR-RESEARCH.md) records competitor evidence and the QR-flow hypothesis to validate.

### D04 implementation checkpoint

Local auth verifies Google identity using trusted JWKS, maps immutable subject and role, issues hashed 15-minute opaque access credentials and rotating refresh credentials capped at 30 days from initial issue, and revokes the session on spent-token replay/logout. Android secure storage and role selection/sign-out are wired; Pending records stay account-isolated and locked on sign-out. See the API session policy, security requirements and implementation progress for checks and limits. Live Google configuration, device evidence and deployment remain pending; this is not a public-release claim.

### D06 implementation checkpoint

Customer QR uses exactly `udhaar://customer/v1/{publicId}` with a 256-bit random lowercase hex lookup ID and no personal, financial or credential fields. Own-QR read and online rotation enforce the customer session. Rotation revokes the old mapping atomically, preserves internal links and permits at most three attempts per customer per ten minutes. The customer screen renders a readable QR with account label and explains that it does not authorize payment. Account-specific secure-storage cache labels saved codes as unverified; uncertain rotation persists a recovery marker and hides the old code until online confirmation. Offline presentation works in an already verified open session, even if an attempted auth renewal fails: credentials are discarded and the account database is locked, while only the cached public QR remains with a Sign in again action. This confers no cloud or ledger authorization. Failed rotations retain an explicit failure notice after recovering the current QR. Full offline session restoration after cold startup remains D12. D07 owner resolution/linking and physical-device QR scanning remain separate gates. Synthetic authorization/rotation/cache/UI and independent rendered-image decoding evidence is recorded in implementation progress.


### D07 implementation checkpoint

Owner scanning accepts only the bounded exact `udhaar://customer/v1/{publicId}` format, requests camera permission only on scan, and provides permission retry/settings and invalid/version/revoked/internet-needed states. An online lookup authorizes the shop before displaying minimal customer identity and makes no link or financial change. Explicit Add customer creates one active relationship using an atomic, scoped D1 batch and operation receipt; same-ID/body retries replay, changed bodies conflict, and concurrent different IDs for the same shop/customer return the existing link. Live QR/ownership/customer predicates are checked at commit. Removed access is not restored by scanning. Original confirmed command bodies are saved in account/shop-specific secure storage before POST and retained after response loss/restart; new scans cannot replace an unresolved confirmation. The bounded customer list states overflow and returning customers open an authorized ledger screen. Credit/payment/history and complete pagination remain D08-D10; owner offline cache/sync remain later gates. Physical camera/device and remote D07 deployment evidence are recorded separately in implementation progress.

### D09 payment implementation checkpoint (2026-10-01)

The existing owner customer screen adds Record payment received, with positive amount, Cash/UPI, customer review and explicit confirmation. It states that the owner manually records receipt and the app does not verify a bank transfer. Successful receipts show the balance when recorded, with refresh for current balance. Overpayment shows a rejected saved request, current authorized balance and explicit amount/method correction; uncertain requests can only be checked using the same identity. Credit/payment pending confirmations block replacement for that customer. Full owner/customer transaction history remains D10. Deployment and phone acceptance are separate gates in implementation progress.
