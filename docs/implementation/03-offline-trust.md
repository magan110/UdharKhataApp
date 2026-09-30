# Milestone 3 — offline and trust (D11–D15)

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../DOCUMENT-MAP.md). **Read with:** [Daily implementation plan](README.md) · [LLD](../../LLD.md) · [SRS](../../SRS.md) · [Security requirements](../../SECURITY-REQUIREMENTS.md) · [QA cases](../../TEST-CASES-QA-CHECKLIST.md).
<!-- DOC_NAV_END -->

**Exit gate:** a previously linked owner's airplane-mode entry survives app restart, syncs exactly once, and is never labeled backed up while Pending; corrections and disputes preserve history. Source: [Roadmap phase 2](../../PROJECT-PLAN-ROADMAP.md#phase-2--offline-and-trust), [LLD sync design](../../LLD.md#43-sync-coordinator), [SRS F-020–032](../../SRS.md), [Security](../../SECURITY-REQUIREMENTS.md).

## D11 — local ledger and durable outbox

**Dependencies:** D10. **Files:** `udhaarkhata/lib/core/db/{account_database,ledger_dao,outbox_dao}.dart`, `lib/core/sync/{operation,save_local}.dart`, `lib/features/ledger/{credit_form,payment_form,ledger_page}.dart`, `test/core/db/`, local migrations.

1. Open an account-scoped, app-private SQLite database after verified sign-in. Cache only authorized shop/link and acknowledged entries. Model Pending/Synced/Needs attention separately from server entry data.
2. On owner submit for a linked customer, create UUID once and transactionally insert provisional entry, immutable outbox payload/hash and local balance projection. Do not issue HTTP before local commit. Reopen database after forced app termination and retain queue in order.
3. Render provisional balance and every entry status; explicitly state Pending is only on this device. Keep customer view acknowledged-only. Reject offline overpayment against local known balance while allowing server to revalidate later.

**Checks:** atomic rollback, duplicate local submit, crash/restart, account database separation, local balance replay. **DoD:** owner can save linked credit/payment offline and inspect it after restart without falsely claiming server acknowledgement.

## D12 — sync push, pull and account isolation

**Dependencies:** D11. **Files:** `udhaarkhata/lib/core/sync/{coordinator,push,pull,retry_policy}.dart`, `lib/core/network/{api_client,error_classifier}.dart`, `lib/core/db/cursor_dao.dart`, `services/api/src/ledger/sync-routes.ts` if API calls for a dedicated endpoint, tests in both projects.

1. Process one account/shop queue serially, bounded by batch and connectivity. Send original operation ID and payload; after acknowledgement, mark local row Synced and attach server ID/sequence in one SQLite transaction. Classify 429/5xx/network/quota as retryable with bounded jittered backoff; preserve queue and honor `Retry-After`.
2. Pull scoped server changes with stable cursor. Upsert entries/links by server identity and operation ID, then advance cursor atomically with rows. Verify behavior when response is lost after server commit, token refresh fails, and app restarts mid-pull.
3. On permanent validation/permission conflict, preserve local row and original payload as Needs attention; stop dependent commands. On sign-out/account switch, lock old cache, show pending count, and prove account B cannot inspect it.

**Checks:** fake transport fault matrix, real local Worker/D1 retry, cursor paging, token expiry, account A/B, outbox/order and row-sum checks. **DoD:** acknowledged writes converge exactly once; rejected writes remain recoverable and explained.

## D13 — offline QR and recovery boundary

**Dependencies:** D12. **Files:** `udhaarkhata/lib/features/qr/{resolve_controller,scanner_page}.dart`, `lib/core/db/qr_link_dao.dart`, `lib/features/settings/recovery_help.dart`, integration tests; `USER-MANUAL-HELP.md` if wording changes.

1. Cache the verified public QR ID→link mapping from successful online link/read. An offline scan may open only a previously linked, account/shop-scoped customer. Unknown or unverified QR shows **Internet needed to add customer** and creates no local link/entry.
2. Handle stale/revoked link at sync: server checks current relationship; rejected local entry remains Needs attention. Show explicit cloud unavailable/quota state, pending count and manual Retry.
3. On a replacement-phone synthetic test, sign in, pull server-acknowledged entries, and explain that device-only Pending entries on the lost phone are unavailable. Do not restore from Android Auto Backup by accident.

**Checks:** known/unknown QR in airplane mode, old rotated QR policy, permission revoked before reconnect, quota simulation, lost-phone/new-phone drill, Android backup configuration inspection. **DoD:** offline repeat flow works and recovery language matches actual data boundary.

## D14 — immutable corrections

**Dependencies:** D13. **Files:** `services/api/src/ledger/{correction,revision}.ts`, `test/ledger/correction*.test.ts`, `udhaarkhata/lib/features/ledger/{correction_form,entry_detail}.dart`, local outbox model/migration if needed.

1. Implement new correction entry linked to original and reason. Keep original unchanged and visible. Validate target kind, current revision and corrected effect; reject any outcome that makes authoritative balance negative.
2. Atomically guard concurrent corrections/payments in D1. Duplicate correction operation ID replays; changed request conflicts. Treat stale offline correction as Needs attention with original data retained.
3. Show original, correction, effective amount, reason and creator/timestamps in owner/customer history; never present a destructive edit/delete action.

**Checks:** ₹500→₹450 gives −₹50 correction and ₹450 balance; cancellation, multiple revisions, concurrent race, stale offline correction, history/export-ready replay. **DoD:** every balance can be reconstructed from immutable entries and rejected changes leave history intact.

## D15 — customer disputes and trust gate

**Dependencies:** D14. **Files:** `services/api/src/disputes/{routes,service}.ts`, `test/disputes/*.test.ts`, `udhaarkhata/lib/features/disputes/{report_page,owner_queue,detail_page}.dart`, local dispute cache if needed.

1. Let linked customer file a reasoned dispute only on own acknowledged entry while online. Enforce one active dispute per entry or documented repeat semantics, length/rate caps and status visibility.
2. Let owning shop view and resolve with a note. Dispute actions do not alter money; a separate correction is required to change balance. Cache last-synced dispute status read-only when offline.
3. Run full trust regression: cross-customer access, scan/no-post, lost response, airplane mode, correction history, dispute lifecycle, pending device-loss boundary.

**Checks:** own/foreign entry, duplicate dispute, resolution authorization, before/after balance equality, screen reader labels, offline error state. **DoD:** SRS phase-2 requirements and corresponding QA cases have recorded evidence, with no unresolved balance, duplicate or privacy blocker.
