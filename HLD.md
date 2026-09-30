# Udhaar Khata — High-Level Design

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [SES](SES.md) · [LLD](LLD.md) · [Security requirements](SECURITY-REQUIREMENTS.md) · [Database design](DATABASE-DESIGN-ERD.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Release:** Android v1  
**Status:** D02 architecture scaffold implemented; data/identity features and deployment remain planned  
**Requirements:** [Scope](SCOPE.md) · [PRD](PRD.md) · [SRS](SRS.md)  
**Companion engineering document:** [SES](SES.md)

## 1. Architecture goal

Support a fast QR-based customer-credit ledger while preserving exact balances, cross-shop privacy and useful offline operation. The shop owner can save entries for previously linked customers without internet. Once online, the mobile app sends pending operations to a Cloudflare Worker, which validates permissions and commits them to D1. The customer sees only server-acknowledged entries after their app refreshes.

The design optimizes for a small first release: one owner account per shop, one shop per owner, customer accounts in multiple shops, INR, and no staff or bank-payment integration. The app is free to users, but D1 and Workers have finite free allowances. Capacity is measured and controlled rather than assumed unlimited.

## 2. System context and trust boundaries

```mermaid
flowchart LR
  subgraph Devices[User devices]
    OA[Owner Flutter Android app]
    OC[(Owner local SQLite)]
    CA[Customer Flutter Android app]
    CC[(Customer local SQLite cache)]
    OA <--> OC
    CA <--> CC
  end
  subgraph Cloudflare[Cloudflare account]
    W[HTTPS Worker API]
    DB[(D1 database)]
    W <--> DB
  end
  G[Google Identity]
  OA -->|Google sign-in| G
  CA -->|Google sign-in| G
  OA <-->|Authenticated API and sync| W
  CA <-->|Authenticated read and dispute API| W
  W -->|Verify Google identity during sign-in| G
```

**Boundary A — device to Worker:** The app is untrusted input. It may hold locally saved entries and a scoped cache, but it cannot assign itself a shop, customer or role. Every cloud operation passes through the Worker over HTTPS. No D1 binding or administrative credential is shipped to devices.

**Boundary B — Worker to D1:** The Worker is the sole application writer/reader of D1. It validates inputs, authenticates sessions, checks ownership and executes scoped, prepared database statements. Administrative access and backup procedures are separate from public routes.

**Boundary C — Google identity:** Google proves the signed-in account. The Worker verifies the ID token and maps Google's stable subject to an internal user ID. Email and display name remain changeable profile fields, not ownership keys. Google documents server-side validation of signature, issuer, audience and expiry. [Google OpenID Connect](https://developers.google.com/identity/openid-connect/openid-connect)

**Boundary D — QR presentation:** The customer's QR contains only a versioned, random public lookup identifier. It is neither an authentication token nor permission to post debt. A copied image can be presented by another person; the owner must verify the displayed customer identity and amount before Submit. Server permissions are checked even when the owner scanned a previously cached QR.

## 3. Logical components and ownership

| Component | Main responsibility | Owns / does not own |
|---|---|---|
| Flutter presentation | Role-specific screens, QR display/scan, transaction confirmation, status and accessible English/Hindi content | Does not decide cloud authorization or trust a QR as consent. |
| Mobile identity/session | Google sign-in, secure app-session storage, account switching | Does not store Google password or expose another account's cache. |
| Local ledger repository | SQLite cache, owner entry creation, pending outbox, last-sync cursors, customer cached read view | Owns provisional owner data; cannot claim pending data is cloud-backed up. |
| Sync coordinator | Retry, pull changes, reconcile immutable IDs and surface failed operations | Keeps same operation ID on retry; never overwrites posted history by timestamp. |
| Worker API edge | HTTPS routing, request validation, authentication, rate limits, stable errors | All app-to-D1 traffic passes through it. |
| Authorization policy | Owner shop check, customer-own-ledger check, link check, operator separation | Ignores client-supplied claims of ownership. |
| Ledger service | Link customer, post credit/payment/correction, calculate/reconcile balances, disputes | Preserves immutable entries and idempotent writes. |
| Read/export service | Paginated shop/customer views, statements and scoped export | Returns only authorized data, with freshness/version metadata. |
| D1 | Acknowledged accounts, shops, links, entries, disputes, sessions/operation outcomes and requests | Authoritative for cloud-acknowledged data. |
| Operations | Environment config, migration, monitoring, backup/restore and support | Does not rely on PDF/CSV as complete database backup. |

This is a logical decomposition. The Worker may be deployed as one service and the mobile components as modules in one Flutter application for v1. Exact packages, endpoint payloads and SQL schema belong in the later LLD, database and API documents.

## 4. Data ownership and consistency model

| Data | Source of truth | Local behavior |
|---|---|---|
| Google identity claim | Google, verified by Worker | App holds only a session scoped to the signed-in account. |
| Shop/customer link and active QR status | D1 after online verification | Owner caches verified links for offline repeat scanning; unknown link cannot be created offline. |
| Posted credit/payment/correction | D1 after acknowledgment | Owner writes a provisional entry plus outbox record locally first. |
| Owner pending entry | Owner's local SQLite only | Displayed as Waiting to sync; may be unrecoverable if device is lost. |
| Customer ledger view | D1 latest acknowledged version | Customer caches last synced view, labeled with timestamp when offline. |
| Balance | Derived from immutable entry effects or a reconciled projection | Owner may show a local balance including Pending entries, clearly distinguished from synced balance. |
| Dispute | D1 after online submit | Customer may read cached status; new dispute submission needs internet. |

Money is represented as integer paise. A credit increases owed balance, a payment decreases it, and a correction contributes a signed adjustment while preserving the original. The app never trusts a balance sent by the client as authoritative. Due dates may be stored per credit entry; aggregate overdue amounts wait until a payment-allocation rule is approved and tested.

### Consistency promise

The architecture promises an **exactly-once ledger effect per operation ID**, not exactly-once network delivery. The app may send the same operation several times; the Worker must return the first committed result for repeats. A locally pending operation is visible only in the owner's provisional view. Once D1 acknowledges it, customer and owner views converge after both clients sync the same version.

## 5. Key end-to-end flows

### 5.1 First-time customer link and credit

```mermaid
sequenceDiagram
  participant C as Customer app
  participant O as Owner app
  participant W as Worker
  participant D as D1
  C->>C: Show cached or newly issued QR
  O->>O: Scan QR
  O->>W: Resolve public QR ID
  W->>D: Look up active QR and existing shop link
  D-->>W: Customer identity and link state
  W-->>O: Minimal display identity
  O->>O: Owner confirms person and Add customer
  O->>W: Create shop-customer link
  W->>D: Insert unique link
  D-->>W: Link or existing link
  W-->>O: Linked customer
  O->>O: Review identity and amount; Submit
  O->>O: Save local pending entry
  O->>W: Post entry with operation ID
  W->>D: Validate owner/link and commit once
  D-->>W: Committed entry
  W-->>O: Acknowledgment
  O->>O: Mark Synced
  C->>W: Refresh own ledger
  W-->>C: Own acknowledged entry
```

The unknown QR lookup and link are online-only. Repeating link creation returns the existing relation. The owner can cancel before credit Submit without creating a transaction. A copied QR is not treated as proof that the account holder approved the amount.

### 5.2 Offline repeat credit or payment

1. Owner scans a QR whose customer-to-shop link is already in a verified local cache, or opens that customer's ledger from the local list.
2. App validates a positive INR amount and saves an immutable local entry and pending outbox operation together.
3. Local balance updates and the entry shows **Waiting to sync**. The customer does not yet see the entry.
4. When online, the sync coordinator sends the original operation ID. Worker rechecks owner and link permissions and commits once. It returns the committed result even after a retry caused by a lost response.
5. App marks Synced and pulls any server changes. If permission/validation prevents commit, it retains the local operation as Needs attention. An offline payment that now exceeds the server balance is not silently converted into an advance.

Cloudflare documents that D1 can be accessed from Workers through bindings and prepared statements, and that batched statements execute transactionally. The LLD will choose the exact atomic write pattern for entry plus idempotency outcome, then test it under retries and failures. [D1 Worker binding](https://developers.cloudflare.com/d1/worker-api/), [D1 batch behavior](https://developers.cloudflare.com/d1/worker-api/d1-database/)

### 5.3 Customer read and dispute

The customer signs in, requests their linked shops and one shop's history, and receives data filtered by the authenticated internal user ID. They cannot query another customer's ledger by changing an ID in a URL. Offline, they can read the last synced cache with a clear timestamp. Reporting an entry dispute requires internet and creates a separate dispute record; it does not alter the ledger balance. The owner may resolve it with a note and, if needed, post a separate correction.

### 5.4 New-device recovery

After Google sign-in on a replacement phone, the Worker returns only that user's authorized, server-acknowledged records. The UI shows a last-sync time and explains that pending entries on a lost old phone were not in D1. Operational backups serve database disaster recovery; they do not restore entries that were never synced.

## 6. Security and privacy architecture

- Verify Google ID tokens on the server using trusted keys and required claims; issue short-lived app sessions with a revocable refresh mechanism. The exact token format, lifetime and revocation storage are LLD decisions.
- Enforce authorization inside Worker services and scoped D1 queries: owner shop, linked customer, or restricted operator. Every endpoint has a documented access rule.
- Validate request type/size and use parameterized D1 statements. Rate-limit QR lookup, sign-in, disputes and exports. A random QR ID reduces guessing but does not replace rate limiting.
- Keep sessions in Android secure storage and financial cache separated by signed-in account. Clear or protect local data on account switch without discarding unresolved pending operations silently.
- Avoid collecting contacts, location, phone number or bank details in v1. Do not put transaction amounts, notes, emails, tokens or customer names in QR payloads or analytics events.
- Retain original transaction and correction history. Apply a reviewed privacy/retention policy to exports, access removal and deletion; one customer's removal from their app must not silently erase the shop's historical ledger.
- Separate production and nonproduction data, secrets and D1 bindings. Administrative access and data export are restricted and audited.

The later **Security Requirements** document will turn these boundaries into controls and verification cases. Privacy/legal wording and retention duration remain launch decisions in the [SRS](SRS.md#11-open-decisions-and-change-control).

## 7. Availability, failure and recovery

| Condition | Mobile response | Cloud/system response |
|---|---|---|
| Owner loses internet, linked customer | Save entry locally and mark Pending | No cloud claim until acknowledged. |
| Owner loses internet, unknown QR | Show internet-needed state; create no link | No unverified customer record. |
| Worker/D1 temporary error or quota | Keep existing linked entries Pending; show last sync and retry path | Return stable retryable error; monitor and apply capacity response. |
| Server rejects old link or invalid operation | Keep local record as Needs attention, without presenting it as posted | Do not alter authoritative ledger; return scoped reason code. |
| App crashes after local save | Restore outbox and entry from SQLite on restart | Retry original operation ID. |
| Server commits but response is lost | Retry with same operation ID | Return original committed result, with one balance effect. |
| Phone lost before sync | New device restores acknowledged records only | D1 has no copy of unsynced records. |
| D1 corruption/accidental deletion | Pause affected writes, communicate impact | Restore from tested encrypted operational backup to a separate environment, reconcile before resuming. |

No deployment topology can guarantee recovery of data that never left a lost device. The app must make that limit visible rather than hide it in policy text.

## 8. Scale, quota and performance approach

Cloudflare's current Workers Free D1 allowance lists **5 GB total storage, 5 million rows read per day and 100,000 rows written per day**. Workers have separate usage limits. D1 read and write billing counts rows examined/written, and indexes affect row operations and storage. On the free plan, reaching a daily D1 limit causes D1 queries to fail until reset; reaching storage limit blocks new writes. These are current provider facts, not a product promise. [D1 pricing and limit behavior](https://developers.cloudflare.com/d1/platform/pricing/), [Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/)

Design responses:

- Index common scoped lookups (owner shop, QR ID, shop/customer history, idempotency ID), paginate ledger history, and avoid full table scans on home refresh.
- Batch bounded sync operations and use incremental cursors; do not fetch all history on every app open.
- Observe Worker request count/error rate and D1 rows read/written/storage; set warning thresholds before the free limits. Logs exclude financial content and tokens.
- If quota pressure rises, reduce nonessential reads, pause new onboarding and make local Pending status explicit. Decide funding/capacity before wide public growth.
- Benchmark real pilot patterns rather than estimate viability solely from stored row size; indexes and usage volume matter.

Core owner screens should render from local data without waiting for network. The product's pilot target is a median under 15 seconds from successful linked scan to local save on supported test phones; actual hardware and measurement method must be specified in the pilot.

## 9. Deployment environments and operations

| Environment | Purpose | Data policy |
|---|---|---|
| Local development | Engineer feedback and schema/API tests | Synthetic records only. |
| Staging | Integrated Google sign-in, Worker/D1, Android test builds and recovery rehearsal | Synthetic or consented test data; separate identities/secrets/bindings from production. |
| Production | Pilot and public app after gates | Real financial data, restricted access, monitoring and operational backups. |

Deploy schema changes through versioned migrations, then compatible Worker changes, then app releases that can handle server versions during rollout. Keep an incident/rollback plan for API and schema changes; restoring or reversing a migration involving financial records requires a tested procedure. Production deployment and public release require separate approval under the workspace's external-action boundary.

## 10. Architecture decisions and deferred detail

| Decision | Rationale | To specify next |
|---|---|---|
| Flutter Android + SQLite | One Android codebase with local durable storage for offline use | Local schema, package choice, account cache boundaries in LLD. |
| Worker as sole D1 gateway | Central validation, permissions and controlled cloud access | API contracts, auth/session lifecycle and rate limits. |
| Immutable ledger plus correction entries | Reconstructable balances and disagreement history | Exact signed-entry schema, correction constraints and balance queries. |
| Operation-ID idempotency | Safe retries across network loss | Unique constraints, transaction/batch sequence, response replay retention. |
| QR lookup ID, not secret | Simple customer-presented identity flow without financial data in code | QR format/rotation, cache treatment and abuse controls. |
| Owner local-first writes | Counter continues without internet | Outbox state machine, sync order and conflict response. |
| Customer read cache | History available offline with freshness label | Cache invalidation and access-removal behavior. |

The next **LLD**, **Database Design / ERD** and **API Specification** should make these interfaces and constraints concrete without changing the approved [PRD](PRD.md) and [SRS](SRS.md). Open product decisions—payment allocation for overdue totals, exact input bounds, retention period, backup destination and supported Android versions—remain visible in those documents rather than being silently invented here.

## 11. References

- [Cloudflare D1 Worker binding API](https://developers.cloudflare.com/d1/worker-api/)
- [Cloudflare D1 database methods and batch semantics](https://developers.cloudflare.com/d1/worker-api/d1-database/)
- [Cloudflare D1 pricing and free-tier behavior](https://developers.cloudflare.com/d1/platform/pricing/)
- [Cloudflare Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/)
- [Google OpenID Connect token validation](https://developers.google.com/identity/openid-connect/openid-connect)

Provider terms and API behavior should be checked again before implementation and launch.
