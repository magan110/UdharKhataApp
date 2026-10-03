# UX01 — Clear Counter complete-app redesign

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../../DOCUMENT-MAP.md). **Read with:** [UX01 UI/UX redesign](../../implementation/06-ui-ux-redesign.md) · [UI/UX agent brief](../../agents/ui-ux-redesign-agent.md) · [UI/UX spec](../../../UI-UX-DESIGN-SPEC.md) · [Implementation progress](../../implementation/PROGRESS.md).
<!-- DOC_NAV_END -->

Date: 3 October 2026. Status: written design approved by the user on 3 October 2026; implementation plan prepared for review. Author: dedicated `ui_ux_redesign` agent. This document is a design artifact; no redesigned product implementation is claimed.

## 1. Approval, intent and evidence

The user selected option 1, the first displayed owner-home concept: **Clear Counter**, green and white, with Udhaar Khata/Kiran Store header, confirmed amount card, amber Pending strip, prominent Scan customer QR action, compact customer rows, and Home/Customers/More navigation. The authoritative generated reference is preserved as [selected owner-home concept](../../design/ux01-owner-home-option1.png), 853 × 1844 pixels, SHA-256 `ed476f12644db17cdef3605f0faac1332a523f7827aaa9680f2eab8186054bdd`; the dedicated agent opened and inspected the original `/workspace/generated_images/exec-03b26c7e-ac9b-4cfe-921c-99c575527db9.png` before writing this specification. The reference is a proposed visual, not a screenshot of the running app. Its names, amounts, counts and artwork are illustrative fixtures. Options 2 and 3 are not selected.

The user selected the visual direction, then replied “approve” to the completed written-specification review on 3 October 2026. This full-app design is approved. The next gate is review of the concrete implementation plan before product code, preserving the user-requested dedicated UI/UX agent as implementer. Backend/API/schema changes are outside the approved design. UX01 follows delivered D21 and does not renumber or replace D22–D24.

The goal is an understandable ledger at a busy Indian shop counter: owners recognize the customer, deliberately review and save money, and understand the save outcome; customers show their QR immediately and explain each shop's debt from its entries. English, Hindi, compact Android phones, large text and intermittent connectivity are first-class inputs. [Personas](../../../USER-PERSONAS.md) and [journeys](../../../USER-JOURNEY-USER-FLOW.md) guide tasks but remain hypotheses, not completed user research.

Source discovery covers the 16 registered routes and additional embedded/modal surfaces. Current rendered baseline screenshots, measured usability, physical scanning, TalkBack and Hindi-speaker acceptance are not available in this discovery. The selected concept does not establish those results. Source risks and proposed solutions below must be checked against fresh renders during implementation.

## 2. Scope and preserved boundaries

Own presentation components, theme, hierarchy, navigation, localized copy, accessibility and feedback. Reuse existing Riverpod providers, repositories, controllers, validation, account/session generation guards and Flutter/native boundaries. Backend endpoints, SQL/schema, accounting, sync algorithms, operation identity and authorization remain unchanged. A presentation component receives existing typed snapshots/state and emits existing actions; it does not create a new financial source of truth.

Preserve integer paise and existing limits; one shop per owner; multiple shops per customer; role guards; account-isolated cache/outbox; revoked-access cache denial; immutable original entries/corrections; original operation/body across retries; durable local save; review before every financial save; no posting from a scan; online first linking; customer QR as lookup only; manually recorded Cash/UPI; acknowledged-only statements; explicit Android sharing; and recovery of acknowledged records only. Never describe Pending as backed up or UPI as verified. Keep original rejected entries visible and recoverable. Do not expose stale protected content as a fallback for authorization/access failure.

No charts, invented recent activity, cloud health claims, bank integration, unverified customers, new permissions, auto-messaging, additional shop ownership, destructive deletion capability or new repository contract is introduced. Preserve current date/amount/note/export bounds and due-summary eligibility. Existing policy/operator/public-use gates remain open.

## 3. Visual system

Translate the reference into responsive Flutter logical dimensions, adapting its phone composition to available width, text scale and system insets. White space and amount prominence are binding; illustrative gradients, logo artwork and dummy data are not implementation requirements. Use a simple existing Material outlined book/store/QR icon treatment, without introducing an unreviewed brand asset dependency.

