# Udhaar Khata — Support / Maintenance SOP

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [Deployment runbook](DEPLOYMENT-RUNBOOK.md) · [Monitoring and logging](MONITORING-LOGGING.md) · [User manual](USER-MANUAL-HELP.md) · [Release notes](RELEASE-NOTES.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Release:** Planned Android v1  
**Status:** Procedure design; support channel, operators and service are not yet live  
**Baseline:** [SRS](SRS.md) · [PRD](PRD.md) · [Security Requirements](SECURITY-REQUIREMENTS.md) · [Monitoring & Logging](MONITORING-LOGGING.md) · [Deployment Runbook](DEPLOYMENT-RUNBOOK.md)

## 1. Purpose and safety rule

This SOP gives support and operations a repeatable way to handle QR, sign-in, ledger, sync, dispute, lost-device, export/deletion and service-health reports. Its goal is to help users without changing a financial record, exposing another person's data or losing an owner-only Pending entry. The app is intended to be free to users, but Cloudflare capacity is finite and outages can delay sync.

**First response rule:** Determine whether the affected entry is **Waiting to sync**, **Synced**, or **Needs attention** before advising any action. A Waiting-to-sync entry is on the owner's phone only. Do **not** tell an owner to uninstall, clear app storage, factory-reset, switch accounts without reviewing Pending items, or generate a new transaction to “make it sync.” A Synced entry is acknowledged in D1; an incorrect one is corrected by a new owner entry with a reason, not silently edited. A customer dispute does not itself change the balance.

This document does not authorize production data changes, outside messages or publication. Support may draft responses and investigate within assigned access; actual user outreach, production changes, exports, deletion and restore follow the approved support/privacy/change process. Named people, channel addresses, hours and legal timelines must be filled before real-user support begins.

## 2. Roles, channels and ticket states

| Role | Allowed work | Escalation boundary |
|---|---|---|
| Frontline support | Receive user report, verify account through approved app flow, explain status, capture sanitized facts, guide ordinary app steps | Cannot view unrelated ledgers, change balances, issue refunds, bypass Google identity or run D1 commands. |
| Engineering on-call | Investigate app/API defects, safe request-ID traces, reproduce with synthetic data, propose fix | Cannot deploy or mutate production without change/incident approval. |
| Operations on-call | Check Worker/D1/backup/quota dashboards, pause rollout per incident authority, perform approved recovery | D1 restore/export requires incident/change review and audit. |
| Product/privacy owner | Decide policy interpretation, deletion/re-linking requests, user-facing wording and launch impact | Must not invent retention period or make legal commitments without review. |
| Shop owner | Posts credits/payments/corrections and resolves disputes for own shop | Only owner can deliberately correct their financial ledger through app flow. |
| Customer | Views own linked ledgers and files dispute/data requests | Cannot post or edit owner entries. |

**Required channels before pilot:** in-app Help/Contact route, monitored support intake destination, incident on-call destination, privacy/data-request queue and status page or in-app service notice mechanism. Fill `[SUPPORT_CHANNEL]`, `[ON_CALL]`, `[PRIVACY_OWNER]`, `[SUPPORT_HOURS]` and `[STATUS_DESTINATION]` in the launch packet. A support channel is not “live” until a test report is received, assigned, answered and closed.

Ticket states: `New → Triage → Investigating → Waiting for user / Waiting for engineering / Waiting for policy → Resolved → Closed`. A reopened issue returns to Investigating with the original ticket history. Do not mark a request Resolved merely because a response was sent; confirm the user's requested outcome or explain the verified boundary.

### 2.1 Minimum ticket record

Capture ticket ID, received time/timezone, reporter role, feature, app version/build, Android version, approximate event time, online/offline state, displayed sync status, safe error code/request ID, affected shop relationship **as viewed by the authenticated reporter**, steps, severity, assigned owner and next update time. If the user volunteers a transaction amount, keep it in restricted case notes only when needed to reconcile the specific report; do not copy it into routine logs, chat channels or broad dashboards. Record consent and provenance for any screenshot or export. Redact or decline tokens, full QR images, Google ID tokens and device database files in ordinary tickets.

Verify the reporter via the app's authenticated session and approved support process. Email or a QR screenshot alone is not proof of account ownership. Never disclose an owner/customer ledger to someone merely because they know a shop name, phone number, QR ID or entry amount. Support uses safe request IDs to correlate Worker events as specified in [Monitoring & Logging](MONITORING-LOGGING.md#3-structured-event-contract).

## 3. Triage and priority

| Priority | Trigger | Initial action |
|---|---|---|
| **P0 Critical** | Wrong authoritative balance/duplicate effect, confirmed cross-tenant leak, secret exposure, silent loss of accepted/local-saved item, backup corruption with no safe recovery | Escalate immediately to engineering/operations; contain affected writes/route/rollout; preserve evidence; use incident runbook. |
| **P1 High** | Widespread sign-in/sync failure, known-link transactions blocked, data request impossible, misleading Pending/backup status, export totals wrong | On-call investigates promptly; stop rollout expansion; give user an accurate workaround if safe. |
| **P2 Medium** | Isolated QR/camera issue, noncritical export or localization defect with safe workaround | Support guides user and files defect; assign target fix. |
| **P3 Low** | Cosmetic issue without money, privacy or accessibility impact | Record for next maintenance cycle. |

These priorities follow the [Test Plan](TEST-PLAN.md#10-entry-exit-and-defect-policy). Exact acknowledgement/update times are not yet promised; the product/operations owner must set them with staffing before pilot. A suspected privacy leak or unexplained ledger mismatch is P0 even if only one report exists. Multiple similar P2 reports may indicate a P1 service incident.

## 4. Standard support workflow

1. **Acknowledge and protect data.** Give ticket ID and next update time. Ask only for role, app version, approximate time, current sync label and request ID if shown. Warn the owner to keep the app installed and preserve Pending entries while investigating.
2. **Confirm scope.** Verify the reporter's signed-in account and which shop relationship they are allowed to discuss. Do not use the QR ID or editable email as an ownership key.
3. **Classify local versus cloud state.** Check the app's status and last sync time. A support dashboard may show only online-device aggregates; it cannot see an offline phone's Pending queue. If the owner says an item is Waiting to sync, do not claim it is on D1.
4. **Check safe service evidence.** Review alert dashboards by release/route/error class and correlate `requestId` to a redacted completion event. Do not search full request bodies or raw QR IDs in logs.
5. **Follow a playbook in sections 5–8.** If facts conflict, stop ordinary troubleshooting and escalate. Never create, delete or edit a ledger row as a support shortcut.
6. **Record outcome.** Note what was verified, guidance given, whether the entry is Synced/Pending/Needs attention, any defect/incident link, and next action. For a financial dispute, direct the customer to the in-app dispute flow and the owner to a correction if appropriate.
7. **Close safely.** Confirm the issue is resolved or the user understands the remaining limitation. Remove unnecessary attachments under the approved retention policy and keep the audit trail required for the case.

## 5. User issue playbooks

### 5.1 Cannot sign in or wrong account

1. Ask whether Google sign-in was canceled, internet is unavailable, or the app shows a specific error code; capture app/build and request ID. Check service-wide auth errors and the release-signed OAuth configuration.
2. Ask the user to select the **same Google account** originally used. Google `sub` identifies the account; a changed email/display name should not create a new ledger. Never switch a user to another account based only on email, QR screenshot or verbal claim.
3. If a token refresh failed, reauthentication is the intended recovery, but **first** warn an owner with Pending operations that account switching/uninstalling may hide or lose local data. Preserve the old account's local cache.
4. If many users fail after a release, mark P1 and escalate to engineering/operations. Do not disable token validation or hand out credentials.

### 5.2 QR does not scan, is revoked, or new customer is offline

1. Separate camera permission/unreadable image from `QR_INVALID`, unsupported version, `QR_REVOKED` and no internet. Camera denial needs a permission retry path; a malformed QR should not open an external link.
2. A customer may show an issued QR offline after registration. An **unknown** QR needs internet for the owner to resolve and link. Do not add a manual unverified customer placeholder to work around offline lookup.
3. If the customer rotated the QR, ask them to show the current one. An old revoked QR cannot create a new link. If already linked, the owner may find the known customer in their own list, subject to current permissions.
4. Confirm that scanning alone did not post an amount. If the owner reports a charge from scanning, escalate P0/P1 based on D1 evidence.

### 5.3 Entry says Waiting to sync or Needs attention

1. Confirm whether owner sees **Waiting to sync** (retryable/offline) or **Needs attention** (server rejected or requires action). Record last successful sync time and safe error code. Do not ask for full payload or token.
2. For Waiting to sync, check network and service status; use the app's **Retry sync** control once. The app must reuse its original operation ID. Avoid repeated manual new entries. Keep phone/app data intact until acknowledgment.
3. If Worker/D1 quota or outage is active, tell user the item is still on the phone and not cloud-backed up. New customer linking may be unavailable. Follow the quota incident in section 7.
4. For Needs attention, do not blindly retry. A balance conflict, stale correction revision or lost authorization needs owner review; retain the original local record. If a changed command is intentionally created, it gets a **new** operation ID and the old rejected record remains inspectable.
5. Escalate if a Pending item disappears, a server ack is uncertain, or the customer sees an entry the owner says is Pending. Engineering checks the D1 receipt by authorized scope and reconciles one effect before any UI guidance.

### 5.4 Wrong balance, duplicate entry or disputed sale

1. Ask whether both devices show the **same server sync version/time**. An owner may have a provisional local balance that includes Pending; a customer sees only acknowledged entries. A difference before sync is not automatically a D1 mismatch.
2. If both are synced and differ, or a duplicate effect is suspected, mark P0, preserve request IDs and stop the affected rollout/write path through on-call. Engineering independently sums immutable D1 entry effects and checks receipts/projection. Support must not edit D1 or advise an offsetting “payment” to hide the error.
3. If a single owner-entered amount was mistaken and D1 is otherwise consistent, explain the **Correct entry** flow: owner sets target amount or cancellation with a reason; original and correction stay visible. A customer may file **Report a problem** on their own acknowledged entry. Filing/resolving a dispute alone does not alter balance.
4. Cash/UPI is a manual label. Do not claim the app can prove that a bank transfer occurred. Any real-world payment disagreement is handled between owner/customer and through the visible dispute/correction history.

### 5.5 Lost, replaced or damaged phone

1. Help the user sign in on the replacement Android phone with the same Google account. Only D1-acknowledged entries and permitted links can restore.
2. State plainly that entries still **Waiting to sync** on the lost phone were not in D1 and cannot be recovered from cloud backup. If the old device is available, preserve its app data and attempt safe sync before retirement; do not promise recovery from a device that is gone.
3. Revoke the missing phone's app session through the approved authenticated process when available. A revoked session does not delete D1 ledger history. Do not use email-only verification to grant access to another account.
4. If the owner reports missing Synced entries, escalate P0/P1 and inspect D1 restore/query scope before saying records are lost.

### 5.6 Reminder, statement or export trouble

1. A reminder is previewed and sent only after the owner chooses an Android share destination; the app never auto-sends. Check the displayed shop/customer and whether the balance is provisional or last-synced before sharing.
2. For PDF/CSV, verify selected customer/date range and opening + signed entries = closing. If totals do not reconcile, mark P1 or P0 if ledger integrity is implicated; keep the file restricted and do not forward it through ordinary ticketing.
3. A full shop data export request is a tracked privacy/support workflow, separate from a convenience customer statement. Its secure delivery method, identity verification and expiry must follow the approved policy.

## 6. Data access, deletion and privacy requests

Route export, customer access removal, account deletion and shop deletion through the app's tracked request flow or the approved privacy queue. Log request ID, verified requester, scope, received time, status, assigned privacy owner, decision basis and completion evidence in the restricted case system. No frontline agent executes a direct D1 delete or exports another shop's records.

**Customer access removal** may stop that customer's app view of a shop, but it must not silently erase the owner's historical posted ledger. Later re-linking and any eventual deletion follow the published retention policy. **Account/shop deletion** requires review of outstanding disputes, financial history, backups, idempotency receipts and legal/privacy obligations; do not invent a fixed retention period. The exact policy, deadlines and authorized sign-off are `[NOT YET APPROVED]` and block public release under [SEC-20](SECURITY-REQUIREMENTS.md#7-abuse-limits-privacy-and-operations).

If a user asks what data is held, provide the approved privacy notice and request route. Do not use a statement PDF/CSV as proof that a full operational export or deletion is complete. Restricted production export/deletion requires a named operator, audit record and separate review as described by [SEC-18](SECURITY-REQUIREMENTS.md#7-abuse-limits-privacy-and-operations).

## 7. Service incident and escalation workflow

| Signal | Support-facing action | Engineering/operations action |
|---|---|---|
| Worker 5xx or sign-in outage | State that cloud actions are delayed; do not advise data clearing; record affected versions and request IDs. | Confirm alert, isolate release/route, stop rollout, apply compatible Worker rollback/fix if approved. |
| D1/Worker quota near or at limit | Explain that known-link owner entries may remain phone-only Pending; first-time linking may pause. | Check rows read/written/storage and current quota; reduce nonessential reads/exports, pause onboarding, decide capacity funding. |
| Reconciliation mismatch/duplicate | Pause ordinary financial troubleshooting, mark P0 and protect evidence. | Stop affected writes, inspect immutable rows/receipts, reconcile and follow incident approval for recovery. |
| Cross-tenant exposure | Do not discuss leaked details with unauthorized reporter; mark P0 and route to privacy/security lead. | Contain route/session access, investigate scope, follow notification policy. |
| Backup or migration failure | Tell users only verified service impact; do not promise all data is restored. | Stop promotion/writes as needed; isolate restore, verify foreign keys, balances and receipts before resuming. |
| Mobile update breaks outbox | Tell owners to keep installed app/data, avoid new manual duplicate entries. | Halt app rollout; reproduce on affected version, ship compatible fix preserving operation IDs. |

Incident commander maintains timeline, impact estimate, containment, user-facing notice decision, rollback/restore decision and final reconciliation. The [Deployment Runbook](DEPLOYMENT-RUNBOOK.md#7-incident-triage-and-rollback-decision-tree) governs production recovery. D1 Time Travel restore overwrites the database and may lose later acknowledged writes; it is never a frontline support action. The [Monitoring & Logging](MONITORING-LOGGING.md#6-proposed-alerts-and-first-response) document defines alert triggers and privacy-safe evidence.

## 8. Routine maintenance schedule

| Cadence | Owner | Check and required record |
|---|---|---|
| Daily during pilot/rollout | On-call operations | Worker error/latency, D1 usage/headroom, sync acknowledgment trend, reconciliation alarm, new P0/P1 tickets; record exception/action. |
| Weekly | Engineering + support | Top support categories, app-version adoption, Pending/Needs attention reports, unresolved disputes, data-request backlog, high-rate QR/429 errors, dependency advisories. |
| Per backup schedule | Operations | Verify encrypted export created, checksum, access permissions and age alarm; failed backup is escalated. |
| Per restore-drill interval | Operations + independent reviewer | Restore to isolated environment and compare IDs, row counts, FK integrity, balances and receipts; record elapsed time and gaps. |
| Before every release | QA/security/product/operations | Run applicable test cases, secret/config review, migration rehearsal, incident/rollback packet, release-note and help-text accuracy. |
| After every significant incident | Incident commander | Post-incident review: timeline, root cause, customer impact, what was recovered, preventive action, test/monitor update and owner/date. |

The exact backup frequency, restore interval, support-hours/SLA and metric retention are not yet approved. Fill them before live pilot/launch; an unassigned row is not a completed maintenance check. Dependency or Cloudflare-plan changes should update the [Deployment Runbook](DEPLOYMENT-RUNBOOK.md) and [Monitoring & Logging](MONITORING-LOGGING.md) with the actual current configuration.

## 9. Response templates to adapt

These are **drafts for an authorized support agent**, not messages to send automatically. Fill the verified state and approved support channel; never promise an unverified recovery outcome.

| Situation | Draft wording |
|---|---|
| Pending entry | “Your entry shows **Waiting to sync**, so it is saved on this phone but has not been confirmed by the cloud. Please keep the app data on this phone and try **Retry sync** when connected. Share the error request ID if one appears.” |
| Needs attention | “The entry needs review before it can be posted. Please open it to see the reason. We will not create another charge while we check the original request.” |
| Unknown QR offline | “This customer has not been added to your shop yet. Connect to the internet to check their QR and choose **Add customer**.” |
| Lost phone | “After signing in on a new phone, you can restore entries that had shown **Synced**. Entries still **Waiting to sync** on the old phone were not yet saved in the cloud.” |
| Manual payment | “Cash and UPI are labels entered by the shop owner. The app does not independently confirm that a bank transfer occurred.” |
| Disputed entry | “You can use **Report a problem** on an entry in your own ledger. Reporting it does not change the balance; the shop owner can review and, if needed, add a visible correction.” |
| Cloud outage/quota | “Cloud updates are delayed. Entries for customers already linked to your shop may remain **Waiting to sync** on your phone. New customer linking may be unavailable until service resumes.” |

Translate and review final templates in English and Hindi, including debt direction and sync status. Do not use templates as proof that the app has a working support channel.

## 10. Readiness and handoff checklist

- [ ] Named support owner, privacy owner, on-call engineer and operations contact are assigned with tested channels and coverage hours.
- [ ] Support staff can identify Pending/Synced/Needs attention, account scope and request ID without viewing another tenant's data.
- [ ] Lost-phone, QR, dispute, correction and quota scripts have been rehearsed with synthetic accounts.
- [ ] Data-request policy, identity verification, retention/deletion timeline and secure export delivery are approved and match the app.
- [ ] Backup schedule, isolated restore drill and escalation route are operational and evidenced.
- [ ] P0/P1 incident channel, status notice, update cadence and handoff are tested.
- [ ] English/Hindi templates and the planned [User Manual / Help Documentation](USER-MANUAL-HELP.md) are reviewed against the shipped build.

The next document is the **User Manual / Help Documentation**. It will express these approved user actions plainly. Until the app and policies exist, this SOP is a draft for implementation and training, not a live service commitment.
