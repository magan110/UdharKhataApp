# Udhaar Khata — Security Requirements

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [SRS](SRS.md) · [API specification](API-SPECIFICATION.md) · [Database design](DATABASE-DESIGN-ERD.md) · [Test plan](TEST-PLAN.md) · [Deployment runbook](DEPLOYMENT-RUNBOOK.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Release:** Android v1  
**Status:** Requirements and release gates; D01-D04 local controls and tests exist, live OAuth and release gates remain pending  
**Baseline:** [SRS](SRS.md) · [HLD](HLD.md) · [LLD](LLD.md) · [Database Design / ERD](DATABASE-DESIGN-ERD.md) · [API Specification](API-SPECIFICATION.md)

## 1. Security objective and scope

Udhaar Khata stores personally identifiable account data and a two-sided credit ledger. A shop owner may create credit, manually record received cash/UPI payments and correct their own shop's entries. A customer may view only their own linked ledgers and dispute an acknowledged entry. A QR code identifies an account for lookup; it is **not** proof of the person presenting it and grants no permission by itself. Cloudflare D1 holds acknowledged records; an owner's offline Pending entries live only on that phone until sync.

This document defines controls that the Flutter Android app, Cloudflare Worker API, D1 schema and operations **shall** satisfy before public use. Each `SEC-` requirement has an observable check. This is a design specification, not a claim of certification or a substitute for privacy/legal review. There is no payment gateway or bank verification in v1; “UPI payment” means **owner-entered record of payment received**, not a verified transfer.

### 1.1 Assets and trust boundaries

| Asset | Sensitivity | Boundary and primary risk |
|---|---|---|
| Google identity token and app session tokens | Critical | Untrusted device → Worker; theft enables account access. |
| D1 account, shop, customer, ledger and dispute data | High | Worker → D1; missing scope check leaks or changes another ledger. |
| Owner SQLite outbox and cached ledger | High | Android app-private storage; lost/stolen phone or account switch exposes data or loses Pending entries. |
| Customer public QR ID | Moderate | Publicly displayed lookup value; copying/guessing can enable enumeration or impersonation at counter. |
| Statement exports and operational backups | High | Files leaving app/server boundary; accidental sharing or broad admin access exposes financial history. |
| Cloudflare bindings, signing keys and Google OAuth configuration | Critical | Build/deploy boundary; leaked or mixed-environment secrets compromise many accounts. |

The app is never a trusted source of role, shop ownership, customer identity, balance, “payment verified” status or server time. The Worker authorizes every request using verified session identity and scoped database queries. Local validation improves usability but never replaces server checks.

## 2. Threat model and control map

| Threat | Attack example | Required control | Proof |
|---|---|---|---|
| Stolen or forged identity token | Modified issuer/audience, expired token, substituted subject | Verify Google token cryptography and claims on Worker; stable `sub` account mapping | SEC-01/02 tests |
| Broken object authorization | Customer changes shop/entry ID; owner changes another owner's shop ID | Role + ownership/link check on every route and DB query | SEC-05 matrix |
| Copied QR at counter | Attacker shows someone else's QR screenshot | QR only looks up; owner sees identity and amount before Submit; no scan-only charge | SEC-06 UX/API tests |
| QR enumeration | Repeated random/known ID lookup | 128-bit+ random ID, minimal lookup response, layered rate limit, redacted logs | SEC-07 load/abuse test |
| Duplicate or reordered write | Lost response causes resubmit; two payments race | Stable operation ID/hash, D1 uniqueness and atomic balance/revision guards | SEC-08/09 concurrency test |
| SQL/CSV injection | Malformed note, QR, cursor or export cell | Strict schema, prepared SQL, encoded output and safe CSV rendering | SEC-10/11 tests |
| Session or local-data theft | Token in logs/backup; old account cache visible after switch | Secure storage, backup exclusions, account-scoped cache and revocation | SEC-03/04/12 tests |
| Data loss | Phone lost while entries Pending; D1 restore missing receipts | Visible Pending boundary, durable outbox, encrypted operational backup/restore | SEC-13/17 drills |
| Insider/admin misuse | Broad production D1 access or export | Least privilege, separate environments, audit and dual review for sensitive recovery | SEC-16/18 evidence |
| Denial of service/free-tier exhaustion | Repeated QR/export requests consume D1 rows or Worker quota | Edge/app rate controls, bounded queries, quotas and incident mode | SEC-15 test |

## 3. Identity and session requirements

| ID | Requirement | Verification |
|---|---|
| **SEC-01** | The Worker shall verify each Google ID token's signature against trusted Google keys, permitted issuer, configured audience, expiration and nonempty subject before creating an app session. Reject altered, expired, wrong-audience and wrong-issuer tokens. The Google `tokeninfo` endpoint is a debugging aid, not production validation. | Automated token negative cases; inspect verifier and key-cache configuration. |
| **SEC-02** | `google_sub` shall be the immutable account key. Email/display name are editable profile attributes, never authorization keys. A first-registration role is fixed to owner or customer in v1; a later `requestedRole` cannot promote or switch it. | Change email/name and retain same ledger; attempt role switch. |
| **SEC-03** | App access tokens shall be short lived; v1 lifetime **15 minutes**. Refresh tokens shall be at least 256 bits of CSPRNG entropy, stored only as a keyed or cryptographic hash in D1, rotated on use, bound to one server session ID, and expire within **30 days maximum** from initial issue. Logout/account deletion shall revoke session state. D04 fixes these lifetimes; refresh rotation never extends initial expiry. | Inspect token claims/entropy, DB rows and expiry; replay old refresh token; revoke then call protected route. |
| **SEC-04** | App tokens are bearer credentials. The Worker shall verify the opaque access credential against its stored hash, expiry and referenced session revocation on protected financial routes; it shall not trust a client `deviceId` as hardware proof. On lost refresh response or revoked session, require Google reauthentication without deleting the offline outbox. | Replay/logout/revocation tests; network-loss test during refresh. |

The implementation plan selects short-lived opaque access credentials backed by hashed `access_sessions` rows linked to rotating hashed `refresh_sessions`. D03 creates those tables; D04 implements verification, expiry, rotation and referenced-session revocation checks. Credentials must have cryptographic entropy and never appear in SQLite or logs. D04 fixes access at 15 minutes and refresh at 30 days from initial issue; spent-token replay revokes the whole session. Trusted Google JWKS are cached for at most one hour with a five-second fetch timeout. A session's `deviceId` is an app-generated identifier for user-facing session management; it is not an authentication factor.

Google recommends server validation of tokens and use of `sub` rather than email as the durable identifier. [Google OpenID Connect guidance](https://developers.google.com/identity/openid-connect/openid-connect)

## 4. Authorization and QR requirements

| ID | Requirement | Verification |
|---|---|
| **SEC-05** | Every protected route shall authorize using authenticated internal user ID and current role/relationship. Owner routes require active ownership of `{shopId}` and correct shop/link association. Customer routes derive customer ID from session and permit only their active linked shop and entries. The Worker shall check again at sync commit; stale local links do not grant cloud access. | Route-by-route matrix with two owners, two customers and shared customer in two shops; modified path/body IDs all denied. |
| **SEC-06** | Scanning a QR shall never create a link or financial entry. Link and ledger commands require separate authenticated owner action; UI shall show customer identity, amount and debt direction before Submit. A copied QR cannot serve as an authorization credential. | Scan without Submit; copied QR; inspect request trace and UI. |
| **SEC-07** | Customer QR shall contain only version and a random public lookup ID with at least 128 bits entropy. First link requires online active-ID resolution. Rotation revokes old ID for new links but preserves existing internal links. Lookup returns only the minimum display label and linked/new state after owner/shop authorization; invalid/revoked/unknown responses shall not expose account details. | Decode QR; brute-force/rate-limit simulation; rotate and test old/new link behavior. |
| **SEC-08** | Link uniqueness and ledger idempotency shall be enforced by D1 constraints and transactional receipts. Same `(shopId, clientOperationId)` and canonical payload must replay the original result; a different payload must conflict. Receipts must survive for the supported retry lifetime. | Lost response, double tap, concurrent same-ID and changed-body tests; inspect one ledger effect. |
| **SEC-09** | Payment and correction guards shall execute atomically with ledger commit. A payment may not overdraw the authoritative balance. A correction requires matching original ledger, target kind and expected revision and cannot make balance negative. Posted rows are immutable through normal API routes. | Concurrent payment/correction tests on D1, rollback and reconciliation checks. |

The access matrix is normative:

| Action | Shop owner | Linked customer | Other authenticated user |
|---|---|---|---|
| View all customers or shop export | Own shop only | No | No |
| View one ledger and balance | Own shop only | Own link only | No |
| Resolve QR/link customer | Own shop, online | No | No |
| Post credit/payment/correction | Own shop + active link | No | No |
| File dispute | Read/respond for own shop | Own acknowledged entry | No |
| Rotate QR | No | Own QR only | No |
| Request shop deletion | Own shop only | No | No |
| Request account deletion/access removal | Own account; shop policy applies | Own account/link | No |

Database foreign keys protect relationships but do not replace application authorization. The Worker shall filter every read by authorized shop/link. Cross-tenant denial responses must not distinguish nonexistent from inaccessible records in a way that reveals private identity or balances.

## 5. Input, output and transport requirements

| ID | Requirement | Verification |
|---|---|
| **SEC-10** | Worker shall validate method, content type, body size, JSON shape, field types, integer money bounds, date format, QR version, UUID operation ID and cursor signature/route scope before database use. Mutations reject unknown fields. No `NaN`, decimal, negative or overflow money value is accepted. | Fuzz malformed JSON, huge body, wrong types, Unicode edge cases, invalid dates and unsafe integer values. |
| **SEC-11** | All D1 access shall use bound parameters or fixed SQL. Never concatenate IDs, sort keys or user text into a query. Notes/reasons shall be rendered as text in Flutter and escaped in PDF/HTML contexts. CSV exports shall mitigate spreadsheet formula injection while preserving an auditable raw-data option if required by the export policy. | Static SQL review; injection payload tests through note, nickname, reason, QR and cursor; open CSV in spreadsheet test. |
| **SEC-12** | All app API traffic shall use HTTPS with normal certificate validation; Android cleartext traffic shall be disabled in release builds. No token or sensitive data in query strings. Financial API responses and exports shall carry `Cache-Control: no-store`; no broad CORS wildcard for credentialed requests. | Release manifest/network config inspection; proxy/network trace; response-header tests. |

For v1's native app bearer-token API, browser cookie-based CSRF controls do not apply because authentication is not carried automatically in cookies. If a future web app adds cookies, it must add a CSRF design and same-site cookie policy before launch. Flutter does not render arbitrary HTML from notes; if future screens do, context-specific escaping is required. Camera QR parser must reject unsupported URI schemes, extra parameters and oversized payloads without launching untrusted links.

## 6. Android local data and export requirements

| ID | Requirement | Verification |
|---|---|
| **SEC-13** | Session credentials shall live in Android secure storage backed by platform key facilities, not SQLite or ordinary preferences. The account-scoped SQLite database and outbox shall be app-private; release build shall exclude tokens, local ledger and outbox from Android Auto Backup and device-transfer rules unless a separately reviewed encrypted recovery design is adopted. | Inspect storage code, manifest/backup XML for supported API levels; backup/restore drill; file-access test. |
| **SEC-14** | Account switch/sign-out shall lock the previous account's cache and prevent account B seeing it. Unresolved Pending entries must be counted and preserved or explicitly exported/recovered after user choice; never silently deleted. On a lost phone, a new phone restores only acknowledged D1 records and explains the Pending limit. | Two-account device test, forced crash/restart and new-phone drill. |

D03 adds app-private account-isolated sqflite and disables Android backup with `allowBackup=false`, `fullBackupContent=false` and Android 12+ cloud/device-transfer exclusions. Host SQLite tests prove account locking and outbox durability; device backup/extraction and SQLCipher review remain D04/D12 gates. D03 SQL ceilings are safe integer money, 120-character labels, 500-character notes/reasons, canonical operation UUIDs and real calendar dates; smaller business amount limits remain D08 work.

Android app-private storage protects against ordinary other-app access but not all compromised-device cases; use device encryption and a reviewed local database encryption decision for the financial cache. Do not copy SQLite into public/external storage. Keep exports in app-private temporary storage until the owner deliberately shares them; apply short cleanup after share or cancellation. A user-visible share target can receive a statement by deliberate choice, so the preview must show the intended shop/customer, period and sensitivity. The app requests camera permission only when scanning and no contacts/location/phone permission in v1. Android documents app-private storage and backup exclusions: [Android security checklist](https://developer.android.com/privacy-and-security/security-tips), [Auto Backup rules](https://developer.android.com/identity/data/autobackup).

## 7. Abuse limits, privacy and operations

| ID | Requirement | Verification |
|---|---|
| **SEC-15** | Rate-limit all public routes, with stronger per-account and per-network limits for auth exchange, QR lookup, dispute creation, export and data requests. Bound page size, export period, sync batch and response body. Return 429 with `Retry-After` where possible; owner outbox keeps the same operation ID. Limits must be measured against real counter traffic and Cloudflare free quotas before pilot. | Load/abuse tests; check legitimate shared-network users; quota incident rehearsal. |
| **SEC-16** | Production Worker secrets/signing keys shall use Cloudflare secret bindings; D1 uses a Worker binding. No secret in source, mobile binary, Wrangler plaintext `vars`, logs, CI output or committed `.env`/`.dev.vars`. Separate production/staging OAuth clients, Worker routes, bindings, D1 databases, keys and backups. | Secret scan of repository/build artifact/history; deployment config review; staging/prod isolation test. |
| **SEC-17** | A production-like D1 dataset shall be backed up through an approved encrypted process and restored into an isolated environment before public launch. Restore must preserve account/link IDs, ledger entries, correction history and idempotency receipts; reconcile per-link entry sums to balances. Pending device-only entries are outside D1 backup scope and must be disclosed. | Dated restore drill with counts, foreign-key check, balance and receipt replay results. |
| **SEC-18** | Administrative access to D1, exports, deployments and backup keys shall be limited to named operators with MFA and least privilege. Sensitive data access and destructive maintenance shall be recorded with actor, time, reason and request/change ID. Separate approval/review is required for production data export or deletion. | Access roster and audit sample; revoke a departed operator; review one simulated maintenance change. |
| **SEC-19** | Routine logs, analytics and crash reports shall exclude tokens, Google `sub`, QR IDs, full names, notes, reasons, amounts and statement bodies. Use request ID, route template, status/error class, latency, D1 usage and coarse sync state. Error responses shall omit stack traces and other tenants' data. | Inspect sampled traces/crash reports with synthetic sensitive values; test redaction. |
| **SEC-20** | Publish a privacy notice and retention/deletion policy before public launch, including Google identity data, ledger visibility, customer access removal, disputes, backups, export handling and support access. No contacts scraping, automatic messaging, bank collection or hidden payment verification. | Approved policy text matched against actual app behavior, data inventory and request workflow. |

Proposed starting rate limits for pilot tuning are **10 auth exchanges per 10 minutes per network**, **30 QR lookups per minute per owner plus network abuse control**, **60 financial commands per minute per owner**, **5 disputes per customer per day**, and **5 exports per owner per day**. They are operational hypotheses, not fixed product promises; tune using measured traffic and false-positive tests. A shared shop Wi-Fi must not cause unjustified lockout. Protect quota with bounded D1 work per request and edge controls where available. If quota is exhausted, existing linked owner writes remain locally Pending and are visibly not backed up; new QR linking cannot proceed.

Cloudflare documents secret bindings and D1 encryption at rest/in transit. These provider properties do not replace access control, backup testing or device security. [Cloudflare Workers secrets](https://developers.cloudflare.com/workers/configuration/secrets/), [D1 data security](https://developers.cloudflare.com/d1/reference/data-security/).

## 8. Required security tests and release gates

| Gate | Minimum evidence before real-user pilot/public release |
|---|---|
| Identity | Valid Google sign-in; invalid signature/issuer/audience/expiry rejected; immutable `sub` mapping; role-switch attempt denied. |
| Session | Access expiry, refresh rotation/replay, logout/revocation, lost refresh response and account switch tested. |
| Authorization | Every route exercised with owner A/B and customer A/B; cross-shop and cross-customer reads/writes denied without information leakage. |
| Ledger integrity | Concurrent duplicate, payment race, correction race, rollback, idempotency receipt retention and sum/projection reconciliation pass on D1. |
| Device | Release artifact has no embedded secrets or cleartext traffic; Auto Backup exclusions, secure credential storage and local account isolation verified. |
| Privacy | QR payload, logs, analytics, export temp files and share preview inspected with synthetic sensitive data; policy and deletion workflow approved. |
| Resilience | Offline outbox survives restart; quota failure keeps Pending; lost-phone/new-phone boundary displayed; encrypted backup restore succeeds. |
| Supply chain | Locked dependencies and CI audit/scans reviewed; high-severity findings triaged before release; Android signing key access restricted. |
| Operations | Production/staging separation, MFA/least-privilege roster, rate-limit thresholds and incident contact/runbook approved. |

No automated test can prove all security properties. A manual pre-release review should inspect the implemented request pipeline, generated Android manifest, D1 migrations/triggers, production Cloudflare bindings and a complete owner/customer journey. Fail any gate that shows cross-tenant access, duplicate/incorrect balance, secret exposure, silent loss of Pending data or untested recovery.

## 9. Decisions requiring sign-off

| Decision | Owner and deadline |
|---|---|
| Final access/refresh lifetimes, signing algorithm/key rotation, rate-limit thresholds and local database encryption | Engineering security review in phase 0, before pilot. |
| Exact input caps and supported Android versions | Product/engineering review in phase 0. |
| Retention period, access-removal/relink semantics, deletion process and public policy wording | Product/privacy/legal review before public launch. |
| Backup destination, encryption-key custody, frequency, restore time objective and operator access | Operations/security review before any real user data. |
| Pending-entry inclusion in any owner export and secure delivery of full shop data | Product/privacy review before phase-3 export release. |

If a decision changes an API payload, database invariant or user-visible guarantee, update the [API Specification](API-SPECIFICATION.md), [Database Design / ERD](DATABASE-DESIGN-ERD.md), [SRS](SRS.md) and [PRD](PRD.md) together. The next document, **Coding Standards / Development Guidelines**, translates these requirements into implementation and review rules.

### D04 local protection decision

Credentials use flutter_secure_storage 11.2.0 with Android platform defaults and reset-on-error disabled. Existing backup exclusions remain. SQLite stays app-private rather than SQLCipher-encrypted; host tests prove account isolation and Pending preservation, while physical extraction/compromised-device review and any encryption rollout remain D12 release gates. No protection against a compromised unlocked device is claimed. The auth adapter locks the cache before switching/restoring and opens it after server profile verification. Uncertain refresh removes credentials and requires reauthentication while preserving the database.

### D06 implementation checkpoint

Customer QR uses exactly `udhaar://customer/v1/{publicId}` with a 256-bit random lowercase hex lookup ID and no personal, financial or credential fields. Own-QR read and online rotation enforce the customer session. Rotation revokes the old mapping atomically, preserves internal links and permits at most three attempts per customer per ten minutes. The customer screen renders a readable QR with account label and explains that it does not authorize payment. Account-specific secure-storage cache labels saved codes as unverified; uncertain rotation persists a recovery marker and hides the old code until online confirmation. Offline presentation works in an already verified open session, even if an attempted auth renewal fails: credentials are discarded and the account database is locked, while only the cached public QR remains with a Sign in again action. This confers no cloud or ledger authorization. Failed rotations retain an explicit failure notice after recovering the current QR. Full offline session restoration after cold startup remains D12. D07 owner resolution/linking and physical-device QR scanning remain separate gates. Synthetic authorization/rotation/cache/UI and independent rendered-image decoding evidence is recorded in implementation progress.


### D07 implementation checkpoint

Owner scanning accepts only the bounded exact `udhaar://customer/v1/{publicId}` format, requests camera permission only on scan, and provides permission retry/settings and invalid/version/revoked/internet-needed states. An online lookup authorizes the shop before displaying minimal customer identity and makes no link or financial change. Explicit Add customer creates one active relationship using an atomic, scoped D1 batch and operation receipt; same-ID/body retries replay, changed bodies conflict, and concurrent different IDs for the same shop/customer return the existing link. Live QR/ownership/customer predicates are checked at commit. Removed access is not restored by scanning. Original confirmed command bodies are saved in account/shop-specific secure storage before POST and retained after response loss/restart; new scans cannot replace an unresolved confirmation. The bounded customer list states overflow and returning customers open an authorized ledger screen. Credit/payment/history and complete pagination remain D08-D10; owner offline cache/sync remain later gates. Physical camera/device and remote D07 deployment evidence are recorded separately in implementation progress.

### D08 online credit implementation contract (2026-10-01)

Approved pilot limits v1: positive credit ₹0.01–₹1,00,000.00 (1–10,000,000 integer paise), optional trimmed note up to 500 UTF-16 code units, valid optional YYYY-MM-DD due date, financial JSON body at most 4,096 bytes, and existing first-100 list ceiling. General JSON/auth bodies retain the 65,536-byte ceiling. The Worker validates strict credit fields and canonical UUID v4 operation identity; unknown/forged effect fields and payment/correction variants are rejected in D08. A first online command accepts device occurrence time from 24 hours before server time to 5 minutes ahead. Receipt replay precedes this mutable clock check. Payments, corrections, full history/pagination and offline local ledger remain their later phases.

The owner opens a linked customer, enters amount/note/date, reviews customer identity and the explicit Customer owes you direction, then confirms. Review has no financial effect. The app durably saves an account/shop/link-specific command before POST and never generates a replacement ID after uncertainty. Reopening the form recovers that body with Check same credit; a response must match shop, link, type, amount/effect, note/date, occurrence time and sequence before acknowledgement. Unverified responses, storage failures, auth/network failure and rejected requests retain the saved record for recovery; it is not silently discarded. This online recovery record is not the D11 offline ledger/outbox, and does not provisionally change the visible balance.

The Worker uses the existing immutable ledger triggers and atomic entry-plus-receipt batch; live authorization is rechecked at commit and replay requires current access. Receipt retries return the original committed balance/version even after later entries, explicitly labeled as the balance when this credit was recorded. Owner link/list reads refresh the current balance. Customer My shops receives its own active link balances/versions from the same profile query and can refresh them. New minimal balance reads authorize the entire current snapshot in one SQL query; no history page or aggregate overdue total is inferred. No new migration is needed.

### D09 payment security checkpoint (2026-10-01)

Strict authenticated owner payment commands enforce active shop/link access both before posting and in D1 commit triggers. The server derives the negative effect, checks authoritative balance atomically and writes entry/projection/success receipt together. Retries require current access and original payload hash, including Cash/UPI method; changed method conflicts. Balance rejection details are read only after fresh relationship authorization. Customer writes and cross-shop requests are denied. Financial fields are not added to telemetry.

Account/shop/link-specific secure-storage recovery retains immutable uncertain commands and verified rejections. Explicit correction archives the rejected original before opening another draft. A shared serial repository prevents credit/payment replacing each other's active confirmation. D09 adds no credentials, OAuth changes, migration or bank-verification integration. Device extraction/backup and the general encrypted offline outbox remain their existing later gates.

### D10 online history checkpoint (2 October 2026)

D10 rechecks account/role/shop/link access on every page and inside scoped D1 reads. Customer shop/history routes derive identity from the session and reject unknown customer-ID query parameters. Encrypted authenticated cursors bind version, account/role/route/shop/link, high-water, position and one-hour expiry. Tampering, cross-scope reuse, expiry and key rotation are tested; cursors contain no names, notes or amounts and are not logged. D1 cursor key access is limited to Worker/admin boundaries; it is never returned. Mobile suppresses old-account in-flight results, rejects inconsistent scope/effects/mixed snapshots, and clears displayed records on permission loss. Key generation is a local-tested D1 migration change; remote application still needs explicit approval.


### D11 local ledger/outbox checkpoint (2 October 2026)

D11 retains app-private account SQLite, secure-storage credentials and Android backup exclusions. Only complete server-authorized owner snapshots admit offline saves; a cached QR or arbitrary link ID creates no authority. Save rechecks verified owner role, active link and expected shop atomically. Explicit forbidden/not-found refresh marks the cached link inaccessible while preserving its pending money/outbox. Auth uncertainty locks the database through the existing adapter. Stale or replacement-account UI responses are discarded. Unresolved legacy financial requests remain protected from replacement. Canonical payload and account/shop-bound SHA-256 hash are local integrity data, not a server receipt/authentication token. No real customer records, new credentials or remote changes were used for local verification. Compromised-device/SQLCipher review, offline session policy and physical-device backup drills remain D12/release gates.

### D12 incremental-feed and event-time policy (local implementation)

The owner sync feed exposes operation IDs only after current owner/shop/link authorization, repeated on continuation. Authenticated cursors bind account, role, distinct route, shop/link and fixed high-water; metadata/aggregates/page queries run in one authorized D1 batch. Customer history remains acknowledged-only and does not gain operation IDs. Logs exclude bodies and cursor query strings.

The D08 24-hour past-age cap is superseded for first credit/payment posts so legitimate durable offline commands can commit without rewriting their original body. Nonnegative safe-integer occurrence time is accepted through server now plus five minutes. It is untrusted descriptive data, never authority for role, balance, idempotency or posting order. Existing hashes and receipt-before-clock replay are unchanged. These local Worker changes are not deployed; offline grant/session implementation and device extraction review remain pending.