### Color tokens

| Token | Value | Use |
|---|---|---|
| canvas / surface | `#FFFFFF` | Screen and cards |
| surfaceMuted | `#F8FAF9` | Secondary sections |
| brand / primary | `#14532D` | Filled action and selected navigation text |
| onPrimary | `#FFFFFF` | Primary action text/icons |
| brandTint | `#EAF4ED` | Confirmed amount panel and selected navigation indicator |
| textPrimary | `#111827` | Headings, numbers, labels |
| textSecondary | `#475569` | Supporting text and timestamps |
| outline | `#64748B` | Input outlines and meaningful boundaries |
| divider | `#E2E8E4` | Decorative list separators |
| credit | `#9A3412` | Credit effect with explicit type/sign |
| payment | `#166534` | Payment effect with explicit type/sign |
| pendingText / pendingSurface | `#92400E` / `#FFF4D6` | Device-only Pending strip/chip |
| attentionText / attentionSurface | `#B91C1C` / `#FEF2F2` | Needs attention and actionable errors |

Avoid gradients for text-bearing actions. Use solid primary fill. Disabled buttons retain a readable label and a separate progress/status explanation. Never communicate ledger type, debt direction or sync state using color alone. Verify actual rendered contrast combinations, including muted panels, navigation and disabled controls; white-background baseline calculations do not establish app-wide compliance. Target 4.5:1 normal text and 3:1 large text/meaningful graphics.

### Type, spacing and shape

Use Flutter/Android's system sans-serif stack with the Android Devanagari-capable fallback (normally Noto Sans Devanagari). Do not download a font or add a package in this design step. Require device verification of Hindi shaping, line height, ₹ and numerals. The PDF's existing embedded-font mechanism stays separate from UI typography.

| Token | Logical size / weight |
|---|---|
| page title | 24 / 700 |
| home brand title | 24 / 700 |
| primary balance | 32 / 700; may use 36 on wider screens |
| section title | 20 / 700 |
| row title / action | 16 / 600 |
| body / field | 16 / 400 |
| metadata / chip | 14 / 400–600 |

Use spacing 4/8/12/16/24/32, compact outer padding 16, wide padding 24, card/row padding 16, card radius 16, input/action radius 12. Main controls and icons have at least 48 × 48 logical-pixel hit regions; filled actions have a 56 minimum height that expands for multiline labels. Customer initials are decorative, 40–48 logical pixels, with a neutral brandTint background and no invented portrait.

At 320 logical-pixel width and 200% text, titles, balances, timestamps and actions wrap/reflow. Do not ellipsize money or shrink away system text scaling. Move trailing row balances below identity if needed. Bottom navigation labels wrap within available layout; replace fixed-height constraints with sufficient height. QR size responds to available width while surrounding text remains scrollable. Respect SafeArea, keyboard insets and landscape. Do not require swipe/long press to discover actions.

Motion is limited to ordinary short state transitions; loading does not delay access to authorized local data. Respect reduced-motion preferences. Screen readers announce screen title, identity, debt direction, amount/currency and status; decorative art is excluded. Financial save, validation and important status changes have live announcements without repeated chatter on every rebuild.

## 4. Navigation and grouping

### Owner

Top-level destinations: **Home, Customers, More**, retaining `/owner` as the owner landing route. Implement presentation shell/tab state with valid protected child locations as specified in the subsequent plan; existing public/deep-link route behavior must remain compatible. Root navigation never changes role or bypasses session redirect. Child task screens have Back and no competing bottom bar.

Home follows the selected reference: app/shop header and Settings shortcut; confirmed shop amount; Pending/attention strip when applicable; Scan customer QR; a Customers preview with View all. Preview shows the first three currently loaded confirmed customer rows in existing server order, without pretending these are recent, highest-value or the entire list. View all selects Customers. If only authorized saved links are available, preview is explicitly **Saved customers on this phone**, and balances are omitted unless an existing per-link snapshot supplies them.

