# Udhaar Khata — Deployment Document / Runbook

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [Security requirements](SECURITY-REQUIREMENTS.md) · [Monitoring and logging](MONITORING-LOGGING.md) · [Support SOP](SUPPORT-MAINTENANCE-SOP.md) · [Release notes](RELEASE-NOTES.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Release:** Android v1  
**Status:** Procedure design; no Worker, D1 database, Android build or production deployment is evidenced  
**Baseline:** [SRS](SRS.md) · [Project Plan](PROJECT-PLAN-ROADMAP.md) · [Database Design / ERD](DATABASE-DESIGN-ERD.md) · [API Specification](API-SPECIFICATION.md) · [Security Requirements](SECURITY-REQUIREMENTS.md) · [Test Plan](TEST-PLAN.md)

## 1. Purpose, audience and release rule

This runbook tells the release operator how to prepare, stage, verify, deploy, observe and recover the first Flutter Android app and Cloudflare Worker/D1 backend. It is a **template for a future implementation**: project names, database IDs, package commands, signing identities, backup destination, monitoring links and named operators must be filled and tested before use. Do not paste placeholder commands into a production shell. The user-facing app remains free; Cloudflare Free capacity is finite and must be watched.

Operators may inspect and draft locally. Production deployment, app-store distribution, secret changes, third-party resource changes and destructive restore require an approved release/change record and the authorization required by the operating organization. This runbook never treats a written checklist as approval or as proof of a successful deployment.

**Hard release gate:** No real shop financial records until identity/tenant isolation, money/idempotency, local Pending truthfulness, encrypted backup and isolated restore, secrets, rate limits, quota alerts, privacy policy and support ownership pass the [Security Requirements](SECURITY-REQUIREMENTS.md#8-required-security-tests-and-release-gates) and [Test Cases](TEST-CASES-QA-CHECKLIST.md#9-phase-exit-checklist). A failed or untested hard gate stops the release.

## 2. Environment inventory and ownership

Fill this inventory in the approved release packet; do not put credentials here.

| Field | Development | Staging | Production |
|---|---|---|---|
| Worker name/route | `[DEV_WORKER]` / `[DEV_API]` | `[STAGE_WORKER]` / `[STAGE_API]` | `[PROD_WORKER]` / `[PROD_API]` |
| D1 database name/ID | `[DEV_D1]` / `[ID]` | `[STAGE_D1]` / `[ID]` | `[PROD_D1]` / `[ID]` |
| Google OAuth client and Android signing fingerprint | `[DEV_CLIENT]` | `[STAGE_CLIENT]` | `[PROD_CLIENT]` |
| Android application ID and signing identity | `[DEV_APP]` | `[STAGE_APP]` | `[PROD_APP]` |
| Backup destination/key owner | Disposable | `[STAGE_BACKUP]` | `[PROD_BACKUP]` / `[KEY_OWNER]` |
| Telemetry/alert destination | `[DEV_MONITOR]` | `[STAGE_MONITOR]` | `[PROD_MONITOR]` |
| On-call and product approver | `[NAMES]` | `[NAMES]` | `[NAMES]` |

Staging and production have separate Worker routes, D1 bindings, Google OAuth clients, session stores and required integration secrets, backups and telemetry. CI uses named least-privilege credentials; operators use MFA. The production D1 binding is never present in a staging Worker or mobile build. Store secrets as Cloudflare secret bindings, never plaintext Wrangler `vars` or committed `.env` files. A D1 binding provides the Worker its database capability; the app only knows the HTTPS API URL. [Workers secrets](https://developers.cloudflare.com/workers/configuration/secrets/), [Workers bindings](https://developers.cloudflare.com/workers/runtime-apis/bindings/).

### 2.1 Required release record

Record change ID, owner/approver, desired deployment window/timezone, app version/build number, source commit, Flutter/Dart/TypeScript/Wrangler versions, Worker version, migration numbers, old/new API compatibility, current D1 bookmark or backup ID, encrypted export location, rollback candidate, supported Android matrix, expected traffic and monitoring links. Link sanitized CI and QA evidence. Name who can stop the rollout and who communicates to pilot users.

## 3. Before implementation: setup and configuration

1. Create development, staging and production Cloudflare environments with **distinct** D1 databases and bindings. Pin Wrangler version in the Worker lock file. Pin Flutter/Dart and Android toolchain versions and use a release build configuration separate from debug. Verify exact environment/DB name/ID before every D1 command; Cloudflare notes that binding names can change, so prefer the recorded database name for migrations.
2. Configure Google sign-in with the correct Android app ID, signing certificate fingerprint and accepted audience for each environment. Worker verifies Google signature, issuer, audience, expiry and subject. Test the **release-signed** app against staging before production.
3. Opaque sessions need no signing secret. Configure the public GOOGLE_CLIENT_ID audience per approved environment; create secret bindings only for integrations requiring them. Define rotation owner and procedure. Never put the Google ID token, refresh token, QR public ID, financial amount or note in logs or deployment output.
4. Create D1 migrations as immutable numbered SQL files. Implement constraints and triggers from [Database Design / ERD](DATABASE-DESIGN-ERD.md). Also version local SQLite migrations and test upgrade with Pending outbox records.
5. Choose and document backup destination, encryption key custody, frequency, retention and restore-time objective. Establish a separately accessible encrypted export of D1 and rehearse import/restore to an **isolated** environment. A PDF/CSV statement is not a full backup. Do not assume Time Travel alone satisfies the chosen retention or offsite recovery policy.
6. Set rate limits, body/page/export bounds and alarms for Worker errors, D1 reads/writes/storage, Pending queue age and reconciliation failures. Review current provider limits and the expected per-shop usage before onboarding real users.
7. Publish and test the privacy/retention notice, data-request workflow, support contact, access-removal behavior and emergency communication path. Decisions left open in the [SRS](SRS.md#11-open-decisions-and-change-control) must be closed before the feature or public launch that depends on them.

As of this document, Cloudflare lists Workers Free D1 Time Travel recovery for **7 days**, and D1 has additional per-database and daily usage limits. Verify the active plan and current limits at release; never present free capacity or recovery duration as an unlimited guarantee. Time Travel restore overwrites the database **in place** and cancels in-flight queries, so it is an incident action, not a routine migration rollback. [D1 limits](https://developers.cloudflare.com/d1/platform/limits/), [Time Travel](https://developers.cloudflare.com/d1/reference/time-travel/).

## 4. Build and staging procedure

D01?D03 local scaffolding and database checks exist. Run `npm run db:migrate:local` and `npm run db:check:local` in `services/api/` for the local-only D1 binding. Repeat migration is a no-op; future changes require a new numbered file. Before the first migration there is no prior financial schema. D03 tests rehearse an additive upgrade and failed-upgrade rollback using synthetic migrations; every future real migration must also be tested with its actual prior version. D03 staging D1 is configured and its initial schema smoke checked; D04 migration 0002 is local only until separately approved for staging. Live OAuth, Worker deployment and release signing remain pending. Replace the remaining illustrative release commands with approved checked scripts before use. Run from the appropriate project directory; commands below show intent and are **not** evidence of execution.

```text
udhaarkhata/:  flutter pub get
               dart format --output=none --set-exit-if-changed .
               flutter analyze
               flutter test
               flutter build appbundle --release

services/api/:  <pinned-package-manager> install from lock file
               <pinned-package-manager> run typecheck
               <pinned-package-manager> run test
               <pinned-package-manager> exec wrangler deploy --dry-run
```

1. Freeze the source commit and lock files. Run format, static analysis, unit/widget/API tests, D1 integration and dependency/secret scans. Review the exact diff and generated Android manifest; verify no production secret or debug endpoint in the bundle.
2. Build a signed **internal** Android App Bundle using the approved upload key and application ID. Verify the certificate fingerprint, Google sign-in, API base URL, cleartext disabled, Auto Backup exclusions and supported SDK range. Protect the keystore and `key.properties`; neither belongs in source control. Flutter documents the release signing and `flutter build appbundle` workflow. [Flutter Android release guide](https://docs.flutter.dev/deployment/android).
3. Rehearse D1 migrations on disposable local D1, then on staging with a representative pre-migration snapshot. Cloudflare's Wrangler migration command uses `wrangler d1 migrations apply <DATABASE> --remote` for a remote database; make the target explicit and verify it before confirming. Record migration output and run `PRAGMA foreign_key_check`, entry-sum/balance reconciliation and receipt replay tests. [D1 migration commands](https://developers.cloudflare.com/d1/wrangler-commands/).
4. Deploy the candidate Worker to **staging**, not production. Confirm its version, D1 binding, secret presence and route. Run the full [Test Cases / QA Checklist](TEST-CASES-QA-CHECKLIST.md) relevant to this release, including valid Google sign-in, two-owner/two-customer access matrix, QR link, ₹500 credit/₹200 payment, lost response, concurrent correction/payment, offline outbox, quota error, export and restore.
5. Install the signed internal app on the approved device matrix. Measure linked scan-to-local-save, test airplane mode and camera permission, English/Hindi, TalkBack and account switch. Capture build/version IDs and sanitized evidence in the release packet.
6. Stop if P0/P1 money, privacy, outbox or recovery defects remain. Repair and repeat affected tests; do not promote a different untested binary or Worker build.

## 5. Production promotion sequence

Use the release record as the source of truth. The following is an **operator checklist**, not a request to execute it now.

| Step | Action | Continue only if |
|---:|---|---|
| 1 | Confirm change approval, named on-call, no active P0/P1 incident, current backup/restore evidence and monitoring. | Approver signs packet and all hard gates pass. |
| 2 | Freeze rollout; record current Worker version and D1 Time Travel bookmark. Create an encrypted full export in the approved destination, with access restricted and checksum recorded. | Export verifies and restore procedure was rehearsed recently. |
| 3 | Apply **expand-compatible** D1 migration to production. Avoid destructive rename/drop while old Worker or old mobile clients may still run. | Correct production database ID confirmed; migration output clean; FK/reconciliation checks pass. |
| 4 | Upload new Worker version, smoke-test its version URL or staged route, then deploy gradually where the account/tooling supports it. | New Worker reads old/new data correctly and old Worker remains rollback-compatible with schema. |
| 5 | Run synthetic production smoke through authenticated test accounts: sign-in, own shop/customer read, QR resolve, one small credit and compensating correction where approved, balance/receipt reconciliation. | No cross-tenant leakage, duplicate effect or unexpected D1 error. Use a dedicated test shop, not a real customer ledger. |
| 6 | Raise Worker traffic in controlled steps and observe error rate, sync acknowledgment latency, D1 rows/usage and queue age at each step. | Thresholds remain within approved limits and no financial invariant alarm fires. |
| 7 | Publish the **same tested** signed Android bundle through the approved private/pilot/public channel. Monitor version adoption and keep `/v1` API compatible with old outbox clients. | Store rollout approved; support and release notes ready. |
| 8 | Mark release complete only after the observation window, reconciliation check and operational handoff. | Product, engineering/QA and operations record final decision. |

Cloudflare supports uploading Worker versions before deployment and gradual traffic splits. A plain `wrangler deploy` immediately serves the new Worker at 100%, so use the release method selected in the approved packet. Cloudflare's Worker rollback changes **Worker code**, not D1 schema; an incompatible migration can make code rollback unsafe. [Worker versions and deployments](https://developers.cloudflare.com/workers/versions-and-deployments/), [gradual deployments](https://developers.cloudflare.com/workers/versions-and-deployments/gradual-deployments/).

### 5.1 Compatibility contract

The rollout order is **expand schema → compatible Worker → app → later contract cleanup**. An old client may hold an offline operation for days; `/v1` must continue accepting its payload and operation ID during the support window. A mobile update must migrate local SQLite without dropping Pending outbox data. A Worker build must either support the existing D1 schema or be deployed only after the compatible migration. A destructive D1 schema change is a separately reviewed release, not an automatic rollback step.

## 6. Verification immediately after promotion

Record observations rather than simply checking “healthy”:

- Worker version and route; staging/production bindings point to their intended D1 IDs; configured secrets present without exposing values.
- Auth route succeeds for dedicated test owner/customer and fails for invalid token; cross-shop test request is denied with no private body.
- Existing linked customer can post once and replay same operation ID with one D1 effect; new QR link requires online resolution.
- D1 ledger sum equals stored balance for synthetic release-test links; `sync_operations` receipt returns original response after retry.
- Error-rate, p95 API latency, D1 rows read/written/storage and free-tier headroom are inside the release thresholds. Mobile Pending queue age does not rise unexpectedly.
- Customer view shows only acknowledged entries; owner Pending is labeled and remains local on a network/quotas failure. No sensitive value appears in telemetry or export temp paths.
- Backup/export artifact is encrypted and accessible only to authorized operators; last restore drill remains valid for this schema version.

Use a short initial observation window and a longer pilot watch, both defined in the release packet. If the app-store rollout is gradual, monitor each cohort before expanding. If an alarm fires, stop promotion immediately and follow section 7.

## 7. Incident triage and rollback decision tree

| Symptom | Immediate containment | Recovery path |
|---|---|---|
| Wrong balance, duplicate effect or reconciliation mismatch | Stop new financial writes/rollout; preserve logs/receipts and D1 bookmark; do not run blind corrections. | Independent ledger-sum investigation. If code-only and schema compatible, roll back Worker or deploy fixed version; verify receipts and reconcile before reopening. |
| Cross-shop/customer data access | Stop affected routes and rollout; revoke exposed sessions if needed; restrict operator access. | Fix authorization, assess scope and privacy notification duties with designated owner; retest full tenant matrix. |
| Worker 5xx after code change, schema compatible | Halt traffic increase; keep app Pending entries on phones. | Roll back to recorded Worker version, then smoke/reconcile. Cloudflare `wrangler rollback` creates a new deployment of a prior version. |
| D1 migration or data corruption | Stop writes immediately; preserve current state and bookmarks. | Restore only after approved impact analysis. Prefer a repaired forward migration when safe; if point-in-time restore is chosen, account for all acknowledged writes after restore point. Never silently discard them. |
| D1/Worker free quota exhausted | Pause new onboarding/export, reduce nonessential reads and communicate delayed sync. | Existing linked owners may continue local Pending writes; monitor reset/upgrade decision; do not claim they are cloud-backed up. |
| Google sign-in or OAuth misconfiguration | Stop mobile rollout; inspect client ID/fingerprint/audience and Worker config. | Correct configuration through reviewed secret/config change; re-test release-signed app. Do not bypass token validation. |
| Bad Android release | Halt app-store rollout; preserve local Pending queues. | Ship a fixed app with compatible local migration. Server remains compatible with old/new clients until Pending commands can sync. |
| Lost device with Pending entries | Explain that D1 cannot restore unsynced records; protect account sessions. | Restore acknowledged records after Google sign-in; use old-device local recovery only if still available. |

**Worker rollback is not database rollback.** Cloudflare notes a Worker version may fail to roll back when dependent platform resources changed. Do not issue a D1 Time Travel restore as a routine reaction: it overwrites the database in place and can erase newer acknowledged entries. A restore requires a change/incident approval, a verified target bookmark, record of all writes since that point, communication plan, and an isolated rehearsal or equivalent confidence. [Worker rollback](https://developers.cloudflare.com/workers/versions-and-deployments/rollbacks/), [D1 Time Travel restore warning](https://developers.cloudflare.com/d1/reference/time-travel/).

## 8. Backup, restore and data-integrity procedure

**Backup requirement:** Choose an encrypted destination independent of the live D1 database, key custody, schedule and retention before real-user data. Cloudflare's `wrangler d1 export <DATABASE> --remote --output=<FILE>` can create a schema+data SQL export, but the resulting file contains sensitive financial data and must be created only on a restricted host, encrypted promptly and removed from unprotected temporary locations. A verified checksum and access log accompany every artifact. [D1 import/export](https://developers.cloudflare.com/d1/best-practices/import-export-data/).

**Restore rehearsal in isolated staging:**

1. Record source database ID, migration version, export timestamp, checksum and encryption key owner. Create a **new isolated restore database** and Worker route, with synthetic data or the minimum authorized protected dataset.
2. Decrypt/import through the approved restricted environment. Run migration-state and `PRAGMA foreign_key_check`; compare user/shop/link/entry/dispute/receipt counts with the source snapshot.
3. For each shop/customer link, recompute `SUM(effect_paise)` and compare with `ledger_accounts.balance_paise`; check correction revisions, `server_seq` ordering and original idempotency receipts.
4. Retry a saved operation ID with the same request hash against the isolated restored service; it returns the original result without a new effect. Test customer and owner access scope. Capture sanitized evidence and elapsed restore time.
5. Destroy the isolated copy according to retention policy after review; do not leave live financial copies in general staging or developer environments.

**Production restore:** preserve the current state first, stop writes, get incident approval, verify target and write-loss window, restore by the approved method, reconcile, replay or manually resolve any acknowledged writes after the restore point, retest authorization/idempotency, then resume traffic. Treat uncertain data consistency as a stop condition. D1 Time Travel's Free retention is finite; operational exports protect beyond that window only if the export/restore process is actually implemented and tested.

## 9. Quota and cost control

The release operator records current D1 and Workers Free limits and actual usage trend before each expansion. D1 Free currently lists **5 GB account storage, 500 MB per database, 5 million rows read/day and 100,000 rows written/day**; Workers have separate request/CPU limits. Verify plan and limits at the time of deployment. Indexes, retries, full-list refreshes and exports affect row usage. Set warning/action thresholds below quota, such as an initial internal watch at 60% and action at 80%, then tune from pilot data. The 60/80 thresholds are proposed operational defaults, not provider promises. [D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/), [D1 limits](https://developers.cloudflare.com/d1/platform/limits/).

If usage rises: inspect route-level read/write counts, disable nonessential exports or repeated refreshes, bound page size, pause new shop/customer onboarding, and decide capacity funding before expansion. Do not drop or silently reject valid offline repeat entries on the device. The app must show **Waiting to sync** until D1 acknowledges them. The free-to-user product promise does not make operating capacity unlimited.

## 10. Release handoff and open fields

Before the release record is approved, fill and verify:

| Item | Required value/evidence |
|---|---|
| Named release operator, backup/key owner, incident contact and product approver | `[NAMES / ON-CALL ROUTE]` |
| Production Worker route and D1 name/ID | `[VERIFIED VALUES]` |
| Google OAuth audience and release signing fingerprint | `[VERIFIED VALUES]` |
| Pinned tool/package versions and CI job URLs | `[VERSIONS / RUN LINKS]` |
| Backup destination, encryption, schedule, retention and last isolated restore result | `[APPROVED RECORD]` |
| RTO/RPO, Time Travel window and acceptable write-loss handling | `[APPROVED INCIDENT POLICY]` |
| Quota and error thresholds, dashboard and alert destinations | `[VALUES / LINKS]` |
| Privacy/retention policy, support process and approved store rollout channel | `[APPROVED RECORDS]` |
| Latest test packet, unresolved defects, rollback Worker version and schema compatibility | `[RUN LINKS / VERSION IDS]` |

After handoff, operations owns monitoring and backup checks, engineering owns compatibility and migrations, support owns user requests, and product owns rollout expansion. The next **Release Notes** document should describe the actual release behavior and known limitations from the approved build; until a build exists it remains a clearly marked draft template.


### Approved staging deployments through GitHub Actions

The manual `Deploy staging API` workflow accepts an approved source ref and targets only `udhaarkhata-api-staging`, the existing `udhaarkhata-staging` D1 binding and the staging Google audience. It installs locked dependencies, verifies the exact public target, runs Worker typecheck/lint/tests and a dry-run, then applies pending versioned migrations to `udhaarkhata-staging --env staging --remote` before deploying `--env staging`. Approval for a run must include its pending migrations. Supply the repository Actions secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`; use a token scoped to the intended account with Workers Scripts Edit and D1 Edit for migration execution and binding discovery. The credentials are injected only into the deployment step, never committed, echoed or attached as artifacts. Missing credentials fail before migration or deployment. Do not paste tokens into chat.

After upload, the workflow checks live HTTPS health and unauthenticated profile, QR resolution and customer linking denial. The public notice/summary records source commit, Worker version where reported and status codes. It creates no synthetic link or financial record: protected smoke requests are unauthenticated and must return AUTH_REQUIRED before mutation. Authenticated owner/customer and camera tests remain phone gates. Every manual run still needs the approval required by AGENTS.md; the workflow is an execution mechanism, not authorization for later deployments.

### D10 online history checkpoint (2 October 2026)

D10 introduces additive D1 migration 0003 for the environment-local cursor key. Before approved D10 staging deployment, run local migration/repeat/foreign-key checks and the read regressions; the prepared staging workflow applies pending migrations to its previously checked exact staging target before deploying. User approval must explicitly include staging migration, deployment and stable-key APK delivery. No new Google OAuth/signing registration is required. Code rollback to D09 leaves the additive table intact; do not drop financial tables or receipts. Cursor-key rotation invalidates outstanding read pages and requires refresh; it does not modify ledger entries or saved device commands.
