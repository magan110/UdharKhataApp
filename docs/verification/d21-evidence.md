# D21 candidate evidence and phone test gates

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../DOCUMENT-MAP.md). **Read with:** [SRS](../../SRS.md) · [Test plan](../../TEST-PLAN.md) · [QA cases](../../TEST-CASES-QA-CHECKLIST.md) · [Private-test operations](../ops/private-test-operations.md).
<!-- DOC_NAV_END -->

Date: 2026-10-02. Scope: D13–D21 private synthetic test candidate. User authorized one continuous implementation and final APK. No real customer data or public release is claimed.

## Verification results

Worker final verification: 106 Vitest tests across 17 files pass; one Node configuration test passes; TypeScript typecheck, ESLint, dry-run build and dependency audit pass (zero known vulnerabilities). Coverage: statements 90.82%, branches 81.71%, functions 98.25%, lines 98.82%, all above 80%.

Flutter final verification: all 236 tests pass, including process-kill persistence checks, actual Hindi widgets at 200% text, cross-account sharing guards and cold-start/revoked in-flight cache tests. Line coverage: 4497/5356 = 83.96% (minimum 80%). Analysis and formatting pass. Staging deployment and APK provenance follow below.

Independent review identified and resolved immutable detail handling, overdue freshness, cross-account sharing, dispute pagination/500-character parsing, Hindi financial labels, and revoked caches. Final privacy review additionally verified cleanup independent of widget lifetime, propagation across ledger/dispute persistent namespaces even on cold start, and rejection of late online responses after revocation. No remaining concrete Critical/Important blocker identified; private synthetic readiness remains conditional on final checks.

Static release checks pass across 263 text files: TLS-only configuration, no contacts permission, Android backup/transfer excluded, cleartext disabled and no recognized private-key/token signatures. This is not an entropy audit or physical-device network/extraction check. Actual Hindi widgets run at 200% text scaling; human Hindi review and TalkBack remain phone gates.

Synthetic restore evidence: three immutable synthetic credit/payment/correction entries; all migration files applied; AES-256-GCM roundtrip and tamper rejection; isolated integrity/foreign-key checks; identical identities/effective projections/receipts; entry sum equals stored projection. Reproduce with `python scripts/restore_drill.py`.

## Requirement traceability

Each SRS identifier has automated evidence or an explicit remaining release gate. Existing D01–D12 evidence remains in implementation Progress; no prior physical-device claim is inferred from a user's brief acceptance message.

