# D12 — durable sync and offline account access

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../../DOCUMENT-MAP.md). **Read with:** [Offline and trust phases](../../implementation/03-offline-trust.md) · [API specification](../../../API-SPECIFICATION.md) · [Security requirements](../../../SECURITY-REQUIREMENTS.md) · [Implementation progress](../../implementation/PROGRESS.md).
<!-- DOC_NAV_END -->

**Status:** proposed written specification; conversational direction approved 2 October 2026. This document needs user review before implementation planning. D11 phone acceptance is user-reported. No D12 product code or remote changes are implied.

## Purpose and scope

An owner can save credit/payment against a completely cached, previously verified ledger, restart offline, and reconnect to converge with D1 exactly once. Acknowledged records remain authoritative; Pending is device-only and Needs attention remains recoverable. Account B cannot inspect account A's cache or outstanding commands.

D12 adds serial push, incremental pull, retry scheduling, session restoration and visible sync controls to the D11 flow. Corrections, disputes, offline QR lookup, lost-phone recovery, background execution while Android terminates the app and automatic rejection editing are later phases. Customer online history continues to expose acknowledged records only; this phase does not add a new customer offline-history flow.

## Chosen approach and alternatives

Use the existing financial POST, receipt batch and account-specific SQLite database. Add an authorized per-link incremental feed with operation identity, and a small coordinator split into push, pull and retry policy. This preserves D11 bodies and existing receipt hashes while avoiding repeated complete-history downloads.

Full history refresh after every write would reuse D10 reads but costs repeated scans and lacks operation identity for safe reconciliation. A new bulk-write endpoint would add batch failure semantics without improving the first pilot's correctness. Neither is selected.

## Queue and acknowledgement

One coordinator run is active per verified account/shop. Capture an account generation at run start; check it before requests and every database/UI application. Switching, signing out or locking invalidates the generation. A late response cannot reopen or mutate a locked/reopened session, including the same account.

Read commands in SQLite insertion order, independent of device clock. Each run attempts at most 20 commands and at most 20 pull pages; network requests remain sequential. A per-link rejected or deferred predecessor blocks its later commands, while unrelated links can progress. Stop the whole run on authentication loss, connectivity failure or shop-wide quota/throttle. Resume through a bounded timer while the app is active, on app resume, after saving locally or through Sync now. No OS background-service dependency is added. Coalesce repeated triggers.

Before sending, validate the account/shop-bound local hash and original payload against its entry. An integrity mismatch becomes Needs attention without a network write. POST the original command fields and operation ID; do not regenerate, normalize again or change occurrence time. Validate the complete returned entry against the command and scope before accepting it. Attach server ID, sequence and commit time, mark Synced and remove the outbox row in one SQLite transaction. A push acknowledgement does not advance the pull cursor: other devices may have committed intervening rows. Original receipt balance is never treated as the latest balance.

Response loss, process termination after server commit, or failure of local acknowledgement preserves the same operation for replay. A later pull can reconcile that operation before another POST. Server identity and operation identity must identify one local row; contradictory matches fail the entire local transaction.

## Incremental pull contract

Add owner-only `GET /v1/shops/{shopId}/customers/{linkId}/sync?afterSeq=<integer>&limit=<integer>` for the first page, and `?cursor=<opaque>&limit=<integer>` for continuation. Default limit 50, maximum 100. Reject ambiguous cursor/afterSeq combinations and unknown query fields. Current owner/shop/link authorization is checked on every page.

Use D10 authenticated cursor machinery with a distinct sync route scope, bound account, role, shop, link, initial after-sequence, fixed high-water, snapshot time and expiry. Include `clientOperationId` in sync entries; D10 customer/public history need not expose it. The response contains `items`, `nextCursor`, `hasMore`, `snapshotAtMs`, `highWaterSeq`, `appliedThroughSeq`, and the acknowledged balance/version through that high-water. Return server-verified minimal link metadata with the page. Rows are strictly increasing in server sequence; global gaps are normal. Empty pages have no continuation and keep the starting sequence. A future starting sequence is CURSOR_INVALID.

Obtain page rows, link authorization and snapshot aggregates from a consistent D1 batch. On completion, entry sums/count/maximum sequence must agree with the supplied snapshot before updating complete-cache metadata. A partial page may be committed and dated as a partial refresh, but cannot claim its high-water balance is already present locally.

Apply each page's records and applied-through sequence atomically. Match by server ID and, when supplied, operation ID; attach missing operation identity to an existing acknowledged D11 bootstrap row only after immutable fields match. This requires a narrowly guarded migration of the local immutability trigger rather than disabling immutable-command protection. Preserve all outstanding payloads and IDs during additive migration. Restart uses the durable sequence with a fresh snapshot; an expired/key-rotated continuation restarts from the last applied sequence. Never delete financial rows or the outbox to reset a cursor.

Reauthorize every cached link individually on reconnect, avoiding the existing customer-list truncation limit. A definitive scoped FORBIDDEN/NOT_FOUND marks that cached link access_removed, retains historical rows, and blocks its queued commands with an explanation. A temporary failure does not infer removal. Access changes are refreshed explicitly because an entry-only cursor cannot convey them. Newly linked customers still enter through existing online linking/bootstrap.

## Failure classification and scheduling

Persist attempts, retry-at time and a sanitized stable error code; never store response bodies, tokens or personal/financial fields in logs. Network/timeout, invalid or unverifiable responses, HTTP 429, HTTP 5xx and capacity/quota failures preserve Pending. Authentication pauses sync and requires online sign-in; it does not classify money as a rejected command. Deterministic validation, balance/idempotency conflicts, unsupported body and permission failures retain the original command as Needs attention.