Customers shows the existing confirmed paginated customer list and an explicitly separate **Saved on this phone** section. Keep separate source sections rather than merging different snapshots into one unlabeled balance list. Names can appear in both sections; label the source clearly. No new sorting, search endpoint or inferred completeness is required. Maintain Load more/Retry page semantics. Scan is a prominent action above the list. Empty confirmed list has a Scan prompt; unavailable confirmed data still allows authorized saved customers.

More contains everyday preferences/help, a **Sync and saved entries** section using existing sync/outbox state, Disputes for the current shop, and account/data controls. No invented notification count is shown. The Pending strip opens this same sync section, displaying original attention entries, counts/timestamps and existing Sync now/export-device-copy actions. This is a presentation destination, not a new outbox editing/deleting facility. Settings gear and `/settings` open the settings/data-controls page consistently. Sign-out is discoverable in More/settings rather than competing with the counter's header actions.

### Customer

Top-level destinations: **My QR, My shops, More**, retaining `/customer` as the landing route and My QR as its initial view. More provides language/help, account/data controls and sign-out; customer receives no owner-only sync/write controls. My shops lists existing per-shop acknowledged amounts, with no invented all-shops aggregate. Task/detail pages return to the originating tab. Preserve Android Back: task → prior page; top-level noninitial tab → initial tab; no Back action implicitly posts, links, rotates, removes access or shares.

## 5. Financial truth and freshness

### Shop home

The green card says **Customers owe you**, exact existing server summary total, **Confirmed balance**, and **Excludes entries waiting to sync**. Include **Server snapshot: [date/time]** and Refresh totals. Confirmed means acknowledged, not necessarily current now. Label dated offline snapshots **Offline · Last confirmed snapshot**. If no verified summary exists, show **Confirmed total unavailable** with retry, not ₹0. Do not sum loaded customer pages or local ledgers to fabricate a complete shop-wide provisional total. Retained-ledger scope/customer count remains available in supporting copy, since the endpoint includes retained ledgers.

Pending strip uses existing account/outbox counts, not rupee totals: **[n] Pending · Waiting to sync**, **Saved on this phone. Not backed up to the cloud.** When attention exists, show a red attention line/count with Review. Counts come from current sync state, not guessed from the preview. The strip and confirmed card describe distinct facts. Zero counts can collapse to a compact last-sync status; keep full recovery truth in More.

### Per-customer owner workspace

Use an identity header and a BalancePanel with **Customer owes you [provisional] · Including Pending entries on this phone**, then **Synced balance [amount]** and complete snapshot timestamp. If amounts match and no Pending/attention exists, acknowledged balance can be primary with its timestamp. Do not call the local figure confirmed. Preserve the existing repository's provisional calculation and handling of attention; do not compute an alternate total in widgets. Negative/conflicting provisional results retain the existing warning/blocking behavior rather than showing a reassuring zero.

Partial refresh displays its separate timestamp and says the complete snapshot remains dated; it never updates the complete freshness label. Authorization, revoked-access or account-generation changes remove content. Transient errors may show only the existing permitted dated cache. Local and confirmed history are explicit source views; navigation between them does not imply reconciliation succeeded.

### Customer and due summary

Customer shows acknowledged entries only: **You owe [shop] [amount]**, **Server snapshot [date/time]**, offline/stale wording where applicable. A global last sync is not a substitute for that ledger snapshot. No pending owner amount is added to the customer's record before acknowledgement.

Due/overdue values appear only when the existing DueSummary guard supplies them. Keep manual Refresh due summary, the current 60-second expiry, complete-ledger checks and owner Pending/attention restrictions. Unavailable/expired due totals show explanatory refresh guidance, not an inferred overdue number or misleading zero. Display acknowledged due timestamp and exact existing allocation outcome.

## 6. Shared presentation contracts

| Component | Existing input / output | Required behavior |
|---|---|---|
| AppHeader / task scaffold | Role, shop/account label, navigation actions | Clear hierarchy, Back on task views, SafeArea and localized title |
| IdentityPanel | Existing display label/nickname | Visible before every review/save; no invented PII/avatar |
| BalancePanel / FreshnessLine | Existing snapshot values/source/timestamps | Explicit debt direction, no fabricated aggregates |
| StatusChip / SyncStrip / SyncDetails | Existing status/counts/error codes | Text + icon + color; Pending device-only warning; attention review |
| CustomerRow / ShopRow | Existing link/shop record | Full name and source-specific amount; responsive stacking |
| LedgerRow / EntryDisclosure | Existing immutable row and loaded history | Type, signed effect, date, status; details preserve provenance |
| AmountForm / ReviewPanel / SaveReceipt | Existing validation/controller/attempt/receipt | Review, busy lock, original attempt retry, durable receipt |
| EmptyState / ErrorState / ProgressState | Existing load/failure/action | Localized next action valid in the actual state |
| ConfirmationSurface | Existing sensitive action callbacks | Specific consequence, cancel default, no mutation on dismissal |

