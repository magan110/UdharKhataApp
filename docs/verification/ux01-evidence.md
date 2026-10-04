# UX01 redesign verification evidence

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../DOCUMENT-MAP.md). **Read with:** [UX01 selected design](../superpowers/specs/2026-10-03-ux01-redesign-design.md) · [UX01 implementation plan](../superpowers/plans/2026-10-03-ux01-redesign.md) · [Implementation progress](../implementation/PROGRESS.md).
<!-- DOC_NAV_END -->

Date: 3 October 2026. Worktree `/workspace/ux01-redesign`, branch `codex/ux01-redesign`, original baseline `d75788a`. Status: presentation implementation, local checks and independent review/fix pass complete; stable-signed APK produced/audited and delivered for synthetic phone testing; physical acceptance pending. This document does not claim physical Android acceptance, native-surface screenshots, real-user usability, Hindi-speaker review or public-use readiness.

## Verification boundaries

Selected generated owner-home image is design direction only. Synthetic Flutter widget captures use actual production screen widgets with test-only providers/native substitutes; they are not phone screenshots. Baseline captures refer to immutable source `d75788a` from `/workspace/ux01-baseline`. Native Google sign-in, real camera/QR lighting, native Android permissions/settings/share, installed Hindi fonts, TalkBack, signer update, traffic and replacement-phone checks require phone/CI evidence.

All fixtures use synthetic IDs/amounts/dates and memory providers. No fixture contacts an API or opens customer SQLite storage. Existing regression tests may use isolated synthetic databases as before; capture fixtures do not use database I/O.

## Checkpoints

- Foundation `3f8f65d`: formatter missing-import RED; integer-paise Indian grouping, large Hindi shared review and contrast plus smoke/resources: 6 pass. Exact commands/logs in persistent execution ledger.
- Counter/navigation `f55ff62`: grouped review, navigation and session-error overflow RED→GREEN; 67 affected tests pass. Home total is server-only, Pending separate, preview server order and More/sign-out scope tested.
- History/customer/disputes/settings checkpoint `8d66dce`: 89 affected tests pass; actual Hindi Credit/Payment large-text and localization/ledger checks: 7 pass. Focused dispute context tests: 4 pass. Root reported a fresh full suite of 260 passing tests and 87.49% coverage (4,943/5,650); subsequent workspace/localization/fixture refinements require the final rerun. The final review-fix verification and source snapshot below supersede this intermediate checkpoint.
- Renderer commands: from Flutter app cwd, `/tmp/ux01_flutter.sh test test/ui/ux01_capture_test.dart --dart-define=UX01_CAPTURE=true --update-goldens`: 292 pass in the final combined batch (`/tmp/ux01-final292-captures.log`), including actual 320px/200% Hindi Credit and Payment validation renders. Immutable-baseline adapter: 70 pass. These counts prove no renderer test failures, not physical or complete variant acceptance.

## Source and financial safety

No backend/API/schema/repository/accounting changes are planned. UI-only integer formatter preserves original parser and export formatter. Existing operation/retry/durable Pending/account generation/cache-revocation guards remain in source and are covered by existing regression plus focused UI tests. Full completion requires recorded final analyze/tests/coverage and fresh review.

## Capture coverage

[Capture manifest](ux01-captures/manifest.json) records 362 images: 292 redesigned widget renders and 70 immutable-baseline renders. Each row pins image SHA256, logical dimensions, locale/text scale, production source, synthetic fixture, scenario and inspection result. Source-file hashes pin the exact presentation and fixture files. The initial immutable capture source is `7c5d55566cf7d1684fecdd94ebf551c5fff04d5d`. The final source hashes and20 review-fix renders are pinned to the final checkpoint below;272 unchanged redesign captures retain their original source reference.

All 41 initial redesign contact sheets and all 12 baseline contact sheets were visually inspected with `view_image`. Initial inspection rejected 16 redesigned rows for untranslated validation, inconsistent fixture arithmetic/retry/cache state, missing Material ancestry or mislabeled long-name/overpayment scenarios. Root corrected those defects; changed/new images were inspected again across 14 followup contact sheets and final individual images. The final corrected-customer Hindi provenance label was localized, regenerated and inspected individually; all initially rejected rows are replaced and inspected. Final large-text validation images show the complete wrapped error text; controls remain reachable by scrolling, as checked by the owning form tests.

