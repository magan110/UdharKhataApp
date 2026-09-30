# Udhaar Khata — Business Requirements Document

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [Product vision](PRODUCT-VISION.md) · [Market research](MARKET-COMPETITOR-RESEARCH.md) · [Scope](SCOPE.md) · [PRD](PRD.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Product:** Free Android digital credit ledger for small shops  
**Companion document:** [SES.md](SES.md)

## 1. Purpose and business outcome

Udhaar Khata helps a shopkeeper record customer credit in seconds and helps the customer see what they owe. A customer signs in with Google, opens their personal QR code, and shows it at the counter. The shopkeeper scans it, adds the customer to the shop if necessary, enters the amount, and submits. Payments reduce the balance. Both parties can inspect the dated history.

The app is free to end users. The first release uses Flutter for Android, local storage for offline work, and a Cloudflare Worker with D1 for cloud sync. Free operation is a launch target subject to Cloudflare quotas, rather than a promise of unlimited free cloud storage.

## 2. Business goals and measures

| Goal | Pilot measure and initial target |
|---|---|
| Fast counter transaction | Existing customer QR scan to saved credit in at most 3 deliberate actions after scan; pilot median under 15 seconds on a supported phone |
| Reliable balances | No unexplained difference between displayed balance and the sum of posted entries in pilot reconciliation |
| Useful offline operation | Previously linked customer can be charged and a payment recorded without internet; queued entries sync after reconnection |
| Customer transparency | Customer can view each linked shop's balance and dated history, and report a disputed entry |
| Low operating cost | Track D1 rows read, rows written, storage, Worker requests, and failures; remain within current free quotas during pilot |
| Recoverability | Reinstall/new phone restores every entry acknowledged by the server; unsynced local entries are clearly identified |

Targets are pilot acceptance goals, not claims about achieved performance.

## 3. Users and scope

**Shop owner:** One Google account manages one shop in the first release. Creates credit entries and records customer payments, corrections, due dates, and reminders. Views totals and exports data.

**Customer:** Signs in with Google; has a personal QR code; can be linked to multiple shops. Sees their own balance and transaction history separately for each shop, including last sync time for offline views. Can report a disputed entry and remove their viewing/link relationship as described under deletion and access.

**Administrator/operator:** Handles support, abuse reports, monitoring, backups, and deletion requests with least privilege. There is no staff access in the first release.

### Included in first public release

- Google sign-in for owners and customers, with role-specific onboarding.
- One shop per owner; customers may be linked to many shops.
- Customer QR generation and owner scanning. A new QR prompts **Add customer**; an existing linked QR opens the credit entry screen.
- Credit sale, payment received, and correction entries. Amounts are in INR.
- Optional due date on a credit entry; optional note and manual cash/UPI payment method.
- Customer and owner views of balance and dated history.
- Dispute report from customer to owner, with visible status.
- Owner-generated PDF statement and CSV export; owner-reviewed reminder through Android sharing.
- English and Hindi interface, offline owner writes for linked customers, offline customer read of last synced data, sync indicators, recovery of cloud-acknowledged entries.
- Owner data export and deletion request; customer access removal.

### Later phases

Supplier ledgers, staff accounts, multiple shops per owner, refunds and advances, bill photos, automatic messaging, verified payment collection, inventory, invoices, and other languages or currencies. These require separate business and technical review.

## 4. Core journeys

### J1 — Customer registers and presents QR

1. Customer signs in with Google and chooses a display name if needed.
2. App registers the account online and receives a random public customer identifier.
3. App shows a QR encoding the app version and that identifier. The QR carries no balance, phone number, Google token, or secret.
4. Customer presents the QR at the shop. The app can display a previously issued QR offline.

**Outcome:** The QR identifies the account for shopkeeper lookup. It does not approve a charge or prove that the person holding a screenshot is the account holder. The shopkeeper confirms the displayed identity with the person at the counter.

### J2 — First visit to a shop

1. Owner scans the QR while online.
2. App queries the server. If that customer is not linked to this shop, it displays the customer identity and **Add customer**.
3. Owner confirms the link and may enter a shop-specific name/nickname.
4. App opens the amount entry screen; owner checks amount and customer, then submits the credit sale.
5. Customer sees the shop and entry after sync.

**Offline exception:** A previously unknown QR cannot be verified or linked while offline. The app clearly says that internet is needed for this first scan; it must not create an unverified customer record.

### J3 — Repeat credit sale

1. Customer shows the same QR.
2. Owner scans; app finds the linked customer, including from its local cache when offline.
3. Owner enters the amount, optionally note and due date, reviews customer and amount, and submits.
4. App updates the local ledger immediately and marks it **Waiting to sync** until D1 acknowledges it. Customer sees the entry after server sync and their next refresh.

### J4 — Payment, correction, and disagreement

1. Owner finds or scans a linked customer and records a payment received. Cash/UPI is an owner-entered label, not bank verification.
2. A mistake is corrected by a new reversing/correction entry linked to the original. Original entries remain visible in the audit history.
3. Customer can flag an entry as disputed and add a short explanation. Owner can mark the dispute resolved with a note; neither action silently changes the amount.

### J5 — Reminder, statement, and recovery

1. Owner reviews balance and optionally a due date, then uses Android sharing to send a prepared reminder. The owner controls whether and where to send it.
2. Owner generates a PDF statement or CSV export for a customer or date range.
3. After signing in on a new phone, the owner or customer downloads server-acknowledged records. The app explains that entries still waiting on the lost phone cannot be recovered from D1.

## 5. Business rules

| ID | Rule |
|---|---|
| BR-01 | Each shop/customer pair has one ledger and one current relationship; duplicate scans must not create duplicate customer records. |
| BR-02 | An owner may add credit and record payments only for customers linked to their shop. Customers may view only their own linked ledgers. |
| BR-03 | Balance owed = total posted credit sales plus signed corrections minus total posted payments. Store money as integer paise; display INR with two decimals. |
| BR-04 | Every transaction has an immutable ID, creator, creation time, type, amount, and sync state. Repeated sync must not post it twice. |
| BR-05 | A correction references the original transaction and preserves history. No destructive edit or delete in normal ledger operation. |
| BR-06 | Customer dispute is a separate record; it does not adjust balance. |
| BR-07 | The app never states that a manually recorded UPI/cash payment was independently verified. |
| BR-08 | A due date is optional. An overdue label depends on unpaid balance and the applicable due date; it is not a legal debt determination. |
| BR-09 | A customer may appear in many shops, but one shop cannot inspect another shop's entries or balance. |
| BR-10 | A QR is an identifier, not authorization. Authentication and shop permissions are checked on every server operation. |
| BR-11 | New customer linking needs network access; repeat use of a previously linked QR can work offline. |

## 6. Functional requirements and acceptance examples

| ID | Requirement | Acceptance example |
|---|---|---|
| FR-01 | Owner and customer sign in with Google | A returning user reaches only their permitted shop/customer views; expired credentials require online renewal before cloud operations. |
| FR-02 | Customer QR screen | QR reopens offline after initial registration; it contains no personal or financial data. |
| FR-03 | Scan and link new customer | Online scan of a valid, unlinked QR offers **Add customer**; accepting creates one link and opens amount entry. |
| FR-04 | Scan linked customer | Scan opens that customer's credit entry screen, online or from verified local cache offline. |
| FR-05 | Post credit | Owner enters positive amount, confirms identity/amount, receives local confirmation, and sees updated balance; duplicate submit/sync yields one entry. |
| FR-06 | Record payment | Owner records positive amount and cash/UPI label; balance decreases exactly once. |
| FR-07 | Correct an entry | Owner can reverse and replace an incorrect entry; original and reason remain in history. |
| FR-08 | View ledgers | Owner sees shop total and customer lists; customer sees their own ledgers per shop and last sync time. |
| FR-09 | Dispute entry | Customer can report a specific entry; owner sees the report and can resolve it with a note. |
| FR-10 | Remind and export | Owner previews reminder; PDF and CSV contain correct dated entries and totals for selected scope. |
| FR-11 | Offline/sync | Offline writes for linked customers queue; reconnecting posts once, with visible failure/retry states. Unknown QR gives a clear online-needed message. |
| FR-12 | Account/data controls | Owner can export and request deletion; customer can remove shop access and request account deletion. Requests have tracked outcomes. |
| FR-13 | Language | Core screens, errors, and shared reminder templates are available in English and Hindi. |

## 7. Nonfunctional and operating requirements

- **Privacy:** Minimize collected data. Google account subject ID is the stable login key; email and display name are profile fields, not authorization keys. No contacts permission is required. Do not put financial data or credentials in QR codes, logs, or analytics.
- **Security:** TLS for API calls; Android secure storage for session material; per-request authentication and authorization; server-side input validation and rate limits; no D1 access from the app.
- **Reliability:** Offline actions are explicitly Pending, Synced, or Failed. A local entry must never be silently discarded. Server acknowledgments drive recovery claims.
- **Performance:** Core ledger screens should open from local storage without waiting for the network. Paginate cloud history and index by shop/customer/time.
- **Accessibility:** Large touch targets, readable balance polarity and labels, screen reader descriptions, and clear English/Hindi terms for credit versus payment.
- **Cost:** Monitor Cloudflare quotas and design compact rows/indexes. Stop onboarding or enter read-only/degraded mode if quota pressure threatens writes; do not quietly lose local transactions.
- **Support:** Provide a help path for mistaken scans, disputed entries, failed sync, lost devices, and deletion requests.

## 8. Delivery phases and gates

| Phase | Deliverable | Exit gate |
|---|---|---|
| 0. Foundations | Flutter shell, Worker/D1 environments, Google authentication, schema, security model, monitoring | Owner/customer sign-in works in test environment; cross-account access is denied. |
| 1. Ledger core | Shop setup, customer QR, scan/link, credit, payment, balances, history | A complete online sale/payment journey reconciles to exact paise; duplicate QR and duplicate post cases pass. |
| 2. Offline and trust | Local SQLite, queued sync, correction, disputes, customer history, failure states | Offline repeat scan and posting work; reconnect syncs once; unknown offline QR is blocked; customer sees only own entries. |
| 3. Sharing and controls | Due dates, reminders, PDF/CSV, Hindi, export/deletion workflows, accessibility | Realistic shop pilot completes daily work without manual balance repair; deletion/export paths verified. |
| 4. Pilot and launch | Private test, small shop pilot, fixes, public Android release | Security review, recovery drill, quota dashboard, crash/sync monitoring, and pilot acceptance targets met. |

Each phase can be reviewed before proceeding; phase 4 is the first public release. Public launch and any external deployment need separate authorization.

## 9. Assumptions, risks, and decisions to validate in pilot

- One shop owner account manages one shop; customers can belong to multiple shops.
- Owners create entries; customer QR presentation alone is not consent to a particular amount. Pilot should confirm that visible confirmation and dispute flow are adequate. A screenshot of a QR can identify the wrong person if the shopkeeper skips identity confirmation.
- Internet is required for initial account registration, first-time customer linking, new-device recovery, and sync. Existing linked ledgers continue locally when offline.
- The legal/privacy wording, retention period, and India data protection obligations need review before public launch. Target workflow: deletion requests are acknowledged immediately and processed within a defined published period; avoid setting a legal promise before review.
- Cloudflare's current free plan has finite D1 and Workers allowances. Quota exhaustion can stop cloud reads/writes; budget and load tests are required before pilot expansion.
- Play Store registration, support, optional domain, and operations may have costs even if app and cloud storage stay within free tiers.

## 10. Source references

- [Cloudflare D1 pricing and free limits](https://developers.cloudflare.com/d1/platform/pricing/)
- [Cloudflare Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/)
- [Google OpenID Connect](https://developers.google.com/identity/openid-connect/openid-connect)
- [Flutter Android documentation](https://docs.flutter.dev/platform-integration/android)

Provider limits and policies must be checked again before implementation and public launch.