Presentation extraction must leave asynchronous repository identity checks and generation guards intact. Shared errors map existing failure keys; do not hide distinct permission, conflict, quota or unknown-outcome states behind generic success. New UI-only localization keys use the current AppStrings mechanism; all visible labels, field errors and semantics are translated with placeholders. English/Hindi copy is consistent about confirmed, Pending, customer owes and payment received. Hindi terminology remains subject to native-speaker review; avoid concatenated English grammar inside Hindi sentences.

## 7. Complete surface specification

All existing routes are defined in [router.dart](../../../udhaarkhata/lib/app/router.dart). Rows below include embedded and modal surfaces so no legacy screen is omitted.

| Surface / source | Layout and actions | Required variants |
|---|---|---|
| `/` [Welcome](../../../udhaarkhata/lib/features/auth/welcome_page.dart) | Brand, concise shared-ledger explanation, owner/customer selection, Continue with Google; existing configuration errors | Selected role, busy, cancelled sign-in, network/auth/config/role failure; no unexpected account creation |
| `/loading`, `/error`, fallback [Status](../../../udhaarkhata/lib/app/status_page.dart) | Localized title/message, semantic progress or valid Retry/Back | Session restoring, failed opening, unavailable deep link, expired/locked session; no old-account content |
| `/owner` [Home/setup](../../../udhaarkhata/lib/features/shop/owner_shell.dart) | Selected composition; embedded one-shop setup uses name/help/Create shop | No shop, required/maximum name, creating/error; totals/list loading/empty/error; offline saved access |
| Owner Customers, [customer list](../../../udhaarkhata/lib/features/shop/customer_list.dart), [saved links](../../../udhaarkhata/lib/features/ledger/local_ledger_view.dart) | Confirmed and saved sections, scan, View all/pagination; source labels | No customers, partial list, retry page, cached rows, no permitted cached access |
| `/owner/scan/:shopId` [Scanner](../../../udhaarkhata/lib/features/qr/scanner_page.dart) | Framed camera with short instruction; known offline/new online explanation and customer-list fallback | Initialization/prior-request check, resolving, camera denial/unavailable/retry/settings return, invalid/version/revoked QR, unknown offline, account change |
| Embedded [Link confirmation](../../../udhaarkhata/lib/features/qr/link_confirm_page.dart) | Identity, optional existing nickname field, Add customer and continue, cancel; copied QR warning | New confirmation, saving, failure, uncertain previous attempt/check same request; no rescan that abandons a retained attempt |
| `/owner/customer/:shopId/:linkId` [Workspace](../../../udhaarkhata/lib/features/shop/customer_list.dart) | Identity/balance panel, Record credit/Payment received, history, due summary, statement and disputes links | Authorized local/confirmed source, loading/refresh/error, unavailable access, Pending/attention, conflicting balance |
| `/owner/credit/:shopId/:linkId` [Credit](../../../udhaarkhata/lib/features/ledger/credit_form.dart) | Identity, numeric amount, optional note/due picker, Review, review identity/amount/details, Submit credit, Edit | Validation/loading, review, busy, durable Pending receipt, acknowledged receipt, uncertain original-attempt recovery/error |
| `/owner/payment/:shopId/:linkId` [Payment](../../../udhaarkhata/lib/features/ledger/payment_form.dart) | Identity/current source balance, amount, Cash/UPI, manual recording notice, optional note, projection/review, Submit payment | Excess/invalid input, changed balance/rejection, original-attempt recovery, busy, Pending and acknowledged receipts |
| `/owner/history/:shopId/:linkId` and `?source=server`; [history](../../../udhaarkhata/lib/features/ledger/history_page.dart), [local ledger](../../../udhaarkhata/lib/features/ledger/local_ledger_view.dart) | Source header and balance/freshness; compact entry rows with detail disclosure; explicit source switch | Empty, loading, page failure/retry, incomplete verification, offline/partial cache, Pending/attention/blocked-by-earlier rows |
| Embedded [Entry detail](../../../udhaarkhata/lib/features/ledger/entry_detail.dart) | Expand/tap clearly labeled Details; original/effective acknowledged amount, dates/note/method/due, correction provenance; Correct entry when eligible | No corrections, multiple acknowledged corrections, pending correction, retained attention; eligibility unchanged |
| Pushed [Correction](../../../udhaarkhata/lib/features/ledger/correction_form.dart) | Original/effective amount, replacement amount including allowed zero, reason, review and deliberate save | Loading/validation, cancelled amount, offline/stale revision/conflict, busy, Pending/acknowledged/retry; original remains visible |
| `/owner/disputes/:shopId`, `/customer/disputes/:shopId?entry=…`; [Disputes](../../../udhaarkhata/lib/features/disputes/dispute_page.dart) | Open/Resolved grouping of current loaded items, entry context, reason/date/response; owner response attached to selected item | Empty, busy/error, cached read-only, duplicate/existing report, unresolved/resolved; no balance mutation |
| `/owner/statement/:shopId/:linkId` [Sharing](../../../udhaarkhata/lib/features/sharing/statement_share_page.dart) | Date range, Load statement, audited preview, opening/closing and timestamp, Pending excluded, editable reminder, Share reminder/PDF/CSV | Bounds/error/loading, empty date range with valid balances, reconciliation failure, generation/share/cancel/account switch interruption |
| `/customer` My QR [Customer shell](../../../udhaarkhata/lib/features/ledger/customer_shell.dart), [QR](../../../udhaarkhata/lib/features/qr/customer_qr_page.dart) | Account label, high-contrast code, Show to owner guidance, lookup-only explanation; Refresh/Replace QR secondary | First load/error, verified/cached-unverified, offline, uncertain rotation hides old code, rotate confirm/busy/error/recovery, sign in again |
| `/customer` My shops [Shops](../../../udhaarkhata/lib/features/ledger/customer_shops.dart) | Per-shop source-labeled owed amount, freshness, open ledger, refresh/pagination | No shops → show QR action, loading/error, dated offline cache, forbidden/revoked data removed |
| `/customer/history/:shopId` [History](../../../udhaarkhata/lib/features/ledger/history_page.dart) | Shop/owed balance/freshness, compact acknowledged rows, detail disclosure and Raise/view dispute, due summary; access removal in secondary section | Empty/load/page retry/stale/cache, correction provenance, own-entry restriction, access removal confirmation/outcome |
| Owner/customer More and `/settings` [Settings](../../../udhaarkhata/lib/features/settings/settings_page.dart) | Language/account/help; separated data requests/status and high-impact controls; owner sync/device-copy section | Request confirm/busy/error/status/latest-100 notice, privacy-policy limitations, device-only-copy sensitive-data confirmation, native share/cancel |
| `/recovery` [Help](../../../udhaarkhata/lib/features/settings/recovery_help.dart) | Short sections: QR meaning, offline/Pending, changed/lost phone, uncertain posting; existing guidance | Acknowledged-only recovery explanation, original-phone sync checklist; no promise of Pending restoration |
| Shared [Sync status](../../../udhaarkhata/lib/features/ledger/sync_status_view.dart) | Compact strip plus full More section with original attention records, last verified/sync/oldest Pending, Sync now | Running, network/rate/capacity/service/auth/access/conflict/legacy/cache-too-large failures; blocked entries and retained original payload |
| Shared [Sign-out](../../../udhaarkhata/lib/features/auth/sign_out_button.dart) | Account-specific confirmation; Pending warning when existing safeguard requires; cancel/sign out | Busy/failure, pending-preservation rule, account switch lock; no uninstall/clear-storage recommendation |

