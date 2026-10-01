# Udhaar Khata — API Specification

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [SRS](SRS.md) · [LLD](LLD.md) · [Database design](DATABASE-DESIGN-ERD.md) · [Security requirements](SECURITY-REQUIREMENTS.md) · [QA cases](TEST-CASES-QA-CHECKLIST.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Release:** Android v1  
**Status:** D02 request-edge scaffold implemented locally; identity and domain endpoints remain planned  
**Baseline:** [SRS](SRS.md) · [SES](SES.md) · [LLD](LLD.md) · [Database Design / ERD](DATABASE-DESIGN-ERD.md)

## 1. Contract and conventions

The Flutter app calls a versioned Cloudflare Worker over HTTPS. The Worker is the only public route to D1. Paths begin with `/v1`. JSON uses `camelCase`; IDs are opaque strings; money is integer **paise** in INR. A field ending `AtMs` is a UTC Unix millisecond integer. `dueDate` is an ISO calendar date (`YYYY-MM-DD`) without a timezone. There are no floating-point rupee amounts in requests or responses.

Protected routes require `Authorization: Bearer <accessToken>`. JSON requests require `Content-Type: application/json`; responses use `application/json; charset=utf-8` except exports. Every response includes `X-Request-Id`, which support may ask for. Financial responses should use `Cache-Control: no-store`; credentials must never appear in URLs, QR payloads, logs or analytics. The app must display server-acknowledged balance separately from local Pending entries.

The schemas below are the intended v1 wire contract. D03 storage ceilings are recorded in the database design: safe integer paise, 120-character labels, 500-character notes/reasons, 128-character device IDs, canonical UUID v4 operation IDs and valid calendar dates. The smaller business amount cap, page-size ceiling, export period remain unresolved [SRS decisions](SRS.md#11-open-decisions-and-change-control). They must become versioned constants before pilot; the Worker must reject values over them. Until then, the examples show format rather than permission to submit arbitrary large values. Unknown JSON properties are rejected on mutation routes so misspelled financial fields cannot be silently ignored. Missing optional fields and explicit `null` are normalized consistently before request hashing.

### 1.1 Success and error envelopes

Single-resource success:

```json
{ "data": { "id": "ent_01..." }, "requestId": "req_01..." }
```

Paged success:

```json
{
  "data": [ { "id": "ent_01..." } ],
  "page": { "nextCursor": "opaque-token-or-null", "hasMore": false },
  "requestId": "req_01..."
}
```

Error:

```json
{
  "error": {
    "code": "BALANCE_CONFLICT",
    "messageKey": "ledger.paymentExceedsBalance",
    "retryable": false,
    "details": { "currentBalancePaise": 30000 }
  },
  "requestId": "req_01..."
}
```

`messageKey` is for English/Hindi client localization; it is not a trusted English sentence. `details` is optional, bounded and scoped to the authorized caller. No error reveals whether another shop/customer's private record exists. A generic 404 may be used instead of 403 for inaccessible resources. Validation errors use field names, never submitted values. The mobile app retains the original local command after any uncertain network outcome.

### 1.2 Shared types

| Type | Fields and meaning |
|---|---|
| `Account` | `id`, `role: owner\|customer`, `displayName`, optional `email`, `createdAtMs`. Email/name are informational, not authorization keys. |
| `Shop` | `id`, `name`, `status`, `createdAtMs`; owner routes may include `ownerUserId`. |
| `Link` | `id`, `shopId`, `customerUserId`, `customerDisplayName`, optional `shopNickname`, `status`, `linkedAtMs`, `balancePaise`, `ledgerVersion`. Owner only; customer routes omit other customers. |
| `LedgerEntry` | `id`, `serverSeq`, `shopId`, `linkId`, `kind`, `amountPaise` (originals), `targetAmountPaise` (corrections), `effectPaise`, `note`, `paymentMethod`, `dueDate`, `correctsEntryId`, `revision` (correction target revision after commit), `correctionReason`, `occurredAtMs`, `createdAtMs`, `createdByUserId`. Nullable fields are consistently `null` when absent. |
| `Balance` | `balancePaise`, `ledgerVersion`, `asOfServerSeq`, `asOfAtMs`. This is acknowledged cloud state only. |
| `Dispute` | `id`, `entryId`, `linkId`, `status: open\|resolved`, `reason`, optional `ownerNote`, `createdAtMs`, optional `resolvedAtMs`. |

Owner list and ledger responses must remain scoped even if a caller edits a path ID. Customer identity is always derived from the session. A QR public ID is a lookup key only and never grants ledger access or write permission.

## 2. Authentication and account routes

### D04 implementation status

`GET /health` is an unversioned liveness route returning only `{ "data": { "status": "ok" }, "requestId": "..." }`. It does not test D1 readiness. D04 implements Google exchange, refresh, logout and profile routes with a D1 binding and approved Google audience. An unconfigured audience fails closed with `503 FEATURE_UNAVAILABLE`. Live OAuth and Worker deployment remain pending; synthetic identity/session tests run locally.

The D02 edge caps JSON bodies at **65,536 bytes**, measured while reading streams as well as against declared size; the auth token field is capped at **16,384 characters**. Shared ID syntax is alphanumeric/underscore/hyphen, at most 128 characters, beginning alphanumeric; cursors are bounded base64url strings of at most 2,048 characters. Cursor signing and route scope enforcement arrive with D10. Money and UTC timestamps use safe integers; timestamps are nonnegative. These wire bounds are shared in [fixtures](contracts/d02-fixtures.json); financial entry caps and other product limits are still due in their planned phases.

| Method and path | Auth | Request | Success | Main failures |
|---|---|---|---|---|
| `POST /v1/auth/google` | None; valid Google ID token required | `{ "idToken": "...", "requestedRole": "owner", "deviceId": "..." }` | `200` new or existing account: `account`, `accessToken`, `refreshToken`, `accessExpiresAtMs` | `IDENTITY_INVALID`, `ROLE_CONFLICT`, rate limit |
| `POST /v1/auth/refresh` | Refresh credential in body; TLS | `{ "refreshToken": "...", "deviceId": "..." }` | `200` rotated access and refresh tokens; old refresh revoked | `AUTH_REQUIRED`, rate limit |
| `POST /v1/auth/logout` | Bearer access token | `{ "deviceId": "..." }` | `204` current session revoked | `AUTH_REQUIRED` |
| `GET /v1/me` | Either role | None | `200` account, role, app/schema capability versions, shop or own link summary | `AUTH_REQUIRED` |

The Worker verifies Google token signature, issuer, audience, expiry and stable `sub`; it maps that subject to one internal account. `requestedRole` is accepted only during first registration and cannot promote a later session. Exact token type/expiry, refresh rotation and device binding are controlled by the [Security Requirements] document; the mobile app stores credentials in Android secure storage. A lost refresh response may require Google reauthentication; it must not delete the offline outbox. The API never returns Google `sub` or tokens on profile routes.

## 3. Owner shop and customer linking

| Method and path | Auth | Request | Success | Main failures |
|---|---|---|---|---|
| `POST /v1/shops` | Owner | `{ "name": "Kiran Store" }` | `201` `Shop`; repeat for same owner returns existing shop or `SHOP_ALREADY_EXISTS` with owned shop ID | `VALIDATION_ERROR`, `FORBIDDEN` |
| `GET /v1/shops/{shopId}` | Owner of shop | None | `200` `Shop` plus acknowledged shop totals/version | `NOT_FOUND` |
| `POST /v1/customer-qr/resolve` | Owner of shop | `{ "shopId": "shp_1", "publicQrId": "..." }` parsed from `udhaar://customer/v1/{publicId}` | `200` `{ "state": "new"\|"linked", "customerDisplayName": "...", "linkId": null-or-id }` | `QR_INVALID`, `QR_REVOKED`, `NOT_FOUND`, rate limit |
| `POST /v1/shops/{shopId}/customers` | Owner of shop | `clientOperationId`, `publicQrId`, optional `shopNickname` | `201` new `Link`; `200` same existing link | `QR_REVOKED`, `IDEMPOTENCY_CONFLICT`, `NOT_FOUND` |
| `GET /v1/shops/{shopId}/customers?cursor=&limit=` | Owner of shop | Bounded page parameters | `200` page of `Link` and balances | `NOT_FOUND`, `CURSOR_INVALID` |

Example first-time link:

```http
POST /v1/shops/shp_1/customers
Authorization: Bearer <accessToken>
Content-Type: application/json

{"clientOperationId":"4c4d0c80-074c-4fd3-b95c-fd68d7173430","publicQrId":"q_opaqueRandomValue","shopNickname":"Ravi"}
```

The owner must see and confirm the customer's display label before calling link. The Worker rechecks QR active status and shop ownership at commit. A unique `(shopId, customerUserId)` link means repeated scans do not duplicate the customer. For the same `clientOperationId` and canonical request hash, retry returns the original committed result and the same link ID. Reusing an operation ID with changed body returns `409 IDEMPOTENCY_CONFLICT`. A different operation ID that targets an already linked customer returns the existing link without creating another row. Unknown QR linking cannot be queued offline. The owner may use a previously verified local link to open its ledger offline; a cached link is reauthorized when writes later sync.

`POST /v1/customer-qr/resolve` is a read-only lookup and returns minimal identity for confirmation. The QR ID is in the request body rather than the URL so standard request-path logs do not capture it; request bodies must also be excluded from logs. A revoked ID cannot create a new link; existing links remain attached to the internal customer account. An online scan of a revoked ID receives `QR_REVOKED`, even when an old local cache still knows the existing link; the owner can open the known linked customer from their own cached/customer list after reauthorization.

## 4. Customer QR and linked shops

| Method and path | Auth | Request | Success | Main failures |
|---|---|---|---|---|
| `GET /v1/me/qr` | Customer | None | `200` `{ "version": 1, "publicQrId": "...", "payload": "udhaar://customer/v1/..." }` | `AUTH_REQUIRED` |
| `POST /v1/me/qr/rotate` | Customer | Empty JSON object | `200` new QR payload; previous ID revoked atomically | `AUTH_REQUIRED`, capacity error |
| `GET /v1/me/ledgers` | Customer | None | `200` full bounded set of own active shop/link summaries with balance, `snapshotAtMs`; later paginate if needed | `AUTH_REQUIRED` |
| `GET /v1/me/ledgers/{shopId}/entries?cursor=&limit=` | Customer linked to shop | Bounded page parameters | `200` own `LedgerEntry` page and `Balance` | `NOT_FOUND`, `CURSOR_INVALID` |

Rotation is online-only. If its HTTP response is lost, the app calls `GET /v1/me/qr` to recover the current active ID instead of blindly rotating again. The QR contains a random lookup ID and format/version only, never name, email, phone, balance, credentials or Google subject. Customer ledger routes use session user ID for SQL filtering; changing `{shopId}` cannot reveal a different customer's rows.

## 5. Ledger reads, writes and sync

### 5.1 Owner reads

| Method and path | Auth | Request | Success |
|---|---|---|---|
| `GET /v1/shops/{shopId}/entries?linkId={linkId}&cursor=&limit=` | Owner of shop and link | `linkId` required; optional opaque cursor and limit | `200` ordered entries and acknowledged `Balance`. |
| `GET /v1/shops/{shopId}/entries/{entryId}` | Owner of shop/link | None | `200` one entry, current effective contribution and revision for an original. |

`linkId` must belong to `{shopId}`. Without it, use the customer list or a separately specified shop-wide sync query; do not accidentally return all entries via an unbounded query. A customer entry-detail route is `GET /v1/me/ledgers/{shopId}/entries/{entryId}` and checks that the entry belongs to the authenticated customer's link.

### 5.2 One idempotent owner command

`POST /v1/shops/{shopId}/entries` accepts one of three strict body variants. The `clientOperationId` is a UUID v4 saved with the original local outbox item. `linkId` is the verified shop/customer relationship, not a QR ID. The client may submit `occurredAtMs` from the device; the server sets `createdAtMs` and orders by `serverSeq`. The Worker bounds clock skew but does not use client time to decide uniqueness or balance.

Credit:

```json
{
  "clientOperationId": "88a4697c-8180-4b52-8f0e-04837c0638c7",
  "linkId": "lnk_1",
  "kind": "credit",
  "amountPaise": 50000,
  "note": "Rice and oil",
  "dueDate": "2026-10-15",
  "occurredAtMs": 1790680000000
}
```

Payment, recorded by the owner rather than verified against a bank:

```json
{
  "clientOperationId": "814938cc-12f4-4300-8c9b-d9da29f43093",
  "linkId": "lnk_1",
  "kind": "payment",
  "amountPaise": 20000,
  "paymentMethod": "cash",
  "occurredAtMs": 1790680300000
}
```

Correction of an **original** credit or payment to a new effective magnitude:

```json
{
  "clientOperationId": "cc96e054-a6e6-4e2e-9d50-3bd83a891e13",
  "linkId": "lnk_1",
  "kind": "correction",
  "correctsEntryId": "ent_original",
  "expectedRevision": 0,
  "targetAmountPaise": 45000,
  "correctionReason": "Entered 500 instead of 450",
  "occurredAtMs": 1790680600000
}
```

Successful new commit returns `201`:

```json
{
  "data": {
    "entry": {
      "id": "ent_2", "serverSeq": 42, "shopId": "shp_1", "linkId": "lnk_1",
      "kind": "correction", "amountPaise": null, "targetAmountPaise": 45000,
      "effectPaise": -5000, "correctsEntryId": "ent_original", "revision": 1,
      "correctionReason": "Entered 500 instead of 450",
      "note": null, "paymentMethod": null, "dueDate": null,
      "occurredAtMs": 1790680600000, "createdAtMs": 1790680601000,
      "createdByUserId": "usr_owner"
    },
    "balance": { "balancePaise": 45000, "ledgerVersion": 2, "asOfServerSeq": 42, "asOfAtMs": 1790680601000 },
    "replayed": false
  },
  "requestId": "req_2"
}
```

A retry with the same operation ID and canonical payload returns `200` with the original `entry`, **original committed balance/version** and `replayed: true`, even if later entries have changed the current balance. The client then performs a read to obtain the latest state. A different payload under that ID returns `409 IDEMPOTENCY_CONFLICT`. The Worker hashes authenticated owner, shop, operation kind and normalized validated fields; it stores the hash and outcome in `sync_operations` atomically with the ledger row. It checks the receipt before revalidating mutable business state, so a legitimate retry after later balance changes remains a replay. A failed command does not create a success receipt; retrying after a permanent rejection needs explicit user review.

The Worker computes signed effect. Credit increases owed balance; payment reduces it. A payment is rejected with `409 BALANCE_CONFLICT` if it exceeds the authoritative current balance at commit time. Correction uses `expectedRevision`; a stale revision gives `409 REVISION_CONFLICT` with the current authorized revision. A correction cannot point to another shop/customer or a correction row. If the proposed correction would make the final balance negative, return `BALANCE_CONFLICT`. Zero target means cancel the original's current effective contribution; the original and every correction remain visible. No `PUT`, `PATCH` or `DELETE` route edits a posted entry.

### 5.3 Pagination and pull protocol

Ledger pages are ordered by increasing `serverSeq`, with a default 50 and maximum 100 entries per response. These limits are **proposed contract values** and must be checked against D1 read cost before pilot. On first page the Worker captures a high-water sequence and encodes `{v, scope, afterSeq, highWaterSeq}` in an opaque authenticated cursor. Following pages return rows with `serverSeq > afterSeq AND serverSeq <= highWaterSeq`, authorized for the same account/shop/link. The cursor is integrity-protected and rejected if scope/version changes; it contains no names, amounts or notes. `hasMore=false` ends that snapshot; the next sync begins after the last successfully applied sequence. Gaps in global sequence are normal.

The app writes the returned entries and advances its local cursor in **one SQLite transaction**. A failed page or crash leaves the previous cursor intact. A response includes `snapshotAtMs` and `Balance` **as of the captured high-water sequence**; the Worker must obtain that balance from the same consistent snapshot or calculate it from effects through that sequence. Reading the current projection after newer entries commit would violate this contract. Full link-list refresh on app start/reconnect detects link removal because the entry cursor alone cannot communicate access changes. If a cursor is invalid after account switch, key rotation or API change, return `409 CURSOR_INVALID`; the app discards only the affected cached snapshot cursor and refetches authorized records, preserving its outbox.

## 6. Disputes

| Method and path | Auth | Request | Success | Main failures |
|---|---|---|---|---|
| `POST /v1/me/disputes` | Customer | `{ "entryId": "ent_1", "reason": "Amount is incorrect" }` | `201` new `Dispute`; repeat for same entry while open returns `200` existing | `NOT_FOUND`, `VALIDATION_ERROR`, rate limit |
| `GET /v1/me/disputes?cursor=&limit=` | Customer | Own disputes only | `200` page | `CURSOR_INVALID` |
| `GET /v1/shops/{shopId}/disputes?cursor=&limit=` | Owner | Shop-scoped disputes | `200` page | `NOT_FOUND` |
| `PATCH /v1/shops/{shopId}/disputes/{disputeId}` | Owner | `{ "status": "resolved", "ownerNote": "Adjusted in a separate correction" }` | `200` resolved dispute | `NOT_FOUND`, `REVISION_CONFLICT` if already resolved differently |

A customer may dispute only an acknowledged entry in their own link. The server uses the authenticated customer ID to locate it. Submission requires internet. The reason is required and bounded. Resolution records owner identity and time. Disputes never change `balancePaise`; any adjustment must use the separate correction command. A retry of a resolved dispute submission is not guaranteed to recreate an open dispute; the app should query current status before resubmitting.

## 7. Reports, exports and data controls

| Method and path | Auth | Request | Success | Main failures |
|---|---|---|---|---|
| `POST /v1/shops/{shopId}/export` | Owner | `{ "linkId": "lnk_1", "fromDate": "2026-09-01", "toDate": "2026-09-30", "format": "csv" }` | `200` CSV/PDF stream, scoped statement metadata headers | `VALIDATION_ERROR`, `NOT_FOUND`, `CAPACITY_UNAVAILABLE` |
| `POST /v1/me/data-requests` | Owner/customer | `{ "kind": "export"\|"account_deletion"\|"shop_deletion"\|"access_removal", "shopId": "shp_1" }` where applicable | `202` tracked request ID and status | `FORBIDDEN`, `VALIDATION_ERROR` |
| `GET /v1/me/data-requests` | Either | None or bounded pagination | `200` own requests/status | `AUTH_REQUIRED` |

Statement generation includes opening balance, dated signed entries, correction history and closing balance; `opening + sum(effects) = closing`. The export is generated from one consistent acknowledged snapshot. This route never silently mixes unsynced owner Pending entries; the phase-3 product decision will specify whether the device offers a separately labeled local provisional export. PDF/CSV content contains financial data, so it is not logged or cached by intermediaries. A full shop data export is a tracked `data-requests` workflow, not necessarily the same as a customer statement. The exact format, secure delivery/expiry and size limits must be fixed before phase 3.

`access_removal` is available only to the authenticated customer for their own shop link. It must not silently erase the owner's historical ledger. `shop_deletion` is owner-only; `account_deletion` is self-only. The API records a request and status; actual retention, re-linking and deletion timelines require the reviewed privacy policy. No route immediately cascades deletion of financial rows.

## 8. Status codes, retries and compatibility

| HTTP | Stable code | Meaning | Mobile handling |
|---:|---|---|---|
| 400/422 | `INVALID_JSON`, `VALIDATION_ERROR`, `QR_INVALID` | Malformed/unsupported input | Preserve draft; show field/QR guidance. |
| 405 | `METHOD_NOT_ALLOWED` | Known path with unsupported method; response includes `Allow` | Correct the client request. |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | JSON media type required; encoded request bodies unsupported | Correct the client request. |
| 401 | `AUTH_REQUIRED`, `IDENTITY_INVALID` | Missing, expired or invalid credentials | Reauthenticate online; preserve outbox. |
| 403/404 | `FORBIDDEN`, `NOT_FOUND` | Caller lacks permission or resource unavailable | Do not reveal cross-tenant details; Needs attention for queued write. |
| 409 | `BALANCE_CONFLICT`, `REVISION_CONFLICT`, `IDEMPOTENCY_CONFLICT`, `CURSOR_INVALID`, `ROLE_CONFLICT`, `SHOP_ALREADY_EXISTS`, `QR_REVOKED` | State conflict | Read current authorized state; require user action where financial command changes. |
| 413 | `PAYLOAD_TOO_LARGE` | Body/export request exceeds limit | Stop automatic retry. |
| 429 | `RATE_LIMITED` | Abuse/capacity throttle | Honor `Retry-After`; keep Pending. |
| 500/503 | `SERVER_ERROR`, `CAPACITY_UNAVAILABLE`, `FEATURE_UNAVAILABLE` | Temporary failure/quota, or a feature awaiting implementation | Retry transient failures with the same operation ID; do not claim a planned feature is available. |

For transport timeout, lost acknowledgment, 5xx, 429 or quota errors, the owner outbox keeps the **same** `clientOperationId` and original payload. For authorization/validation/business conflicts it marks the local item **Needs attention** and retains it. A customer never sees Pending owner entries via API. `Retry-After` is seconds when supplied; otherwise the client uses bounded exponential backoff with jitter. Server errors and traces never include financial fields. The Worker may intentionally map unauthorized and nonexistent resources to the same 404 response.

Backward-compatible v1 changes may add optional response fields; clients must ignore unknown response fields. Breaking request/response semantics require `/v2` or an explicit migration window. The Worker should publish minimum supported app/schema versions through `GET /v1/me` and retain v1 while supported clients may still hold unsynced outbox commands. Retiring a version without a safe outbox migration risks permanent data loss.

## 9. Contract verification checklist

| Scenario | Required API result |
|---|---|
| Scan alone | QR lookup causes no link or ledger entry. |
| New customer offline | No link request sent; app says internet needed. |
| Same operation retry after lost response | Original entry ID, original committed balance/version, one effect. |
| Same key, changed amount | `IDEMPOTENCY_CONFLICT`; no second effect. |
| Two simultaneous payments | At most the allowed total commits; no negative authoritative balance. |
| Concurrent corrections | One expected revision succeeds; stale one conflicts. |
| Customer A requests B's entry | Scoped 403/404, no identity or amount leaked. |
| Revoked QR | No new link; existing ledger remains by authenticated relationship. |
| Customer offline cache | Last-synced label; no claim of unseen records. |
| Export | Opening + effects = closing; Pending excluded or separately labeled by later decision. |
| Access removal | Customer access changes per policy; owner history not silently deleted. |
| D1 quota failure | Retryable error if Worker can respond; local item remains Pending. |

The API is a design contract, not evidence of a running service. Implementation needs schema validation, authorization and integration tests against the pinned D1 runtime. Cloudflare documents the D1 Worker binding and transactional batch behavior used by this design: [D1 Worker API](https://developers.cloudflare.com/d1/worker-api/d1-database/). The next document, **Security Requirements**, will fix credential lifetimes, rate-limit thresholds, device storage and operational controls.

### D04 session policy

Access credentials contain 256 random bits and expire after 15 minutes. Refresh credentials contain 256 random bits, rotate atomically and expire 30 days from initial session creation; rotation never extends the deadline. D1 stores SHA-256 hashes only. Spent-token replay revokes the session and every associated access credential; lost refresh response requires Google reauthentication. Other device sessions remain valid. Required deviceId is an app identifier, not hardware proof. Profile returns account and capabilities (apiVersion=1, localSchemaVersion=1); shop/link summaries follow later.

Controls start at 10 Google exchanges per 10 minutes per network and 30 refresh attempts per minute per network, returning 429 and Retry-After. IP keys are hashed; inactive rate rows expire on auth traffic. Pilot capacity remains untested. Offline sign-out locks local data and clears local credentials; the UI reports unconfirmed cloud revocation. Server credentials still expire by the above deadlines.
