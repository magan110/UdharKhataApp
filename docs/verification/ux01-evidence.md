# UX01 redesign verification evidence

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../DOCUMENT-MAP.md). **Read with:** [UX01 selected design](../superpowers/specs/2026-10-03-ux01-redesign-design.md) · [UX01 implementation plan](../superpowers/plans/2026-10-03-ux01-redesign.md) · [Implementation progress](../implementation/PROGRESS.md).
<!-- DOC_NAV_END -->

Date: 3 October 2026. Worktree `/workspace/ux01-redesign`, branch `codex/ux01-redesign`, original baseline `d75788a`. Status: presentation implementation and local checks complete; fresh whole-branch review and signed APK pending. This document does not claim physical Android acceptance, native-surface screenshots, real-user usability, Hindi-speaker review or public-use readiness.

## Verification boundaries

Selected generated owner-home image is design direction only. Synthetic Flutter widget captures use actual production screen widgets with test-only providers/native substitutes; they are not phone screenshots. Baseline captures refer to immutable source `d75788a` from `/workspace/ux01-baseline`. Native Google sign-in, real camera/QR lighting, native Android permissions/settings/share, installed Hindi fonts, TalkBack, signer update, traffic and replacement-phone checks require phone/CI evidence.

All fixtures use synthetic IDs/amounts/dates and memory providers. No fixture contacts an API or opens customer SQLite storage. Existing regression tests may use isolated synthetic databases as before; capture fixtures do not use database I/O.

## Checkpoints

- Foundation `3f8f65d`: formatter missing-import RED; integer-paise Indian grouping, large Hindi shared review and contrast plus smoke/resources: 6 pass. Exact commands/logs in persistent execution ledger.
- Counter/navigation `f55ff62`: grouped review, navigation and session-error overflow RED→GREEN; 67 affected tests pass. Home total is server-only, Pending separate, preview server order and More/sign-out scope tested.
- History/customer/disputes/settings checkpoint `8d66dce`: 89 affected tests pass; actual Hindi Credit/Payment large-text and localization/ledger checks: 7 pass. Focused dispute context tests: 4 pass. Root reported a fresh full suite of 260 passing tests and 87.49% coverage (4,943/5,650); subsequent workspace/localization/fixture refinements require the final rerun. Final checks remain pending until root records their exact snapshot.
- Renderer commands: from Flutter app cwd, `/tmp/ux01_flutter.sh test test/ui/ux01_capture_test.dart --dart-define=UX01_CAPTURE=true --update-goldens`: 292 pass in the final combined batch (`/tmp/ux01-final292-captures.log`), including actual 320px/200% Hindi Credit and Payment validation renders. Immutable-baseline adapter: 70 pass. These counts prove no renderer test failures, not physical or complete variant acceptance.

## Source and financial safety

No backend/API/schema/repository/accounting changes are planned. UI-only integer formatter preserves original parser and export formatter. Existing operation/retry/durable Pending/account generation/cache-revocation guards remain in source and are covered by existing regression plus focused UI tests. Full completion requires recorded final analyze/tests/coverage and fresh review.

## Capture coverage

[Capture manifest](ux01-captures/manifest.json) records 362 images: 292 redesigned widget renders and 70 immutable-baseline renders. Each row pins image SHA256, logical dimensions, locale/text scale, production source, synthetic fixture, scenario and inspection result. Source-file hashes pin the exact presentation and fixture files. The final immutable source checkpoint is recorded in the manifest after the local checkpoint commit.

All 41 initial redesign contact sheets and all 12 baseline contact sheets were visually inspected with `view_image`. Initial inspection rejected 16 redesigned rows for untranslated validation, inconsistent fixture arithmetic/retry/cache state, missing Material ancestry or mislabeled long-name/overpayment scenarios. Root corrected those defects; changed/new images were inspected again across 14 followup contact sheets and final individual images. The final corrected-customer Hindi provenance label was localized, regenerated and inspected individually; all initially rejected rows are replaced and inspected. Final large-text validation images show the complete wrapped error text; controls remain reachable by scrolling, as checked by the owning form tests.

Every plan variant now has an individual manifest record: captured/inspected, a separately identified behavior test with shared visual, or native camera runtime pending. Added production-screen interactions cover actual authentication/router outcomes, setup creating/error, server pagination, partial/negative workspace source, corrected history, matched/missing dispute context, statement date bounds/reconciliation/share controls, and data request submission. Cancellation execution has owning interaction tests plus the modal/control capture; a distinct post-cancel screenshot is not implied. Scanner ready/resolving/unsupported/revoked/unknown-offline camera surfaces depend on `mobile_scanner` native camera/controller lifecycle; controller tests cover guards, while phone evidence remains pending.

Normal renders are 390×844 logical pixels, with selected Hindi 320×844 at 200% text and 844×390 landscape variants. Review/detail captures may be scrolled to reachable controls; identity outside that viewport is not claimed simultaneously visible. Full amounts may wrap at large text; no amount is accepted by truncating digits. Test-only bundled Noto fonts make renderer text readable and do not verify installed Android font fallback.