### Financial flow decisions

Keep scanner → customer workspace → Record credit/payment. Although the older journey proposes direct credit after linked scan, this design explicitly chooses the current shipped workspace behavior: the owner can select credit or payment and inspect the identified customer, without adding a new intent/routing controller. The workspace puts Record credit first and avoids redundant identity-confirmation dialogs. Timing is measured before considering a separately reviewed direct-to-credit optimization.

Keep editing → review → saving → durable result. Review includes customer, amount, note/due/method and source-qualified balance/projection where existing data supports it. Local saving may immediately produce Pending; it must not wait for a cloud spinner to show local success. Pending receipt says Saved on this phone/Not backed up and links Back to customer. Acknowledged receipt identifies the balance **when recorded**, not a guaranteed current balance, and offers return/refresh. Do not add a new-record button that clones an unresolved attempt. Retry invokes the existing retained operation. Once an attempt exists, existing restrictions on editing original payload remain.

Keyboard-safe review/action areas scroll into view; do not overlay content with a fixed Submit. Back/Edit before an attempt returns without posting. After an attempt exists, preserve the existing durable attempt semantics and make any uncertain outcome explicit; do not treat dismissal as cancellation of money already saved. Rapid repeated taps cannot create multiple operations.

### History and detail decisions

Retain existing authoritative entry order, pagination and integrity verification. Do not reverse a page or group by displayed date in a way that loses server sequence. Use labeled Details disclosure within the current history screen rather than require a new entry-fetch endpoint. Compact rows show type, signed balance effect, date and status; original amount and detailed provenance are available in disclosure. If a signed effect is not part of a row's existing typed data, use the existing kind/effect fields rather than infer an alternate accounting result. Corrections keep original/target IDs and reasons; raw IDs are secondary selectable metadata.

