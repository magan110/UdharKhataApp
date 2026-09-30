# Udhaar Khata — Use Cases and User Stories

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [User journeys](USER-JOURNEY-USER-FLOW.md) · [PRD](PRD.md) · [SRS](SRS.md) · [QA cases](TEST-CASES-QA-CHECKLIST.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Release:** Android v1  
**Sources:** [Scope](SCOPE.md) · [Personas](USER-PERSONAS.md) · [User Flows](USER-JOURNEY-USER-FLOW.md) · [PRD](PRD.md) · [SRS](SRS.md)

## 1. Purpose and conventions

This document turns the approved product flows into work that designers, engineers and QA can review together. A **use case** describes an actor's full goal and its alternate paths. A **user story** describes a smaller capability with acceptance checks. These are requirements for a planned product; they are not claims that the application has been built.

**Priority:** P0 is essential to the core product, and P1 is part of the agreed first public release but delivered later in the phase plan. Both priorities must be complete before public launch unless [scope](SCOPE.md) is formally changed. “Server acknowledged” means committed to D1 through the Worker. “Pending” means saved only on the owner's phone.

## 2. Actors, permissions and use-case catalog

| Actor | Can do | Cannot do |
|---|---|---|
| Owner | Manage one shop, link customers, post credit/payment/correction, see own shop, resolve disputes, share/export and request deletion | See another owner's shop; post for an unlinked customer; claim a manually recorded payment was bank-verified |
| Customer | Show own QR, view own shop ledgers, report own-entry disputes, remove access/request deletion | Post or edit entries; view another customer's ledger or a shop's other customers |
| Service | Validate identity/permissions, sync entries, return scoped history and status | Treat QR possession alone as authorization |
| Operator | Perform restricted support, backup and deletion duties | Use a normal customer/owner session to bypass permissions |

| Use case | Primary actor | Goal | Priority / phase | Related PRD |
|---|---|---|---|---|
| UC-01 | Owner / Customer | Sign in and reach correct role | P0 / 0 | PR-01 |
| UC-02 | Owner | Set up one shop | P0 / 0–1 | PR-02 |
| UC-03 | Customer | Get and present personal QR | P0 / 1 | PR-03 |
| UC-04 | Owner | Scan and link a new customer | P0 / 1 | PR-04–05 |
| UC-05 | Owner | Scan linked customer and record credit | P0 / 1–2 | PR-04, PR-06, PR-09–10 |
| UC-06 | Owner | Record a payment received | P0 / 1–2 | PR-07, PR-09–10 |
| UC-07 | Owner / Customer | Review balances and entries | P0 / 1–2 | PR-08 |
| UC-08 | Owner | Sync pending entries and recover data | P0 / 2 | PR-09–10 |
| UC-09 | Owner | Correct a posted entry | P1 / 2 | PR-11 |
| UC-10 | Customer / Owner | Report and resolve a dispute | P1 / 2 | PR-12 |
| UC-11 | Owner | Set due date and share reminder | P1 / 3 | PR-13–14 |
| UC-12 | Owner | Generate statement and CSV export | P1 / 3 | PR-15 |
| UC-13 | Owner / Customer | Change language and use accessible controls | P1 / 3 | PR-16, PR-18 |
| UC-14 | Owner / Customer | Export or request deletion/remove access | P1 / 3 | PR-17 |

## 3. Detailed use cases

### UC-01 — Sign in and enter the right account

**Primary actors:** Owner or Customer.  
**Trigger:** User opens the app for the first time or after session expiry.  
**Preconditions:** Google sign-in is available; initial registration has internet.  
**Postcondition:** A verified user reaches their own role's home, with only their own cached and cloud data.

**Main path:** (1) User chooses Owner or Customer. (2) Google sign-in completes. (3) Service verifies identity and returns a session. (4) New owner goes to shop setup; existing owner goes to owner home. New customer receives QR identity and goes to My QR; returning customer reaches their own account.

**Alternates:** If sign-in is cancelled, stay on welcome. If identity verification fails, show a retryable error without creating an account. If offline and no valid previous local session exists, explain that internet is needed. If a different Google account is selected, do not display the prior account's cached ledger. The app may show authorized cached data offline after a previously verified session, but cloud actions require renewed authorization when needed.

**Acceptance:** A customer cannot reach owner functions by choosing Owner in the UI; server role and ownership are enforced. Test wrong-audience/expired identity and account switching. Maps to SRS-F-001–005.

### UC-02 — Set up one shop

**Primary actor:** Owner.  
**Trigger:** Newly signed-in owner reaches shop setup.  
**Preconditions:** Owner identity is verified online and has no active shop.  
**Postcondition:** One active shop belongs to that owner; owner can open its home screen.

**Main path:** Owner enters a nonblank shop name, reviews it and saves. Service creates the shop under the authenticated owner and app opens owner home.

**Alternates:** Blank/invalid name → explain and remain on form. Network failure → retry without creating a duplicate. Existing active shop → open existing shop rather than creating another. Different owner account → never display another owner's shop.

**Acceptance:** One owner account cannot create a second active shop in v1; the shop name and owner association survive sign-out/sign-in. Maps to SRS-F-003–004.

### UC-03 — Get and present a personal QR

**Primary actor:** Customer.  
**Trigger:** Customer finishes initial registration or opens My QR on a later visit.  
**Preconditions:** First registration was completed online and assigned a public QR identifier.  
**Postcondition:** Customer can display their current QR to a shopkeeper; showing it does not create a debt or reveal a ledger.

**Main path:** Customer opens My QR. App shows the code and a display label; customer presents it at the counter. The owner may then run UC-04 or UC-05.

**Alternates:** No initial registration → request internet and Google sign-in. Previously issued QR while offline → show cached code. QR rotated/revoked online → replace the old local code after sync; warn if current code cannot be confirmed. Wrong signed-in account → do not display another person's QR.

**Acceptance:** Decoding the QR reveals only version/format and random lookup identifier; no email, phone, balance or credential. QR can be opened offline after registration. Maps to SRS-F-006–007.

### UC-04 — Scan and link a new customer

**Primary actor:** Owner; **supporting actor:** Customer showing QR.  
**Trigger:** Customer visits the shop for the first time with their registered QR.  
**Preconditions:** Both accounts exist; owner is signed in; owner's device is online; customer's QR is active and not linked to this shop.  
**Postcondition:** Exactly one relationship exists between the shop and customer; no credit entry exists until the owner submits one.

**Main path:** (1) Owner taps Scan QR and grants camera permission if needed. (2) App reads a supported QR and requests identity lookup. (3) App shows the customer display label and **Add customer**. (4) Owner confirms the person at the counter, optionally adds a shop nickname, and confirms. (5) Service creates the unique shop/customer relationship. (6) App opens credit amount entry.

**Alternates:** Offline unknown QR → show internet-needed message, create nothing. Invalid/revoked QR → explain and offer rescan. Camera denied → explain permission and allow retry. Already linked on server → open existing ledger instead of adding again. Customer declines before confirmation → return without link or entry. Duplicate concurrent link request → return existing link.

**Acceptance:** Scanning alone never posts credit. A second owner cannot see this shop's relationship. QR carries no balance, email, phone or credential. Maps to SRS-F-006–013.

### UC-05 — Record credit for a linked customer

**Primary actor:** Owner.  
**Trigger:** Linked customer presents QR or owner opens their ledger from the customer list.  
**Preconditions:** Shop/customer link was previously verified; owner has access; amount is positive INR within the configured limit.  
**Postcondition:** One local entry exists immediately; after server acknowledgment, one authoritative entry exists and becomes visible to the customer after their sync.

**Main path:** (1) Owner scans QR or opens customer ledger. (2) App shows linked customer and credit form, even offline if link is cached. (3) Owner enters amount, optional note/due date, reviews identity and amount, and taps Submit. (4) App assigns one operation ID, saves entry and pending operation locally, updates local balance and shows status. (5) App syncs when possible; server validates ownership/link and commits once. (6) Owner sees Synced; customer later sees the entry.

**Alternates:** Invalid amount → stay on form with correction prompt. Owner cancels before Submit → no entry. Double tap or lost response → same operation ID returns one result. Temporary network/quota error → keep Pending, show Waiting to sync. Permanent permission/validation failure → retain entry as Needs attention, remove its provisional effect from any authoritative balance display or clearly distinguish it; provide help/export path. A cached but server-revoked link cannot authorize a cloud post.

**Acceptance:** ₹500 credit increases amount owed by ₹500 exactly once. Pending entry survives app restart. Server and customer never treat a merely local entry as already synced. Maps to SRS-F-014, F-016–019, F-024–027, F-030.

### UC-06 — Record a partial or full payment

**Primary actor:** Owner.  
**Trigger:** Customer pays the shop.  
**Preconditions:** Customer linked to shop; currently recorded amount owed is greater than zero.  
**Postcondition:** One payment entry reduces the amount owed exactly once after acknowledgment; manual payment method is visible.

**Main path:** (1) Owner finds customer by scan or list. (2) Chooses Payment received. (3) Enters amount not above current recorded owed balance and selects Cash or UPI. (4) Reviews customer and amount; submits. (5) App saves locally, shows sync status and later receives server acknowledgment.

**Alternates:** Zero/negative/excess amount → validation error. If offline, use locally recorded balance but mark payment Pending. If server balance changed so that pending payment would exceed it, do not silently create an advance; preserve the operation as Needs attention for review. Duplicate retry → one payment entry. No network → queue locally for the existing link.

**Acceptance:** Starting from ₹500 owed, a ₹200 payment leaves ₹300. The UI says the payment was recorded by the owner; it does not imply UPI/bank verification. Maps to SRS-F-015–019, F-024–027.

### UC-07 — Review and explain a ledger

**Primary actors:** Owner and Customer.  
**Trigger:** Either party wants to know the amount owed or review a transaction.  
**Preconditions:** The relevant shop/customer link exists; user is authorized or has a previously authorized local cache.  
**Postcondition:** User sees a scoped balance and dated history with an accurate freshness indicator.

**Main path:** Owner opens shop summary/customer ledger, or customer opens My shops and selects one shop. App shows balance with direction in words, entries in stable order, payment/correction history and last sync time where relevant. User opens a specific entry for details.

**Alternates:** No linked shops/customers → useful empty state. Offline customer → show cached last-synced ledger and timestamp. Access revoked → remove/deny private ledger view and give help route. Pagination failure → retain current page and retry without mixing shops or customers.

**Acceptance:** After both sides sync the same server version, their amount owed matches the sum of posted entries. Customer A cannot see customer B's entries; owner A cannot see owner B's shop. Maps to SRS-F-017–018, F-022, F-028.

### UC-08 — Sync and restore acknowledged records

**Primary actor:** Owner; **supporting actor:** Service.  
**Trigger:** Connectivity returns, app restarts, or user signs in on a new phone.  
**Preconditions:** For sync, a durable pending operation exists. For restore, cloud-acknowledged records exist.  
**Postcondition:** Each accepted operation exists once in D1; new phone restores only acknowledged data.

**Main path:** App sends pending operations with their original IDs, receives acknowledgments, marks them Synced and refreshes scoped data. A new phone signs in and downloads the account's server-acknowledged records. App displays last sync time.

**Alternates:** Response lost after commit → retry returns original commit. Temporary outage/quota → retain Pending and retry later. Permanent rejection → Needs attention and preserve local record. Device lost with unsynced records → explain that only acknowledged records were restored; do not claim complete recovery.

**Acceptance:** Airplane-mode ₹150 entry survives app restart and posts once after reconnection; new-phone restore contains Synced entries but not Pending entries from the lost phone. Maps to SRS-F-024–030.

### UC-09 — Correct an incorrect entry

**Primary actor:** Owner.  
**Trigger:** Owner finds an incorrect amount or accepts a customer's dispute.  
**Preconditions:** Original entry belongs to owner's shop; correction reason provided.  
**Postcondition:** Original stays intact; linked correction changes the effective balance exactly once.

**Main path:** Owner opens entry detail, chooses Correct entry, enters reason and corrected amount or cancellation, reviews balance effect and submits. App creates a new correction entry linked to original and shows both in history.

**Alternates:** Wrong shop/customer or missing original → reject. Double submission → one correction operation. Offline correction for locally available original may queue and must revalidate on sync. If prior corrections make the requested change ambiguous, show Needs attention rather than silently calculating an unexpected amount.

**Acceptance:** Correcting ₹500 credit to ₹450 produces an effective ₹450 owed and preserves the ₹500 original and reason. Ordinary users cannot delete or overwrite the original. Maps to SRS-F-020–021.

### UC-10 — Report and resolve a disputed entry

**Primary actors:** Customer, then Owner.  
**Trigger:** Customer sees a questionable synced entry.  
**Preconditions:** Customer is signed in, online and authorized to see that entry.  
**Postcondition:** A scoped dispute has visible Open or Resolved status; balance changes only if owner posts a separate correction.

**Main path:** Customer opens entry, taps Report a problem, gives a reason and submits. Owner sees dispute, reviews entry/history, and resolves with a note. If amount is wrong, owner also uses UC-09. Customer sees result after refresh.

**Alternates:** Customer offline → cached history remains visible but submission waits for internet. Entry belongs to another customer → deny. Duplicate active dispute on same entry → show existing status. Owner no longer owns shop → deny resolution.

**Acceptance:** Opening/resolving dispute leaves balance unchanged; both parties see status and any correction history. Maps to SRS-F-031–032.

### UC-11 and UC-12 — Reminder, statement and export

**Primary actor:** Owner.  
**Trigger:** Owner follows up on a balance or needs a record.  
**Preconditions:** Shop/customer link exists; owner can view ledger.  
**Postcondition:** Owner may share a reviewed reminder/statement; no message is dispatched automatically. Exports reconcile with the ledger.

**Main path:** Owner opens customer ledger. For reminder, app prepares shop/customer/current-known-balance text; owner previews, edits or cancels, then uses Android share sheet. For statement, owner chooses period and generates PDF or CSV with opening balance, dated entries, corrections and closing balance.

**Alternates:** No amount owed → reminder action may be disabled or clearly say no balance is due. Pending local entries → disclose that the amount may not yet be visible to customer. Share target unavailable/cancelled → no send claimed. Export failure → explain and retain ledger. Due-date/overdue amount is only shown after a deterministic payment-allocation rule is confirmed and tested.

**Acceptance:** Export arithmetic reconciles; owner initiates sharing; no automatic SMS/WhatsApp or payment request is sent. Maps to SRS-F-023, F-033–034.

### UC-13 — Change language and use accessible controls

**Primary actors:** Owner or Customer.  
**Trigger:** User chooses language or uses Android accessibility settings.  
**Preconditions:** App is installed; the relevant account/screen is available.  
**Postcondition:** Critical flows remain understandable and operable in English or Hindi and with assistive technology.

**Main path:** User selects English or Hindi in settings. Core screens, balance direction, errors, sync states and reminder text update. Buttons, amounts, QR description and status indicators have screen-reader labels and do not rely on color alone.

**Alternates:** A translation is missing → do not show a blank control; use a known fallback and log a localization defect before launch. Larger text or screen zoom → content can still be read and primary actions remain reachable. Camera permission denial → accessible explanation and retry route.

**Acceptance:** A user can complete sign-in, QR display/scan, credit/payment, ledger review and dispute/reminder flows in either language; critical actions are operable with a screen reader and enlarged text. Maps to SRS-F-037 and SRS-N-007–008.

### UC-14 — Remove access or request data action

**Primary actors:** Owner or Customer.  
**Trigger:** User wants an export, to stop viewing a shop, or to request account deletion.  
**Preconditions:** User is authenticated and authorized for the requested scope.  
**Postcondition:** Request is recorded with status; access and retained historical ledger are handled according to published policy.

**Main path:** Owner requests shop export or deletion; customer removes own app access to a shop or requests account deletion. App confirms the requested scope and displays request status. Restricted operator workflow processes requests under the published retention policy.

**Alternates:** User attempts another person's data action → deny. Request repeats → show existing status rather than create ambiguous duplicates. Pending offline entries → warn about recovery/export before clearing local data. Policy does not yet permit immediate historical deletion → explain what is retained and why under the final reviewed policy.

**Acceptance:** Removing customer app access does not silently erase the owner's posted entries or expose them to another account. Actual retention periods remain a launch decision. Maps to SRS-F-035–036.

## 4. User story backlog

Each story is sized as a capability to plan, refine and test. Implementation tasks may split it further. The table links to existing requirements so scope is not silently expanded.

| Story | Priority / phase | User story | Acceptance summary | Source |
|---|---|---|---|---|
| US-01 | P0 / 0 | As an owner, I want Google sign-in so my shop opens on my phone. | Verified identity; one shop; no other shop's data. | UC-01/02, PR-01/02 |
| US-02 | P0 / 0 | As a customer, I want Google sign-in so my own shop ledgers are available. | Own account only; multiple shops supported; account switch isolates cache. | UC-01, PR-01/08 |
| US-03 | P0 / 1 | As a customer, I want my QR ready at the counter so the owner can find my account. | Issued online; displays offline later; no PII/financial data in code. | UC-03, PR-03 |
| US-04 | P0 / 1 | As an owner, I want to scan a new customer's QR and add them so I can start their ledger. | Online verification; one link; clear offline/invalid error. | UC-04, PR-04/05 |
| US-05 | P0 / 1 | As an owner, I want a linked QR to open the amount form so I can record repeat credit quickly. | Online/offline cached lookup; identity displayed before Submit. | UC-05, PR-04/06 |
| US-06 | P0 / 1–2 | As an owner, I want credit and payment entries to update the amount owed accurately. | Positive paise; payment capped at owed; one effect per operation. | UC-05/06, PR-06/07 |
| US-07 | P0 / 1–2 | As an owner, I want to see each customer's history and total so I can explain balances. | Scoped shop/customer view; exact reconciliation. | UC-07, PR-08 |
| US-08 | P0 / 2 | As a customer, I want to see each shop's history so I know what I owe. | Own entries only; last sync displayed when offline. | UC-07, PR-08 |
| US-09 | P0 / 2 | As an owner, I want entries saved offline so the counter keeps moving. | Linked customer only; pending survives restart; status visible. | UC-05/08, PR-09/10 |
| US-10 | P0 / 2 | As an owner, I want sync to retry safely so a poor connection cannot double-charge a customer. | Same operation ID; one server entry; rejection retained. | UC-08, PR-10 |
| US-11 | P1 / 2 | As an owner, I want to correct an entry with a reason so history stays explainable. | Original preserved; effective balance correct. | UC-09, PR-11 |
| US-12 | P1 / 2 | As a customer, I want to report a wrong entry so the owner can review it. | Own synced entry only; Open/Resolved status; no automatic balance change. | UC-10, PR-12 |
| US-13 | P1 / 3 | As an owner, I want an optional due date so I can see when credit is expected back. | Date shown; overdue totals require validated allocation. | UC-11, PR-13 |
| US-14 | P1 / 3 | As an owner, I want to review and share a reminder so I can follow up politely. | Owner chooses to send; correct known amount; no auto-send. | UC-11, PR-14 |
| US-15 | P1 / 3 | As an owner, I want a PDF statement and CSV export so I can share and retain records. | Period totals reconcile, corrections included. | UC-12, PR-15 |
| US-16 | P1 / 3 | As either user, I want English/Hindi labels and readable controls so I understand each amount and action. | Reviewed translations, accessible labels and touch targets. | UC-13, PR-16/18 |
| US-17 | P1 / 3 | As either user, I want export/access/deletion controls so I can manage my data. | Scoped request, visible status, no silent ledger erasure. | UC-14, PR-17 |
| US-18 | P1 / 3–4 | As an operator, I want quota, sync and backup signals so I can keep the service recoverable. | Alerts and restore drill pass without leaking ledger details. | PR-18, SRS-N-005/009–012 |

## 5. Example acceptance scenarios in Given/When/Then form

| Story | Scenario |
|---|---|
| US-04 | **Given** a registered customer whose QR is not linked to this shop and the owner is online, **when** the owner scans and confirms Add customer twice, **then** one shop/customer link exists and no credit is posted until Submit. |
| US-05 | **Given** a linked customer's QR and a cached link, **when** the owner scans offline, **then** the correct amount form opens and shows the customer's identity. |
| US-06 | **Given** ₹500 owed, **when** the owner records ₹200 received and it syncs, **then** both parties see ₹300 owed and one payment entry. |
| US-09 | **Given** a linked customer and no network, **when** the owner submits ₹150 credit and restarts the app, **then** the entry remains visible as Waiting to sync. |
| US-10 | **Given** the server committed an entry but its response was lost, **when** the client retries with the original operation ID, **then** the server returns the existing result and the balance changes once. |
| US-11 | **Given** a ₹500 credit was wrong, **when** the owner corrects it to ₹450 with a reason, **then** ₹450 is effective and both original and correction remain in history. |
| US-12 | **Given** a customer disputes one of their synced entries, **when** the owner resolves it without a correction, **then** the dispute status changes but the balance does not. |
| US-15 | **Given** a period with credit, payment and correction entries, **when** the owner exports it, **then** opening balance plus signed entries equals closing balance in both PDF and CSV. |

## 6. Exceptions and unresolved rules

- **First-time customer offline:** The owner cannot link an unknown QR offline. The app explains that internet is required; no placeholder ledger is created.
- **Customer without app/Google account:** The first-release shared-ledger flow cannot onboard that person. Discovery should measure refusals before a fallback is proposed as a scope change.
- **Copied QR:** QR possession identifies an account but does not authorize a charge; owner confirms the person and amount.
- **Overpayment:** Payments above the currently recorded amount owed are rejected in v1. Advances and negative balances are later-scope items.
- **Offline payment race:** A locally valid payment may be rejected after server state changes. Preserve it as Needs attention for manual resolution; do not transform it silently.
- **Due-date allocation:** Proposed oldest-unpaid-credit-first allocation requires product confirmation before overdue totals appear.
- **Deletion and retention:** Specific timelines and re-link behavior require reviewed policy before public launch. Until then, no use case promises instant erasure of a posted shop ledger.
- **Provider limits:** Free Cloudflare capacity is finite. Quota failure preserves local pending entries for linked customers but stops first-time linking and cloud recovery until service returns or capacity changes.

## 7. Ready-for-build checklist

A story can enter implementation when its actor, preconditions, main and alternate outcomes, error message, data permission, offline behavior, acceptance checks and requirement IDs are clear. Before public release, the [SRS verification scenarios](SRS.md#9-verification-scenarios) and [Project Plan phase gates](PROJECT-PLAN-ROADMAP.md#3-work-breakdown-by-phase) must pass. Pilot discoveries that change identity, payment, retention or scope should update the [BRD](BRD.md), [PRD](PRD.md), [SRS](SRS.md) and [SES](SES.md) together.
