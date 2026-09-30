# Udhaar Khata — Monitoring & Logging

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [Deployment runbook](DEPLOYMENT-RUNBOOK.md) · [Security requirements](SECURITY-REQUIREMENTS.md) · [Support SOP](SUPPORT-MAINTENANCE-SOP.md) · [Test plan](TEST-PLAN.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Release:** Android v1  
**Status:** Observability design; dashboards, alerts and telemetry are not yet configured  
**Baseline:** [SRS](SRS.md) · [PRD](PRD.md) · [HLD](HLD.md) · [API Specification](API-SPECIFICATION.md) · [Security Requirements](SECURITY-REQUIREMENTS.md) · [Deployment Runbook](DEPLOYMENT-RUNBOOK.md)

## 1. Purpose and operating principles

Monitoring must answer four questions: **Can people use the app? Are ledger effects exact? Are owner entries reaching D1? Is the free Cloudflare capacity safe?** It must do so without collecting financial contents or user identity in routine telemetry. D1 is authoritative for acknowledged entries; a locally Pending owner entry exists only on that phone until sync. The server cannot see an offline device's queue, so server metrics alone cannot prove that every Pending entry is safe or absent.

This document defines event fields, metric names, dashboard panels, proposed alerts, response ownership and verification. It does not claim those systems are running. The implementation may use Cloudflare Workers Logs/Analytics and D1 Analytics first, with a carefully scoped mobile aggregate diagnostic path if approved. Paid observability is not required to define these controls, but a free-to-user app still needs an operator able to respond to alerts.

## 2. Data classification and prohibited telemetry

Routine logs, analytics and crash reports **must not contain** Google ID/access/refresh tokens, Google `sub`, email, phone, full name, QR public ID or decoded QR payload, shop/customer/entry IDs, client operation IDs, financial amount or balance, note/dispute reason, exported statement body, request/response body, raw SQL parameters, or full URL/query strings that could contain identifiers. Do not use raw IP or persistent device ID as an analytics dimension. The Worker can look up scoped IDs in D1 for an authorized support investigation, but routine telemetry uses a random request ID and route template only.

| Data class | Examples | Allowed handling |
|---|---|---|
| Public operational | Environment, release version, route template, HTTP status, latency bucket | Dashboard and aggregate log. |
| Operational but scoped | Request ID, error code, D1 row count, outbox size/age **bucket** | Restricted logs with configured retention. |
| Financial/identity | Amount, names, notes, QR ID, account/entry/link IDs, token | Never in routine logs/analytics; only D1 and scoped app UI. |
| Sensitive export/backup | PDF/CSV, D1 SQL export, full diagnostic bundle | Restricted encrypted storage with audited access and retention policy. |

The QR resolve endpoint is a read-only **POST** with public ID in a JSON body, not a URL. This prevents ordinary path logs from capturing the ID; raw body logging remains prohibited. Route logs must use `/v1/customer-qr/resolve`, not raw URLs. The [API Specification](API-SPECIFICATION.md#3-owner-shop-and-customer-linking) and [SES](SES.md#5-api-contract-sketch) reflect this change. Check Cloudflare automatic invocation/exception log behavior on the pinned runtime and disable or sanitize any field that would violate this rule before real-user traffic.

## 3. Structured event contract

Every Worker request has a newly generated `requestId`, propagated in the response and through application logs for that request. Log only one bounded completion event plus exceptional safe events; avoid `console.log` of a whole Request, Error object, SQL statement with bound values or JSON body. Use an explicit allowlist serializer. Example:

```json
{
  "event": "api.request.completed",
  "requestId": "req_randomOpaque",
  "atMs": 1790680601000,
  "environment": "staging",
  "workerVersion": "worker_build_42",
  "routeTemplate": "/v1/shops/{shopId}/entries",
  "method": "POST",
  "status": 201,
  "errorCode": null,
  "durationMs": 84,
  "d1RowsRead": 5,
  "d1RowsWritten": 3,
  "outcome": "entry_committed"
}
```

Allowed `outcome` values are a small fixed enum, such as `entry_committed`, `entry_replayed`, `entry_conflict`, `link_created`, `qr_resolved`, `auth_rejected`, `rate_limited`, `capacity_unavailable`, and `read_completed`. Do not put dynamic customer/shop names, operation IDs or exception messages in an outcome. An exception logger emits a safe code and stack location only after redaction; never include request body or SQL bindings. Response `requestId` helps support correlate a user's error without asking for their ledger contents.

Mobile aggregate events, if enabled, have no persistent device ID and no financial values. Proposed events: `onboarding_started/completed` by role, `qr_scan_outcome` by fixed category, `owner_entry_saved_local`, `owner_entry_synced`, `owner_entry_needs_attention`, `customer_history_viewed`, `dispute_started/submitted`, `reminder_previewed/share_opened`, and `export_generated`. Buckets may include app version, OS major version, locale and coarse connectivity. Do not log recipients of Android sharing. Privacy notice and user choices must match the actual collection. If there is no approved mobile telemetry endpoint/provider, leave fleet mobile measures marked **unavailable** rather than silently inferring them from API traffic.

### 3.1 Outbox visibility limit

The app should show its local Pending count and oldest age to the owner. It can report only **coarse aggregate** queue-size and age buckets when online and permitted by the approved privacy design. A phone that stays offline cannot report, so dashboards must label mobile queue metrics as “last reported by online devices.” Server counts of new acknowledgments and retry errors do not reveal the total number of unsynced phone-only records. Support guidance must preserve this distinction.

## 4. Metrics and definitions

| Metric | Definition/source | Dimensions and use |
|---|---|---|
| `worker_requests_total` | Count of Worker requests by route template/status; Cloudflare Analytics or safe completion event | Environment, Worker version, route group, status class. Detect availability and abuse. |
| `worker_5xx_rate` | 5xx / all requests over a fixed window; omit synthetic probes from user-rate view | Same low-cardinality labels. Error-budget signal. |
| `worker_latency_ms` | p50/p95/p99 request duration by route group | Detect slow auth, QR, ledger and export independently. |
| `d1_rows_read_total`, `d1_rows_written_total` | D1 query metadata and account/database analytics | Environment, route group, D1 database; free-tier headroom. |
| `d1_database_size_bytes` | D1 analytics | Database and account totals; per-database cap. |
| `d1_query_latency_ms` | D1 Analytics | Detect expensive/slow query families; no SQL parameter values. |
| `entry_commit_total` | Successful new ledger commits, not replays | Environment, kind only. Compare to receipt creation. No amounts. |
| `entry_replay_total` | Same operation ID/hash returned original receipt | Route/version; spikes may signal flaky network or double taps. |
| `entry_conflict_total` | Validation, balance, revision, idempotency and permission conflicts separately | Fixed error code; detect client or ledger problems. |
| `sync_ack_latency_ms` | On a consenting online device, local-save-to-ack elapsed time for operations that became acknowledged | App version and coarse connectivity only; not meaningful for offline periods without context. |
| `online_outbox_age_bucket` | Last reported age bucket from online devices | Never interpret as all devices. Alert on worsening trend, not exact population. |
| `reconciliation_mismatch_count` | Count of links where authoritative sum differs from projection in a controlled check | Any nonzero value is critical; store affected IDs only in restricted incident record, not metric label. |
| `backup_age_hours`, `restore_drill_age_days` | Last verified encrypted export and isolated restore evidence | Operations readiness; value unavailable until implemented. |
| `data_request_open_count` | Pending export/deletion/access requests by request kind and age bucket | Support workload; no requester identity. |

Cloudflare D1 Analytics exposes query volume, latency, rows read/written and database size, and its D1 binding returns per-query row counts. Its documented analytics retention is 31 days at the time of writing; preserve approved long-term aggregates separately if needed, without copying sensitive query text. [D1 metrics and analytics](https://developers.cloudflare.com/d1/observability/metrics-analytics/). Workers Analytics and Workers Logs provide request/error and log views; configure observability deliberately and inspect automatic fields. [Workers metrics](https://developers.cloudflare.com/workers/observability/metrics-and-analytics/), [Workers Logs](https://developers.cloudflare.com/workers/observability/logs/workers-logs/).

### 4.1 Reconciliation job

A scheduled, bounded, read-only check compares each sampled or partitioned link's `SUM(ledger_entries.effect_paise)` with `ledger_accounts.balance_paise` and confirms every committed entry has the expected operation receipt. It records counts and a restricted investigation handle, never an amount or customer ID in routine metrics. To cover **all** links, partition over multiple runs and track coverage/high-water mark; sampling alone cannot prove global integrity. Tune its read budget so the monitor itself does not exhaust D1 Free allowance. Any mismatch stops financial rollout and invokes the [Deployment Runbook incident path](DEPLOYMENT-RUNBOOK.md#7-incident-triage-and-rollback-decision-tree). Do not silently repair a mismatch with a blind balance update.

## 5. Dashboard layout and review cadence

| View | Panels | Primary reviewer |
|---|---|---|
| **Release health** | Active Worker/app versions, requests, 5xx, p95 latency, auth/QR/entry success, last deployment marker | On-call during rollout, daily in pilot. |
| **Ledger trust** | New commits vs replays/conflicts, payment/revision conflicts, reconciliation coverage/mismatches, dispute count | Worker engineer + QA daily in pilot; immediate on mismatch. |
| **Sync and mobile** | Acknowledged writes, retry categories, last-reported online queue age/size buckets, app crashes, app versions | Flutter engineer/support daily; note offline visibility gap. |
| **Capacity** | D1 rows read/written by day and route, storage/account caps, Workers requests, row cost per owner-home/QR/entry/export | Operations daily in pilot, more often near threshold. |
| **Recovery/privacy** | Backup age, last restore drill, data-request backlog, rate-limit counts, redaction audit result | Operations/security weekly and before launch. |

No panel uses shop/customer ID as a label; high-cardinality identifiers create privacy and cost problems. Include environment and release annotations so a spike can be tied to a rollout. During public rollout, on-call reviews release health and capacity at each traffic step; after stability, establish a documented daily/weekly cadence and backup owner.

## 6. Proposed alerts and first response

Thresholds below are **initial staging/pilot proposals**. Tune against baseline traffic and the currently published Cloudflare plan before real users; record alert owner, destination and tested delivery. A low-volume system should use a minimum request count to avoid noisy ratios.

| Alert | Trigger proposal | Severity / first response |
|---|---|---|
| Ledger mismatch | `reconciliation_mismatch_count > 0`, or receipt/entry count invariant fails | **P0**: stop new financial writes/rollout, preserve evidence, investigate before resuming. |
| Suspected cross-tenant leak or secret in log | Any verified occurrence | **P0**: contain affected route/log sink, revoke exposure as needed, initiate security incident. |
| Worker availability | 5xx >2% for 10 min with ≥50 user requests, or synthetic authenticated probe fails 3 times | **P1**: inspect deployment/version and D1 status; halt rollout; keep app Pending honest. |
| Sync degradation | Online acknowledgment p95 >5 min for 30 min, with ≥30 online samples, or sharply rising retryable failures | **P1/P2**: segment by app/Worker version and connectivity; check D1 quotas. Do not infer offline-phone counts. |
| D1 read/write quota | Watch at 60%, action at 80% of current daily free allowance; projected 24-hour use > allowance | **P1**: reduce nonessential reads/exports and pause onboarding; confirm Pending messaging. |
| D1 storage | Watch at 60%, action at 80% of per-database or account cap | **P1**: review retention/index growth and capacity plan; do not purge receipts/ledger ad hoc. |
| Backup stale or restore drill overdue | Export exceeds approved schedule or drill exceeds approved interval | **P1 before real-user release**; operations repairs and repeats drill. |
| Data requests overdue | Open request age exceeds published support/privacy target | **P2 or policy severity**: support owner triages without exposing requester data in metrics. |
| Telemetry silence | Synthetic probe succeeds but no expected completion events for 15 min during observed traffic | **P2**: check logging pipeline/config; avoid claiming service down solely from missing logs. |

Rate-limit/429 spikes should be reviewed by route and shared-network context; a spike may be abuse or a false positive affecting a busy shop. Quota alarms should use **UTC daily reset** and current provider definitions. D1 Free currently lists 5 million rows read/day and 100,000 rows written/day, with 5 GB total storage and a 500 MB per-database cap; limits may change and are not a product promise. [D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/), [D1 limits](https://developers.cloudflare.com/d1/platform/limits/).

## 7. Logging implementation and retention controls

1. Implement a schema-enforced allowlist logger; reject unexpected keys rather than spreading arbitrary objects. Use route templates, not raw paths, so future URL parameters cannot leak into logs.
2. Keep production log level at outcome/error class. Debug logging of payloads is forbidden even during incidents; use a restricted, time-bound diagnostic path with explicit authorization if deeper inspection is necessary.
3. Sample routine successful requests if volume rises, but preserve complete counts through aggregate platform metrics and retain all safe error/critical events within quota. Do not sample away the only ledger-mismatch signal.
4. Configure Workers Logs observability and access intentionally. Test whether invocation logs, uncaught exceptions or third-party crash tools include raw URL, body or headers; disable unsafe fields or sanitize before collection. No Authorization header is ever recorded.
5. Set log/metric retention and deletion from the approved privacy policy. Restrict dashboard/export access to named operators with MFA; audit access to sensitive diagnostic exports. Avoid an unbounded external analytics sink that would undermine the free-cost plan.
6. Use a synthetic-data redaction test in CI/staging: send unique sentinel email, token, QR ID, name, note and amount through success, validation, server error and crash paths; search every configured sink. Any sentinel in routine telemetry blocks real-user release.

The app's own error screen may show a request ID and safe message key. Support should ask for that ID, app version and approximate time, not a full QR screenshot or transaction note by default. A full statement or device database should be collected only through a separately approved support workflow.

## 8. Incident workflow and verification

When an alert fires: **acknowledge → verify data/source → classify user impact → contain → investigate → recover → reconcile → close with evidence**. On-call records time, version, route group, alert condition, affected feature, actions and sanitized request IDs. For balance or privacy incidents, stop rollout immediately and use the P0 path in the [Deployment Runbook](DEPLOYMENT-RUNBOOK.md#7-incident-triage-and-rollback-decision-tree). For quota incidents, preserve the owner's local Pending queue and communicate that it is not cloud-backed up. Never fix an unexplained balance mismatch by editing ledger rows directly.

Before public use, stage synthetic incidents and prove that: Worker 5xx alert delivers to the named on-call; a D1 quota simulation shows capacity alert and correct Pending UI; a reconciliation mismatch pages the owner without leaking an amount; stale-backup alarm reaches operations; QR/body sentinels do not appear in logs; request ID can connect a user report to safe server events; dashboard labels make the offline Pending visibility limit explicit. Record the test date, configuration version, evidence and any missed alert. Retest after changing telemetry configuration or providers.

## 9. Open operational decisions

| Decision | Required before |
|---|---|
| Exact on-call destination, named owners and response windows | Real-user pilot. |
| Approved mobile telemetry collection/consent and crash-report tool | Enabling mobile analytics. |
| Production log/aggregate retention, restricted diagnostic policy and privacy wording | Public launch. |
| Final thresholds based on pilot baseline, Cloudflare plan and false-positive review | Public launch. |
| Backup schedule/restore drill interval and alert source | First real financial record. |
| Reconciliation partition size and complete-coverage interval under quota budget | Public launch. |

The next **Support / Maintenance SOP** should use these alert and request-ID conventions for user reports, account recovery, disputes, data requests and service incidents. Keep this document updated when a deployed dashboard, telemetry source or Cloudflare plan changes; do not mistake a dashboard design for proof that alerts exist or work.