Customer detail reveals only already authorized loaded row information. Original-entry links may scroll to a loaded matching row; if it is not loaded, show its ID and existing Load more path without claiming a complete correction chain. Owner effective acknowledged amount and correction eligibility continue to use existing EntryDetail logic. An expandable row remains accessible with a labeled button/state and contains no hidden-only gesture action.

### Dispute decisions and available context

The existing dispute payload supplies ID, shopId, entryId, customerUserId, reason, status, createdAtMs, resolutionNote and resolvedAtMs; it does not supply customer name, entry amount/type or date. Entry-origin navigation may pass a UI-only summary of the already loaded authorized entry. Associate it by account/shop/entry and discard it on session changes. Never persist that summary as a new authority or use it to enable posting. On direct reload/list navigation where entry context is unavailable, render **Entry [ID]** with reason/status/date; do not fabricate identity/amount or fetch unrelated ledgers to fill the card.

Group only currently returned items into Open/Resolved, preserving their source order; counts are labeled for displayed items if shown. The repository does not expose dispute cursors, so do not add a functional-looking Load more/pagination control. Retain refresh and empty states. Owner taps Resolve on one selected card to open an attached expanded response form/dialog with its reason/context and resolution note, rather than using a shared note below all cards. Existing resolve endpoint/validation is unchanged. Customer reason limit stays at the current form limit, not a silently expanded parser maximum. Reporting/resolving never changes debt; correction is a separate owner action.

### QR, permissions and sessions

Preserve scanner camera lifecycle serialization, permission-at-use, retry/settings actions and uncertain link recovery. Scan cannot post or implicitly confirm a new link. First linking needs online verification; known locally authorized link can open offline. Copied QR does not prove the person. Unsupported/revoked codes keep distinct actionable messages. Customer QR cache remains explicitly unverified when current server validity cannot be established; uncertain rotation hides the old code until online recovery. Rotation confirmation explains old-code invalidation without suggesting ledger deletion.

Never show code/ledger from another account while navigating/rebuilding. Session refresh/loading routes supersede task UI; callbacks/results from old repositories are ignored. Auth failure offers existing reauthentication; revoked access denies cached ledger rendering. Public cached QR exception follows existing code exactly and grants no ledger/cloud authority. More/settings navigation cannot bypass these rules.

### Sharing, privacy and help

Statements/reminders use existing audited acknowledged snapshots, with bounded date ranges, opening/closing reconciliation and snapshot timestamp. Show Pending excluded before sharing; do not merge local-only requests into PDF/CSV. Editable reminder is a preview, not an automatic send. Share labels open native share only on a user tap; cancel is not reported as delivery. Preserve temp-file cleanup, generated font/Unicode behavior and account-change interruption safeguards.

