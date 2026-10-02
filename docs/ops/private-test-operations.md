# D19–D20 private-test operations packet

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../DOCUMENT-MAP.md). **Read with:** [Deployment runbook](../../DEPLOYMENT-RUNBOOK.md) · [Monitoring and logging](../../MONITORING-LOGGING.md) · [Security requirements](../../SECURITY-REQUIREMENTS.md) · [D21 candidate evidence](../verification/d21-evidence.md).
<!-- DOC_NAV_END -->

Prepared 2026-10-02 for synthetic staging tests. This packet does not enable production data, publish a legal retention policy, appoint an operator or claim a configured production backup.

## Privacy data map and requests

| Data | Authorized visibility | Storage/revocation | Retention gate |
|---|---|---|---|
| Google subject/profile | Auth service; display labels to authorized linked users | D1; subject never included in QR/log events | Reviewed account policy required before real use |
| Sessions/hashed refresh and access tokens | Auth service only | D1 hashes; 15-minute access, 30-day refresh, replay revokes session | Expired session cleanup policy not yet approved |
| Public lookup QR | Customer and scanning owner after authorization | D1; one active ID; rotation blocks new links with old ID | Revoked-ID audit period requires review |
| Ledger/receipts/corrections | Owning shop and currently linked customer | Immutable D1; account-scoped app-private owner cache | Financial/legal retention requires review; no ad hoc deletion |
| Customer offline snapshots | Same locally verified account only | Secure storage, dated acknowledged view; explicit removal clears account snapshots | Device clear/uninstall loses cache; offline may be stale |
| Device Pending/Needs attention | Same verified owner account only | Durable app-private SQLite, disabled Android backup | Retain until acknowledged or investigated; do not clear to fix sync |
| Disputes | Reporting customer and owning shop | D1; readonly last-synced device status | Audit/retention period requires review |
| Data requests | Requester and approved operator workflow | D1 status; deletion requests do not erase records | No completion SLA invented; policy/operator approval required |
| Statements/shared device copy | Owner then manually selected recipient | App-private temporary PDF/CSV; cleanup on sheet return and old-file reap | Recipient receives a copy outside app control; warn before sharing |
| Safe request events | Authorized environment operators | Route template/status/error/duration/request ID only | Log retention/access and alert routing must be approved |
| Operational backups | Separately authorized restore operator | Synthetic local AES-256-GCM drill only | Actual separate storage/key custody and retention not configured |

Owners request shop export or shop/account deletion; customers request account deletion or remove shop access. Status is submitted/in_review/completed/denied. There is no public operator status-update endpoint. A submitted deletion request does not delete an account. Access removal immediately revokes the customer's active relationship and preserves the owner's historical ledger. Relink stays blocked until an approved published policy specifies consent and retained-ledger behavior. No specific legal retention period has been invented.

## Encrypted backup and restore

Reproduce the isolated synthetic drill with `python scripts/restore_drill.py --output /tmp/restore-evidence.json` (Python cryptography required). It applies all migrations, posts synthetic credit/payment/correction and immutable receipts, backs up SQLite consistently, encrypts with AES-256-GCM, rejects tampering, restores into a separate file, compares identities/tables/receipts, checks integrity and foreign keys, and reconciles per-link signed effects against the stored projection. Temporary plaintext and ephemeral key are destroyed at exit; no remote database is accessed.

The drill checks receipt recognition without applying a second financial effect; Worker tests separately exercise HTTP duplicate replay. Local SQLite rehearsal does not prove remote D1 export/restore or provider recovery during an outage.

Proposed public-use targets (unproven): RPO ≤24 hours and RTO ≤4 hours, with daily encrypted consistent D1 exports to separately controlled storage, verified completion/hash alarms and periodic isolated restore. Product must approve targets before real use. Restore owner, backup owner, storage account, encryption-key custodian, restore authorization, retention and emergency contact remain **unassigned / not configured**. Cloudflare Time Travel is an additional provider feature, not proof of an independently controlled backup. Public/real-data use remains blocked until actual setup and a timed remote drill pass.

