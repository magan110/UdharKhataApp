# Milestone 4 — first-release completeness (D16–D20)

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../DOCUMENT-MAP.md). **Read with:** [Daily implementation plan](README.md) · [PRD](../../PRD.md) · [SRS](../../SRS.md) · [Deployment runbook](../../DEPLOYMENT-RUNBOOK.md) · [User manual](../../USER-MANUAL-HELP.md).
<!-- DOC_NAV_END -->

**Exit gate:** P0/P1 release features, data controls, recovery, localization, accessibility, quota behavior and operating procedures are ready for private testing. Source: [Roadmap phase 3](../../PROJECT-PLAN-ROADMAP.md#phase-3--first-release-completeness), [PRD priorities](../../PRD.md#5-release-scope-and-priorities), [SRS](../../SRS.md), [Security](../../SECURITY-REQUIREMENTS.md).

## D16 — due dates and deterministic overdue totals

**Dependencies:** D15. **Files:** `services/api/src/ledger/{allocation,overdue}.ts`, `test/ledger/overdue*.test.ts`, `udhaarkhata/lib/features/ledger/{credit_form,ledger_page,due_summary}.dart`, `DATABASE-DESIGN-ERD.md` and `API-SPECIFICATION.md` if projection changes.

1. Store optional ISO calendar due date on credit only. Define effective dated credit after corrections; allocate acknowledged payments to oldest unpaid credit by due date, then server sequence/ID, with undated credits last. Document timezone-free due-date semantics and how cancelled/reduced credits reallocate payments.
2. Implement a pure allocation function used by server summaries and independent test oracle. Keep total balance equal to signed entry sum; overdue is a subset, never a separate ledger effect.
3. Expose due date and tested overdue summary in owner UI; avoid an overdue number if allocation data is stale or incomplete.

**Checks:** multiple credits/dates, partial/full payments, corrections before/after payments, undated credit, pagination-independent totals and property/invariant tests. **DoD:** overdue result is deterministic and reconciles with total balance under documented rules.

## D17 — reminder and audited exports

**Dependencies:** D16. **Files:** `udhaarkhata/lib/features/sharing/{reminder_preview,statement_pdf,export_csv,share_controller}.dart`, `services/api/src/export/{routes,queries}.ts` if server export is required, tests and fixtures; `API-SPECIFICATION.md` for selected export contract.

1. Build owner-reviewed reminder with shop/customer, known balance, as-of/sync status and Hindi/English template. Launch Android share sheet only after explicit owner action; no automatic WhatsApp/SMS integration.
2. Generate bounded-period PDF customer statement and CSV with opening balance, ordered entries/corrections and closing balance. Define whether owner export includes device-only Pending in a clearly separate section; never fold Pending into acknowledged totals.
3. Prevent CSV formula injection, escape PDF/user text, bound export period/size, store temporary files privately and clean them after reasonable lifecycle. Show recipient and sensitivity before sharing.

**Checks:** independent sum/export reconciliation, date bounds, injection strings, Unicode/Hindi, empty period, large bounded period, share cancel and temp-file inspection. **DoD:** owner can deliberately share accurate, clearly scoped output with no automatic dispatch.

## D18 — localization, accessibility and help

**Dependencies:** D17. **Files:** `udhaarkhata/l10n/{app_en.arb,app_hi.arb}`, `lib/app/localization.dart`, all critical feature pages, `USER-MANUAL-HELP.md`, widget/accessibility tests.

1. Move all critical strings, API `messageKey` mappings, currency/debt direction, statuses, reminders and errors to Flutter localization. Set English/Hindi selection and persist preference per account/device as appropriate.
2. Review Hindi wording with speakers; ensure **Customer owes you** versus **You owe [shop]** is unambiguous. Format INR and dates consistently without floating-point calculations.
3. Add semantic labels for QR, scanner, balances, errors and status; support text scaling, adequate targets/contrast, TalkBack reading order and camera-denial alternative guidance. Write concise help for offline/pending/new-phone limitations.

**Checks:** English/Hindi full critical journeys, missing-string scan, font-scale and TalkBack manual pass on a supported device, screenshot review. **DoD:** a user can complete sign-in through ledger/dispute/share in either language and understand debt direction without color alone.

## D19 — data controls, privacy and backup/restore

**Dependencies:** D18. **Files:** `services/api/src/privacy/{requests,access_removal,retention}.ts`, migration if needed, `udhaarkhata/lib/features/settings/{data_export,access_removal,deletion_request}.dart`, `docs/ops/{privacy-data-map,backup-restore-evidence}.md`, updates to [runbook](../../DEPLOYMENT-RUNBOOK.md), [security](../../SECURITY-REQUIREMENTS.md), [SRS](../../SRS.md) and [PRD](../../PRD.md).

1. Implement tracked owner shop-data export/deletion request and customer account-deletion/access-removal request with authorized status. Do not silently erase historical owner ledger on customer unlink. Specify relink behavior and publication-ready retention periods through product/privacy review; defer actual destructive deletion until policy and operator workflow are approved.
2. Inventory personal data, session records, QR IDs, backups, exports and logs. Define who can see each item, retention schedule, support evidence and revocation effects. Verify app text accurately describes what requests do.
3. Design encrypted operational D1 backup to separately controlled storage, key custody, schedule, RPO/RTO and named restore owner. Rehearse restore into an isolated local or approved nonproduction environment; check foreign keys, IDs, operation receipts, per-link sums and sample replay. Real production backup location/setup needs approval.

**Checks:** role/path tampering, request-state transitions, access removal/relink, privacy data inventory, dated restore drill with reconciliation. **DoD:** data controls match published policy and a synthetic production-like restore is proven; real-data use remains blocked until actual backup and policy approvals are complete.

## D20 — monitoring, quota control and release candidate

**Dependencies:** D19. **Files:** `services/api/src/telemetry/{metrics,redaction,rate_limits}.ts`, `udhaarkhata/lib/core/sync/status_ui.dart`, `docs/ops/{dashboards,quota-playbook}.md`, CI/release configuration, [monitoring](../../MONITORING-LOGGING.md), [runbook](../../DEPLOYMENT-RUNBOOK.md).

1. Instrument route-template request/error/latency, auth/QR/ledger rejection class, outbox age/status and Cloudflare usage without amounts, notes, names, tokens, Google subject or QR IDs. Add rate limits to auth, QR, financial commands, disputes and exports, tuned on realistic shared-network traffic.
2. Define warning/action thresholds for Worker/D1 limits from current vendor terms and measured traffic. On quota/service failure, preserve known-link owner writes locally Pending; prevent first-time link with clear reason. Provide manual retry, support request ID and no false backup claim.
3. Configure separate env files/bindings, migration order, compatibility version check, secret scan, reproducible Android artifact, release signing/key custody plan, rollback and incident runbook. Do not deploy automatically without approval.

**Checks:** synthetic quota outage, rate-limit false-positive test, telemetry redaction sample, dependency audit, full Flutter/Worker CI, migration upgrade/rollback rehearsal, release manifest/backup exclusion review. **DoD:** feature-complete candidate and operations packet are ready for D21; any real remote change remains explicitly approval-gated.