Every plan variant now has an individual manifest record: captured/inspected, a separately identified behavior test with shared visual, or native camera runtime pending. Added production-screen interactions cover actual authentication/router outcomes, setup creating/error, server pagination, partial/negative workspace source, corrected history, matched/missing dispute context, statement date bounds/reconciliation/share controls, and data request submission. Cancellation execution has owning interaction tests plus the modal/control capture; a distinct post-cancel screenshot is not implied. Scanner ready/resolving/unsupported/revoked/unknown-offline camera surfaces depend on `mobile_scanner` native camera/controller lifecycle; controller tests cover guards, while phone evidence remains pending.

Normal renders are 390×844 logical pixels, with selected Hindi 320×844 at 200% text and 844×390 landscape variants. Review/detail captures may be scrolled to reachable controls; identity outside that viewport is not claimed simultaneously visible. Full amounts may wrap at large text; no amount is accepted by truncating digits. Test-only bundled Noto fonts make renderer text readable and do not verify installed Android font fallback.

`settings-requests-latest100` uses one synthetic row plus the incomplete/latest-100 warning, not 100 rendered records. Scanner captures render the actual camera-error component inside Material scaffolding; they do not prove native camera readiness, permission dialogs, decoding or device settings. Native share/account chooser, TalkBack and Hindi-speaker comprehension remain phone checks.

## Phone acceptance packet

Candidate: Udhaar Khata 0.3.0+3, package `com.udhaarkhata.app`. Install as an update over the D21 build after signer verification; preserve device-only Pending entries. The stable signing key is available only to the existing GitHub Actions build. The redesigned stable-signed APK has now been produced and audited; delivery details are below.

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
- Local `flutter build apk --debug --no-pub` with the existing staging endpoint and Google audience stops with **No Android SDK found**, `/tmp/ux01-local-apk.log`. Existing stable-key CI build invocation will be prepared against the independently reviewed immutable source. The user separately approved pushing the reviewed branch and running the existing stable-key workflow on4October2026. No new signer or backend deployment was needed.

Root regression fixes retain their RED→GREEN evidence: statement shop identity/snapshot metadata; owner workspace provisional/synced amounts with complete and partial freshness; translated payment validation/correction reason/conflict; Hindi original-entry provenance; multiline large-text validation. Focused fixture tests verify credit/payment arithmetic and retained attempts. Renderer refinements were regenerated and inspected as described above.

## Execution rulings

1. The user-requested dedicated UI/UX agent implements Tasks 1–9; root owns final review, version and APK preparation. This preserves the requested assignment and keeps remote actions outside local scope.
2. Payment review retains its existing control tree and rejection/uncertain-attempt branches, using shared identity/receipt/theme components instead of forcing the generic review wrapper. The tradeoff is less component reuse; financial action availability and original retry bodies remain unchanged.
3. Capture-helper style/key/import cleanup is presentation-neutral. Existing renderer evidence remains valid because production widgets and fixture state are unchanged; source hashes are refreshed and focused fixture tests rerun.

Fresh review results and the single fix pass are recorded below. Five native camera-runtime variants plus the phone acceptance matrix remain pending.

## Prepared signed build invocation

Final candidate source: `78f0f93f83aca516dc5ae7c1b17fa7f7ef89b494`. Branch: `codex/ux01-redesign`. The existing `.github/workflows/apk-download.yml` accepts this full immutable SHA and restores the existing stable key; it refuses to generate a replacement key.

After explicit remote authorization, push the reviewed branch and run:

```sh
gh workflow run apk-download.yml --repo magan110/UdharKhataApp \
  -f source_ref=78f0f93f83aca516dc5ae7c1b17fa7f7ef89b494 \
  -f api_base_url=https://udhaarkhata-api-staging.udhaarkhata-api.workers.dev \
  -f google_server_client_id=1098240805044-90hnifajs9hvtvcive1d65r3q2cqnu03.apps.googleusercontent.com \
  -f expected_signing_sha1=3C:CE:D2:62:9B:40:A7:5F:ED:A4:DB:DA:AB:21:E3:57:96:9F:16:C6
```

