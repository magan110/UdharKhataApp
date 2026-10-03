# UX01 redesign verification evidence

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../DOCUMENT-MAP.md). **Read with:** [UX01 selected design](../superpowers/specs/2026-10-03-ux01-redesign-design.md) · [UX01 implementation plan](../superpowers/plans/2026-10-03-ux01-redesign.md) · [Implementation progress](../implementation/PROGRESS.md).
<!-- DOC_NAV_END -->

Date: 3 October 2026. Worktree `/workspace/ux01-redesign`, branch `codex/ux01-redesign`, original baseline `d75788a`. Status: implementation and synthetic verification in progress. This document does not claim physical Android acceptance, native-surface screenshots, real-user usability, Hindi-speaker review or public-use readiness.

## Verification boundaries

Selected generated owner-home image is design direction only. Synthetic Flutter widget captures use actual production screen widgets with test-only providers/native substitutes; they are not phone screenshots. Baseline captures refer to immutable source `d75788a` from `/workspace/ux01-baseline`. Native Google sign-in, real camera/QR lighting, native Android permissions/settings/share, installed Hindi fonts, TalkBack, signer update, traffic and replacement-phone checks require phone/CI evidence.

All fixtures use synthetic IDs/amounts/dates and memory providers. No fixture contacts an API or opens customer SQLite storage. Existing regression tests may use isolated synthetic databases as before; capture fixtures do not use database I/O.

## Checkpoints

- Foundation `3f8f65d`: formatter missing-import RED; integer-paise Indian grouping, large Hindi shared review and contrast plus smoke/resources: 6 pass. Exact commands/logs in persistent execution ledger.
- Counter/navigation `f55ff62`: grouped review, navigation and session-error overflow RED→GREEN; 67 affected tests pass. Home total is server-only, Pending separate, preview server order and More/sign-out scope tested.
- Subsequent history/customer/disputes/settings verification is being recorded after focused and full suites complete.

## Source and financial safety

No backend/API/schema/repository/accounting changes are planned. UI-only integer formatter preserves original parser and export formatter. Existing operation/retry/durable Pending/account generation/cache-revocation guards remain in source and are covered by existing regression plus focused UI tests. Full completion requires recorded final analyze/tests/coverage and fresh review.

## Capture coverage

Capture manifest and images will be linked here after generation and inspection. Every shipped route, embedded/modal surface and material state maps to the plan's scenario matrix. Missing native/physical evidence remains explicitly pending, rather than inferred from a widget substitute.

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