| Requirement | Evidence target | Result / remaining gate |
|---|---|---|
| SRS-F-001 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-002 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-003 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-004 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-005 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-006 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-007 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-008 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-009 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-010 | Flutter qr_link_dao_test.dart plus owner local/sync tests and replacement-phone/cache fixtures. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-011 | Flutter qr_link_dao_test.dart plus owner local/sync tests and replacement-phone/cache fixtures. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-012 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-013 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-014 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-015 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-016 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-017 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-018 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-019 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-020 | Worker ledger/correction.test.ts, allocation.test.ts and Flutter correction_test.dart, correction_ui_test.dart, dispute_due_test.dart. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-021 | Worker ledger/correction.test.ts, allocation.test.ts and Flutter correction_test.dart, correction_ui_test.dart, dispute_due_test.dart. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-022 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-023 | Worker ledger/correction.test.ts, allocation.test.ts and Flutter correction_test.dart, correction_ui_test.dart, dispute_due_test.dart. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-024 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-025 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-026 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-027 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-028 | Flutter qr_link_dao_test.dart plus owner local/sync tests and replacement-phone/cache fixtures. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-029 | Flutter qr_link_dao_test.dart plus owner local/sync tests and replacement-phone/cache fixtures. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-030 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-031 | Worker disputes/privacy authorization and lifecycle tests; Flutter dispute_due_test.dart and settings tests. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-032 | Worker disputes/privacy authorization and lifecycle tests; Flutter dispute_due_test.dart and settings tests. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-033 | Flutter sharing/statement_test.dart, localization resources/delegate, preview/native share UI; reconciliation/injection/Unicode tests. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-034 | Flutter sharing/statement_test.dart, localization resources/delegate, preview/native share UI; reconciliation/injection/Unicode tests. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-035 | Worker disputes/privacy authorization and lifecycle tests; Flutter dispute_due_test.dart and settings tests. | Automated candidate evidence; final execution results recorded below. |
| SRS-F-036 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Public-use blocker: reviewed retention/relink policy pending. Access removal preserves immutable owner history; relink denied. |
| SRS-F-037 | Flutter sharing/statement_test.dart, localization resources/delegate, preview/native share UI; reconciliation/injection/Unicode tests. | Automated candidate evidence; final execution results recorded below. |
| SRS-D-001 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-D-002 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-D-003 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-D-004 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-D-005 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-D-006 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Public-use blocker: reviewed retention/relink policy pending. Access removal preserves immutable owner history; relink denied. |
| SRS-N-001 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-N-002 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Static TLS/secure-storage checks and CI APK configuration/signer audit; on-phone traffic inspection pending. |
| SRS-N-003 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-N-004 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-N-005 | scripts/restore_drill.py synthetic encrypted isolated SQLite restore; integrity, foreign keys, IDs, sums and receipts. | Synthetic drill passes; real encrypted D1 backup/storage/custody/operator and remote drill pending before real use. |
| SRS-N-006 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Device/Hindi-speaker gate pending final user APK test; no physical-device evidence claimed. |
| SRS-N-007 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Device/Hindi-speaker gate pending final user APK test; no physical-device evidence claimed. |
| SRS-N-008 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Device/Hindi-speaker gate pending final user APK test; no physical-device evidence claimed. |
| SRS-N-009 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Safe instrumentation and documented thresholds available; measured pilot traffic, remote alarm delivery and named operator pending before real pilot. |
| SRS-N-010 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Automated candidate evidence; final execution results recorded below. |
| SRS-N-011 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Device/Hindi-speaker gate pending final user APK test; no physical-device evidence claimed. |
| SRS-N-012 | Existing authorization, schema, auth, ledger, sync and Flutter regression suites; detailed test paths below. | Safe instrumentation and documented thresholds available; measured pilot traffic, remote alarm delivery and named operator pending before real pilot. |

## Security inspection

Prepared parameter binding is required on all external values; static SQL identifier interpolation is permitted only for fixed internal/test table lists. Every protected route must enforce current role/shop/customer relationship before data and before duplicate replay. Posted rows/receipts remain immutable; revisions and overpayment guarded atomically. Review includes strict parser/body bounds, Google verification/rotation, account generation guards, QR terminal invalidation, outbox original payload retention, CSV injection, PDF/font bounds, native share/temp lifecycle and telemetry allowlisting. Final fresh-review results and fixed findings will be recorded below.

## Physical Android matrix — pending user test

| Device class | Required evidence | Status |
|---|---|---|
| Defined low-end Android API24+ | Model/API, build/hash, camera denial, scan-to-save timing samples, intermittent network/restart | Pending; no device available in workspace |
| Current Android | Model/API, install/update Google sign-in, QR camera, PDF/CSV native share and cancellation | Pending final user APK |
| English + Hindi speaker | Debt direction, corrections/disputes/data requests, errors/recovery/reminder/PDF clarity | Draft localized strings; speaker review pending |
| TalkBack + large font | Reading order, labels, targets, 200% text, scanner/forms/dialogs/share/settings | Widget/static coverage; on-phone TalkBack pending |

## Final phone journey

Update the existing app without uninstalling/clearing storage. Use dummy owner/customer accounts: (1) sign in and language switch, (2) new and repeat QR at two shops, (3) credit with due date, partial/full Cash/UPI payment, (4) airplane-mode repeat QR then unknown QR, save/restart/reconnect and verify one posting, (5) correction ₹500→₹450, cancellation and stale/offline correction, (6) customer dispute and owner resolution without monetary change, (7) reminder preview, bounded PDF/CSV and native share cancel, (8) account switch isolation and device-only request export, (9) customer access removal/request status, (10) replacement phone with same account restores acknowledged records only. Report model/Android version, language, action and displayed error/request ID; do not send tokens, private QR or real ledger data.

D21 remains open for any failed financial/privacy/recovery gate or unperformed mandatory device checks. D22–D24 (participants, real-shop pilot, public launch decision) are outside this delivery.