Before phone delivery, inspect the downloaded exact artifact's package `com.udhaarkhata.app`, version `0.3.0+3`, stable signer above, embedded endpoint/audience and SHA256 against `apk-audit.json`; record run/artifact IDs and file size/hash. Update over D21 without uninstalling or clearing app storage. No backend deployment is necessary. This exact command was dispatched after separate user approval; the successful artifact is recorded below.

## Independent final review and fix pass (4 October 2026)

Fresh-context reviewer `ux01_final_review` (`gpt-6-astra`) reviewed immutable `d75788a..d776a985030825e713541a91e74d4536767b0c60`, governing design/plan, production diff, selected captures and 14 focused tests (all pass). No Critical finding or additional confirmed accounting, retry, snapshot or selected-response regression was found. Reviewer identified:

- **Important:** Owner More/sign-out was inside the successful non-null shop branch, blocking account recovery during no-shop setup, loading or error. Fixed by rendering account-level More independently, with optional shop actions. Three actual-router tests failed before the fix, then verified Sign out opens the Pending warning and Cancel preserves the signed-in account and makes no write. RED log `/tmp/ux01-signout-red.log`; focused GREEN `/tmp/ux01-review-fixes-green.log`.
- **Originally Minor, root regraded Important:** A fresh direct-linked dispute without matching context/card could show the report form without its target entry. The approved spec requires an honest entry-ID fallback; root treats a missing submission target as a functional gap. Fixed with localized `Entry <ID>` independent of existing cards, without inventing an amount. New no-matching-card test failed first (`/tmp/ux01-dispute-id-red.log`), then passed in the same nine-test focused GREEN batch.

Single review fix pass completed. There are **no deferred minor findings**. Twenty affected owner-More/dispute renders pass (`/tmp/ux01-review-captures.log`); four changed English/Hindi images were inspected individually, and the other 16 remain identical. Final full regression after these fixes: **266 tests pass**, **87.73% line coverage (4,976/5,672)**, `/tmp/ux01-reviewed-suite.log`. Analysis is clean (`/tmp/ux01-reviewed-analyze.log`); formatting153 files zero changes; release-static298 text files, coverage threshold, documentation49 files/navigation and diff checks pass. No core/backend/repository/lockfile changes; generated desktop tooling noise restored. Reviewer could not establish physical camera/Google/share/TalkBack/Hindi-font/signing acceptance and did not produce an APK.

Additional execution ruling: root regraded the direct-link target-ID issue because reporting needs a visible target even before any dispute exists. The cost is an extra ID label on matching-card screens; this does not alter the ledger or dispute API. The branch remains isolated; at the review checkpoint it had not been pushed. Subsequent separately approved push/build and artifact delivery are recorded below; no main merge or backend deployment occurred.

Final immutable source checkpoint: `78f0f93f83aca516dc5ae7c1b17fa7f7ef89b494`. All68listed source hashes match that commit;all362image hashes match their files. Twenty rerendered rows pin this checkpoint;272unchanged redesign captures retain their actual initial capture source. Build this full SHA after authorization, preserving branch and worktree for phone feedback.

## Stable-signed phone-test delivery (4 October 2026)

The user explicitly replied **Approved** to pushing the reviewed UX01 branch and running the existing signed APK workflow. Branch `codex/ux01-redesign` was pushed without merging main or redeploying the Worker.