Device-only request copy is a separate recovery export, with original Pending/attention requests and sensitive-data warning, explicitly not proof of server balance. Its confirmation says choose a trusted recipient and keep app data until resolved. Data requests distinguish requesting export/deletion from completed deletion. Preserve current non-destructive test-policy wording, retained immutable history and latest-100 status limit. Customer Remove shop access explains loss of viewing access and retained owner history/current relink limitation; cancellation changes nothing. Help reinforces sync-before-device-change, no recreation of uncertain entries without checking, and no uninstall/clear-data as recovery advice.

## 8. State and modal completeness

Every applicable surface has loading, empty, ready and recoverable/nonrecoverable error variants. Loading maintains authorized available content where existing repository rules permit; it does not resurrect denied cache. Inline errors preserve editable fields and focus/announce the first error. Empty state provides the task's next action; unavailable/unknown amount is never rendered as zero. Rate limit/capacity errors retain original entries and display existing retry guidance, not invented countdowns. Unknown outcomes say checking/retry same request rather than failed/not saved.

Modal/embedded coverage includes role selection; shop-name validation; credit due-date picker; financial review/edit/results; payment method and rejected-attempt recovery; entry disclosures and correction form; scanner permission/settings and link recovery; QR replacement confirmation; dispute reason/selected resolution; statement date pickers/reminder preview/native share; language selector; data-request confirmation/status; device-copy sensitive share confirmation; customer access-removal confirmation; sign-out Pending warning; session failure/reauthentication. Dialog content scrolls at large text, has explicit Cancel, and returns focus to its invoking control. System date picker and native share remain native surfaces with localized app-owned surrounding copy.

## 9. Implementation handoff and acceptance

After written-design review, prepare a plan aligned with UX01-C through UX01-G: shared tokens/components/localization/navigation; owner counter and ledger; customer QR/shops/history/disputes; sharing/settings/help; full integration/regression/render/phone handoff. Assign exact presentation file ownership and preserve repositories/controllers. Root owns registry/progress/evidence integration. Do not begin product code from image selection alone.

Required automated checks are formatting, Flutter analyze, full Flutter tests and at least 80% coverage per UX01. Add meaningful interaction tests for navigation/Back, review/save/retry, account-change interruption, original Pending preservation, source/freshness labels, offline/permission recovery, selected dispute context, share cancellation and critical large-text/Hindi semantics. Preserve existing money/auth/sync/correction/statement tests; screenshot snapshots alone do not prove these outcomes. No API/schema change is planned; a separately reviewed contract dependency would require API regression too.

Maintain a coverage evidence table for every row in section 7 and every material state/modal in section 8: source, synthetic fixture, accepted current baseline capture or named blocker, redesigned capture, interaction test, physical status. Capture/inspect actual rendered app screens, not generated mockups presented as implemented screens. Review English/Hindi at 320 logical pixels/200% text, keyboard open and landscape; full numbers, debt direction, warnings and actions remain readable/reachable. Verify target size, measured contrast, focus order, labeled QR, validation and receipt announcements. No accessibility-compliant claim is allowed from screenshots alone.

Physical acceptance uses a defined low-end API24+ Android and current Android with synthetic owner/customer accounts: Google sign-in/update, permission denial/settings return, new/repeat/offline known/unknown QR, scan-to-local-save timings, credit/due/partial/full manual Cash/UPI, restart/reconnect exactly once, correction/cancellation/stale revision, dispute/resolution without balance change, reminder/PDF/CSV native share/cancel, language/Hindi-speaker debt/Pending comprehension, TalkBack/200% text, account switch isolation, access-removal/request status and replacement-device acknowledged-only restoration. Record model/API/build/hash/language and failed checks. The PRD median under 15 seconds is a measurement target, not an achieved result.

Inspect final APK package/version/stable signer/hash and update without clearing app storage. A redesigned build or successful widget suite does not close unperformed D21 phone acceptance, privacy/retention/relink, backup/custody/operator or real-user pilot/public-launch gates. UX01 completion means all shipped UI surfaces are redesigned and verified to the recorded evidence level, with every remaining external/physical gate explicitly visible.