Carry HTTP status and Retry-After through ApiClient/AppFailure even for non-JSON gateway failures. Use injected clock/random in policy tests. Backoff starts at 2 seconds, doubles to a maximum base of 5 minutes, and uses jitter between half and the full base. Honor a valid server Retry-After as a minimum delay even when longer than the local cap; parse seconds and HTTP-date safely. Never cap it down to retry early. Persist scheduling so restart cannot cause a retry storm. Reset successful operations by removing their queue rows. Needs attention has no automatic retry or replacement-ID action in D12.

Pull current authorized state after a balance conflict while keeping the rejected row excluded from Pending and Synced sums. Clearly mark later same-link Pending commands as blocked; do not reinterpret their original amounts automatically.

## Older occurrence times

Remove the 24-hour lower age restriction for a first credit/payment POST; accept valid nonnegative safe-integer occurrence timestamps up to server now plus 5 minutes. Keep amount, body, note/date and current authorization/balance guards unchanged. Server-created time and sequence remain authoritative posting order. Device occurrence time is untrusted descriptive metadata, not proof of when an event happened. Receipt replay still precedes mutable clock checks, and canonical hashes remain unchanged.

This avoids losing legitimate entries held offline for days and supports existing D11 outbox bodies without rewriting them. Update API, security, database and requirements documentation to explicitly supersede the D08 online-age rule when implemented. A future-clock command remains Needs attention; silently changing its timestamp is forbidden.

## Offline session restoration

After successful online profile verification, save minimal account profile plus last-verification time and a local access deadline (30 days after verification) in Android secure storage, separate from credentials. Do not extend this deadline through offline use. Only this previously verified account may reopen its existing database offline; verify stored database identity/role and do not create a new offline account. Missing, corrupt, expired, future-dated or mismatched metadata requires online sign-in.

For cold startup, try profile verification with an unexpired access credential. A clear transport/temporary availability failure may fall back to the valid local grant. If access is expired, perform a non-mutating connectivity preflight before rotating refresh; transport failure permits local fallback without sending refresh. Once refresh is attempted, any uncertain outcome follows SEC-04: clear credentials/local grant, lock the cache and require Google reauthentication while preserving its database/outbox. A received AUTH_REQUIRED or revocation response also disables the local grant. Temporary cloud failure during a verified open offline session preserves local access only when no uncertain refresh occurred.

Local access does not authorize cloud requests. UI shows Offline / last verified and the device-only Pending warning. Unknown links still require internet. Signing out clears the local grant and credentials, invalidates the coordinator and locks the database, while preserving all financial rows. Show pending count before sign-out; account switching cannot implicitly reopen the old account. Reauthentication of the same account recovers its unchanged queue.

Retain app-private SQLite, Android secure storage and existing backup/device-transfer exclusions. Do not claim protection against a compromised unlocked device. SQLCipher rollout is outside this change; physical-device extraction/security review remains a pilot-release gate, explicitly recorded rather than inferred from host isolation tests.

## Components and compatibility

Flutter: coordinator, push, pull and retry_policy under core/sync; transport/error classification under core/network; scoped cursor/acknowledgement/outbox DAOs under core/db; auth grant/session handling and lifecycle generation under core/auth. Riverpod owns coordinator lifetime. Owner saved-customer, ledger and history views refresh their local projections after committed changes and expose Sync now, progress, last successful sync and Needs attention explanations. Keep modules focused and follow existing repository patterns.

Worker: a dedicated sync route reuses owner authorization, prepared SQL and cursor codec; existing entry POST changes only the occurrence-age policy. No new D1 financial schema is anticipated. If an actual required schema change is discovered, amend this design before implementation. Local additive migration must support both v1 and v2 upgrades to the new version without modifying outbox bytes.

D08/D09 secure-storage uncertain command recovery stays compatible and continues to block new replacements for that link. D12 automatic queue processing must not submit or erase those legacy commands; their existing Check same action remains explicit. D11 large-ledger online fallback remains available; do not admit an incomplete cache or exceed its 10,000-entry automatic-cache limit during sync. A limit hit preserves rows/queue and exposes online confirmed history with a clear local-capacity explanation.

## Verification and completion evidence

Use synthetic records only. Reproduce failures before fixes and run meaningful tests against native SQLite and the pinned local Worker/D1 runtime.

- Lost POST response after commit, duplicate replay, changed-payload conflict and crash between acknowledgement steps produce one server effect and one local row.
- Incremental pages, interleaved other-device writes, sparse sequences, empty page, expired/foreign cursor, bootstrap identity reconciliation and restart mid-pull preserve sums and atomic cursor movement.
- 429 Retry-After, malformed 5xx, quota, transport loss, integrity failure, permanent rejection and dependent-command ordering retain appropriate states with bounded request counts.
- Expired token, refresh-response loss, revoked session, offline cold startup, grant expiry, explicit sign-out and account A/B/same-account generation races preserve queues and prohibit cross-session access.
- Several-day-old commands commit unchanged; future timestamps remain rejected; old receipt hashes replay unchanged.
- Owner UI distinguishes acknowledged/provisional totals, blocked entries and offline verification. Customer API never includes owner Pending rows. Local migration preserves existing D11 queue bytes and IDs.

Run full Flutter tests/analyze/coverage, Worker runtime tests/typecheck/lint, relevant migration tests, docs/navigation checks and independent code review. Record evidence and limitations in Progress. Local completion does not imply phone or remote acceptance: staging deployment, source push and stable-key APK publication require explicit authorization once the tested change is reviewable. Final phone checks cover airplane-mode save/restart, reconnect exactly-once convergence and account isolation.