- Source built: `78f0f93f83aca516dc5ae7c1b17fa7f7ef89b494`; workflow checkout logs verify this exact commit.
- Cloud CI [37168026963](https://github.com/magan110/UdharKhataApp/actions/runs/37168026963): docs, Flutter and Worker jobs **success**, including full automated checks.
- Stable-key APK build [37168036144](https://github.com/magan110/UdharKhataApp/actions/runs/37168036144): **success**, including exact `apksigner verify`/certificate/configuration audit and key cleanup.
- Artifact **11290846371**, `Udhaar-Khata-debug-APK`: [download ZIP](https://github.com/magan110/UdharKhataApp/actions/runs/37168036144/artifacts/11290846371), retained14days. Contains `app-debug.apk` and `apk-audit.json`.
- Downloaded ZIP SHA256 `d3d9e3fb72354a3e5e2ef71ab4c0d305a2dd99789efbcfc94d198203f3eaa1ae` matches GitHub artifact digest. The authorized GitHub connector supplied the reusable download reference; no signed URL is retained in this document.
- APK package `com.udhaarkhata.app`, **version0.3.0+3**, existing registered signer SHA1 `3C:CE:D2:62:9B:40:A7:5F:ED:A4:DB:DA:AB:21:E3:57:96:9F:16:C6`. Local binary-manifest/certificate extraction independently agrees with CI; CI performed cryptographic signature verification, bound locally by the exact APK hash.
- APK size **202,749,839bytes** (~193.4MiB). SHA256 **`73afcb16511975d05f4605e59ec827ccca7a6b00d299e31e99a282098e77a428`**.
- Embedded staging endpoint `https://udhaarkhata-api-staging.udhaarkhata-api.workers.dev` and existing Google audience independently found in the exact downloaded APK; all fields match CI `apk-audit.json`.

Local delivery files: `/workspace/artifacts/ux01/app-debug.apk`, ZIP and both audit JSON files. APK binaries remain outside source control. Install as an update over D21; **do not uninstall or clear app storage**. First sign in online, then use the phone acceptance matrix above with synthetic accounts/entries. Physical update/data preservation, native Google/camera/share, TalkBack, Hindi-speaker usability and pilot/public-use/backup gates remain pending until tested; matching signer/build success does not claim those outcomes.

## Archived focused verification commands

These are chronological execution checkpoints, superseded by the final266-test/CI/APK results above. All execution rulings and review findings are preserved in this evidence document; the ignored per-plan scratch ledger can now be removed.

```text
Task 1 evidence: base 327bb22..3f8f65d; /tmp/ux01_flutter.sh test test/ui/money_display_test.dart test/ui/presentation_accessibility_test.dart test/app_smoke_test.dart test/sharing/localization_resources_test.dart -> 6 pass.
Verification: /tmp/ux01_flutter.sh test test/ui/owner_home_truth_test.dart test/ui/role_navigation_test.dart test/router_test.dart test/shop_session_test.dart test/sync_ui_test.dart test/ui/scanner_recovery_test.dart test/auth_ui_test.dart test/owner_link_ui_test.dart test/resolve_controller_test.dart test/shop_test.dart test/qr_ui_test.dart test/ui/financial_review_safety_test.dart test/credit_ui_test.dart test/payment_ui_test.dart test/device_ledger_ui_test.dart test/credit_repository_test.dart test/payment_repository_test.dart -> 67 pass.
Tasks 5–8 complete checkpoint: f55ff62..8d66dce. /tmp/ux01_flutter.sh test test/ui/dispute_context_test.dart test/dispute_due_test.dart test/dispute_cache_test.dart test/ui/ledger_source_truth_test.dart test/history_ui_test.dart test/device_ledger_ui_test.dart test/correction_ui_test.dart test/correction_test.dart test/due_summary_ui_test.dart test/ui/customer_truth_test.dart test/qr_ui_test.dart test/customer_shops_test.dart test/offline_auth_test.dart test/settings/settings_ui_test.dart test/ui/secondary_action_safety_test.dart test/sharing/statement_pages_test.dart test/sharing/share_controller_test.dart test/sharing/statement_test.dart test/auth_ui_test.dart -> 89 pass (/tmp/ux01-task5678-green.log).
Task 9 in progress: /tmp/ux01_flutter.sh test test/ui/financial_large_text_test.dart test/sharing/localization_resources_test.dart test/ledger_hindi_ui_test.dart -> 7 pass (/tmp/ux01-task9-large.log); actual CreditPage and PaymentPage Hindi320/200% keyboard inset300 review actions reachable. Renderer fixtures/capture evidence still pending.
```
