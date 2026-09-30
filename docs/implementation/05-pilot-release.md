# Milestone 5 — private test, pilot and launch decision (D21–D24)

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../DOCUMENT-MAP.md). **Read with:** [Daily implementation plan](README.md) · [Roadmap](../../PROJECT-PLAN-ROADMAP.md) · [Test plan](../../TEST-PLAN.md) · [Deployment runbook](../../DEPLOYMENT-RUNBOOK.md) · [Release notes](../../RELEASE-NOTES.md).
<!-- DOC_NAV_END -->

**Exit gate:** evidence supports launch, extended pilot or scope revision; no automatic public release. Source: [Roadmap phase 4](../../PROJECT-PLAN-ROADMAP.md#phase-4--private-test-pilot-and-release-decision), [Test Plan](../../TEST-PLAN.md), [QA checklist](../../TEST-CASES-QA-CHECKLIST.md), [Security gates](../../SECURITY-REQUIREMENTS.md#8-required-security-tests-and-release-gates), [Deployment](../../DEPLOYMENT-RUNBOOK.md).

## D21 — synthetic full regression and security audit

**Dependencies:** D20 and all earlier gates. **Files:** `services/api/test/e2e/`, `udhaarkhata/integration_test/`, `docs/verification/{traceability,security-review,device-matrix}.md`, defect fixes in the owning modules.

1. Run every applicable SRS verification journey and the [QA checklist](../../TEST-CASES-QA-CHECKLIST.md) with synthetic accounts: new/repeat QR, cross-shop/customer, credit, payment, duplicate retry, offline restart, quota, correction, dispute, share/export, account switch, replacement phone.
2. Run authorization matrix on every protected route and inspect D1 prepared statements, session rotation, QR parser, receipt uniqueness, correction/payment races, migration upgrade and release Android manifest. Verify no client credential, D1 binding secret, cleartext API or sensitive telemetry.
3. Test selected low-end and current Android devices/API levels, camera permission denial, intermittent network, English/Hindi, TalkBack and large text. Record actual device versions, run ID, failures and fixes. Reconcile all account/link balances from immutable entry sums.

**Checks:** complete Flutter and Worker suites, dependency audit, migration/restore, manual security checklist, static secret scan and device test report. **DoD:** no open balance, duplicate, cross-tenant privacy, pending-loss or recovery blocker; every SRS requirement has passing evidence or a documented release-blocking gap. A failed gate remains D21.

## D22 — approved private distribution and usability repair

**Dependencies:** D21. **Files:** `docs/pilot/{private-test-protocol,consent,findings}.md`, localized app/help text and code/test fixes, [user manual](../../USER-MANUAL-HELP.md), [release notes](../../RELEASE-NOTES.md).

1. Prepare a concrete private-test packet: target participants/devices, consent, dummy-data setup, expected tasks, observation form, support contact and withdrawal path. Get approval before distributing builds or inviting participants; external messaging/distribution is not implied by this plan.
2. Test QR scan-to-entry time and comprehension with representative shop owners/customers. Record install/Google sign-in refusal, invalid scan, wrong identity, debt-direction misunderstanding, offline status confusion and accessibility issues without storing private ledger values.
3. Fix blockers and re-run affected automated/device tests. Compare findings against initial product bet; if customers will not install/sign in, create a scoped change proposal before introducing alternate identity flows.

**Checks:** signed/private artifact provenance, consent and sanitized findings, targeted regression, no high-severity usability/security blocker. **DoD:** private-test findings and fixes are reviewable; only after approval does distribution actually occur.

## D23 — approved real-shop pilot and operations drill

**Dependencies:** D22, approved privacy policy, encrypted backup/restore, named operators and explicit authorization for real data. **Files:** `docs/pilot/{pilot-plan,weekly-results,incident-log,quota-report}.md`, defect fixes/tests, `docs/ops/restore-evidence.md`.

1. Plan 3–5 shops for 2–4 weeks as the existing roadmap proposes. One day's phase is **pilot setup and first supervised day**, not a claim that multiweek observation fits one day. Monitor adoption, scan-to-save median (SRS target under 15 seconds on defined low-end device), duplicates, correction/dispute rates, pending queue age, balance reconciliation, support burden and D1/Worker usage.
2. Rehearse quota and incident response. Check backup completion and restore evidence before/through real use; monitor alerts without logging identities/amounts. Investigate every unexplained balance or sync discrepancy before adding users.
3. Continue weekly pilot cycles as needed while D23 remains In progress. Record consent, anonymized aggregate results, actual costs, defects and fixes; re-run regression for fixes. Pause onboarding or pilot if data integrity/privacy/recovery gate fails.

**Checks:** daily reconciliation sample, queue-age/usage dashboards, dated incident and restore drill, defined low-end timing sample. **DoD:** intended observation window is complete with evidence and no unresolved safety blocker. If the pilot has not run long enough, D23 remains open on subsequent days.

## D24 — launch decision and prepared release

**Dependencies:** completed D23. **Files:** `docs/release/{decision-packet,checklist,rollback-record}.md`, [release notes](../../RELEASE-NOTES.md), [deployment runbook](../../DEPLOYMENT-RUNBOOK.md), [support SOP](../../SUPPORT-MAINTENANCE-SOP.md), store listing/privacy/help drafts and final code fixes.

1. Assemble traceability: all SRS/PRD P0/P1 evidence, unresolved defects, pilot adoption and timing, balance reconciliation, security review, recovery RPO/RTO drill, quota forecasts, support ownership, app signing, Android device coverage and English/Hindi review. Decide launch / extend pilot / revise product with reasons.
2. Prepare release artifacts and store listing draft, versioned migration and Worker/app compatibility order, staged rollout and rollback criteria. Run a final staging rehearsal and verify post-deploy smoke tests with synthetic records; remote staging action requires approval.
3. For launch, obtain explicit user/product-owner approval before production migration, Worker deployment, Google/Cloudflare changes, Play Store submission or real-user distribution. Execute the [runbook](../../DEPLOYMENT-RUNBOOK.md) only after approval, then record release version, monitoring, and first-week support checks. If approval is not given, the phase can finish as a **prepared decision packet**, but production release remains pending.

**Checks:** final CI/audit, signed artifact inspection, migration/restore rehearsal, smoke/rollback rehearsal, decision sign-off, support readiness. **DoD:** launch decision packet is complete and truthful; public release is marked done only when separately approved, deployed, verified and monitored. An extend/revise decision has an explicit next plan.

## Ongoing maintenance after release

Use [Monitoring and Logging](../../MONITORING-LOGGING.md), [Support SOP](../../SUPPORT-MAINTENANCE-SOP.md), [Deployment Runbook](../../DEPLOYMENT-RUNBOOK.md), and [Coding Standards](../../CODING-STANDARDS-DEVELOPMENT-GUIDELINES.md) as operational references. Each release cycle: triage incidents and support, review queue age/balance anomalies/quotas, inspect dependency/security updates, run backup checks and periodic restore drills, review access and retention requests, test schema/app compatibility, update release notes and localized help, and keep the SRS/PRD/API/data contracts aligned with behavior. Never modify posted financial history to resolve a support issue; use auditable corrections and documented operator procedures.