`settings-requests-latest100` uses one synthetic row plus the incomplete/latest-100 warning, not 100 rendered records. Scanner captures render the actual camera-error component inside Material scaffolding; they do not prove native camera readiness, permission dialogs, decoding or device settings. Native share/account chooser, TalkBack and Hindi-speaker comprehension remain phone checks.

## Phone acceptance packet

Candidate: Udhaar Khata 0.3.0+3, package `com.udhaarkhata.app`. Install as an update over the D21 build after signer verification; preserve device-only Pending entries. The stable signing key is available only to the existing GitHub Actions build. No redesigned APK has been produced yet.

| Check | Phone procedure | Acceptance / record |
|---|---|---|
| Device/build | Record model, Android API, APK source/hash and installed version; test API24+ low-end and current Android. | Exact audited candidate; successful update preserving account/Pending. |
| Sign-in/navigation | Google sign-in, owner/customer roles, three root tabs, task Back and deep links. | Correct role; task returns to originating tab; root Back returns Home/My QR. |
| Camera/link | Allow/deny camera, open settings, new/repeat QR, known offline and unknown offline. | Correct customer review; unknown offline cannot link; scan never posts money. |
| Credit/payment | Enter credit with due date, Cash and manual UPI; edit review then save. | Full identity/amount visible; UPI described as manually recorded. |
| Pending/retry | Save offline, restart, reconnect; repeat Submit and retry unknown outcome. | Pending described as device-only; original attempt retained; one posting after acknowledgement. |
| History/due | Confirmed/local history, correction provenance, partial refresh, overdue expiry. | Sources/freshness explicit; unavailable amount never represented as zero. |
| Disputes | Report loaded entry, open direct link without context, resolve second card. | Honest context/ID; selected response; unchanged debt. |
| Sharing | Preview bounded statement/reminder, share PDF/CSV, cancel native chooser. | Acknowledged entries only; no claimed delivery on cancellation. |
| Hindi/accessibility | Hindi-speaking review; 200% text; TalkBack; keyboard and landscape. | Amount/status/control readable, ordered semantics, reachable Cancel/Submit, no clipped controls. |
| Privacy/account | Cancel sign-out/removal/device copy; switch accounts; request/status history. | Pending preserved on cancel; denied/old-account caches absent; request is not completed deletion. |
| Recovery | Replace device using synthetic acknowledged ledger only. | Acknowledged history restored; device-only Pending loss boundary understood. |
| Counter usability | Time repeat scan→workspace→review→local receipt; ask owner to identify customer, amount, source and next step. | Record timings, mistakes and comprehension rather than infer usability from screenshots. |

All physical, native Google/camera/share, TalkBack and Hindi-speaker checks remain pending until performed on phones. UX01 does not close D22–D24, public-use policy or production-backup gates.

## Final local verification (3 October 2026)

- `/tmp/ux01_flutter.sh test --coverage`: **262 tests pass**, 87.61% line coverage (4,965/5,667), `/tmp/ux01-final-suite.log`. Opt-in image generation is separately verified by its 292-test renderer batch.
- `/tmp/ux01_flutter.sh analyze`: **no issues**, `/tmp/ux01-final-analyze3.log`. Final test-helper cleanup removed unused imports and added the standard widget key without changing fixture behavior.
- `dart format --output=none --set-exit-if-changed lib test`: 153 files, zero changes. Final copy/workspace/statement/resource checks: **10 pass**, `/tmp/ux01-final-focused.log`.
- `python scripts/check_docs.py`, `python scripts/update_doc_navigation.py --check`, `git diff --check`: pass. All 362 PNG hashes match their manifest; 129 required variant records are present.
- Diff against `d75788a` contains no backend, core, repository, accounting, schema or lockfile changes. Generated desktop plugin noise from Flutter tooling was restored.
- Local `flutter build apk --debug --no-pub` with the existing staging endpoint and Google audience stops with **No Android SDK found**, `/tmp/ux01-local-apk.log`. Existing stable-key CI build invocation will be prepared against the independently reviewed immutable source. No new signer or remote change is authorized by the local implementation plan.

Root regression fixes retain their RED→GREEN evidence: statement shop identity/snapshot metadata; owner workspace provisional/synced amounts with complete and partial freshness; translated payment validation/correction reason/conflict; Hindi original-entry provenance; multiline large-text validation. Focused fixture tests verify credit/payment arithmetic and retained attempts. Renderer refinements were regenerated and inspected as described above.

## Execution rulings

1. The user-requested dedicated UI/UX agent implements Tasks 1–9; root owns final review, version and APK preparation. This preserves the requested assignment and keeps remote actions outside local scope.
2. Payment review retains its existing control tree and rejection/uncertain-attempt branches, using shared identity/receipt/theme components instead of forcing the generic review wrapper. The tradeoff is less component reuse; financial action availability and original retry bodies remain unchanged.
3. Capture-helper style/key/import cleanup is presentation-neutral. Existing renderer evidence remains valid because production widgets and fixture state are unchanged; source hashes are refreshed and focused fixture tests rerun.

Fresh review results and any deferred minor findings will be added here before delivery. Five native camera-runtime variants plus the phone acceptance matrix remain pending.