## Capacity and rate control

Cloudflare documentation fetched 2026-10-02: [D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/), [D1 limits](https://developers.cloudflare.com/d1/platform/limits/), [Worker limits](https://developers.cloudflare.com/workers/platform/limits/). At this check Workers Free lists 100,000 requests/day and 10 ms CPU; D1 Free lists 5,000,000 rows read/day, 100,000 rows written/day, 500 MB per database and 5 GB total account storage. Limits can change; verify actual plan/dashboard before onboarding. D1 rows charged include index work; requests are not a safe substitute for measured rows.

| Measure | Watch at 60% | Act at 80% | Action |
|---|---:|---:|---|
| Worker requests/day | 60,000 | 80,000 | Pause onboarding; review traffic/capacity |
| D1 rows read/day | 3,000,000 | 4,000,000 | Limit repeated full reads/exports; preserve authorized essential sync |
| D1 rows written/day | 60,000 | 80,000 | Pause new links; preserve device Pending queue |
| Per-database storage | 300 MB | 400 MB | Review capacity; never delete ledger/receipts as a quota shortcut |
| D1 account storage | 3 GB | 4 GB | Capacity decision before admitting users |

Synthetic test traffic is not representative pilot measurement. Usage panels/alerts need actual Cloudflare dashboard/API configuration and named recipients before real pilot; this packet and safe events are not evidence that remote alarms deliver.

Runtime buckets are hashed and atomic: Google network 10 per 10 minutes, QR rotation account 3 per 10 minutes, QR owner 30/minute plus shared network 300/minute, credit/payment/correction owner 60/minute, link owner 30/minute, disputes customer/owner 20/minute, privacy request 10/minute, export owner 6/minute. Refresh shared-network allowance is 120/minute. Google shared-network restriction remains conservative abuse protection and must be measured for shared-shop networks during private testing; raise only with evidence and compensating identity protection. Retry-After is honored by the outbox. Owner known-link writes remain local Pending during outages; unknown QR/new link requires connectivity. No unlimited free-service promise.

## Observability and incident actions

Safe events allowlist request UUID, route template, HTTP status, bounded stable error code and duration. Never log request URLs, Google subject, tokens, QR IDs, names, notes, amounts, balances or raw request/response bodies. Status/age/count of local Pending and Needs attention are device-local visibility; server telemetry cannot see an offline phone's queue. Request IDs are support correlation only.

On wrong balance/duplicate/privacy incident: stop affected rollout, preserve immutable data and original outbox, classify route/version/request ID, investigate authorization/receipts, fix and reconcile in staging, then obtain production change approval if applicable. Never fix a discrepancy by deleting rows or recreating an uncertain operation. On quota incident: pause new links/onboarding, preserve local Pending, follow Retry-After/manual Sync now, communicate that Pending is not backed up.

## Compatibility, signing and rollback

Use additive migrations in filename order before deploying the Worker, then distribute the app built from the same full commit. Existing credit/payment request hashes remain compatible; API version 1 health capabilities advertise owner sync, correction, dispute, due and privacy contracts. App supports Android API24+; actual low-end/current-device matrix remains pending. Separate local and staging D1 bindings; no production binding is configured.

The private APK uses the existing stable test signer and package `com.udhaarkhata.app` so it can update the previous test build. Keep the GitHub keystore secret masked; its signer SHA-1 is public provenance. Debug signing is not production key custody. Production signing owner/store/backup/recovery and release upload process require separate approval. Never sign a public release with a debug key.

Rollback a faulty Worker to the last verified deployed version only when wire/schema compatibility is retained. No destructive migration rollback is offered; restore is an approved incident workflow, into isolation first with reconciliation and receipts intact. An APK rollback must not reduce SQLite schema compatibility or discard Pending. Do not advise uninstall/clear data. Source CI, deployment and APK audit identify full source commits; record actual run IDs and artifact hash in D21 evidence after they finish.
