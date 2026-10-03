# UX01 — Complete app UI/UX redesign

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../DOCUMENT-MAP.md). **Read with:** [UI/UX agent brief](../agents/ui-ux-redesign-agent.md) · [UI/UX spec](../../UI-UX-DESIGN-SPEC.md) · [Wireframes](../../WIREFRAMES.md) · [Implementation progress](PROGRESS.md).
<!-- DOC_NAV_END -->

Date: 3 October 2026. Status: phase created; initial source discovery complete; user selected option 1; complete full-app specification written and awaiting review; product implementation has not begun.

## Mandate and ownership

The user requested a separate agent and separate phase focused entirely on redesigning the app's UI/UX. UX01 covers the entire shipped Flutter Android experience, including owner and customer journeys, embedded views, dialogs and failure states. It follows the delivered D21 private-test candidate and is a separate workstream; existing D22–D24 identifiers retain their original meanings.

Dedicated agent: `ui_ux_redesign`. Its persistent instructions are in [UI/UX agent brief](../agents/ui-ux-redesign-agent.md). The primary agent coordinates integration and verification. The dedicated agent owns discovery, visual direction, screen specifications, shared UI components and presentation changes after design review.

## Intended outcome

Make the ledger faster to navigate and easier to understand at a busy shop counter, with a cohesive visual identity across every screen. Owners must recognize the customer, review an amount and understand the save outcome. Customers must quickly show their QR, see what they owe each shop and find an entry or dispute. English and Hindi, compact Android phones and large text are first-class design inputs.

The user specified complete UI/UX coverage, not a color-only refresh. Selected visual direction: option 1, a clean modern ledger with clear hierarchy, generous touch targets and restrained decoration. The user selected the first displayed generated concept on 3 October 2026. Full-screen interactions and state specifications will be written for review before product implementation.

## Complete coverage inventory

| Area | Screens and interactions to redesign |
|---|---|
| Identity and onboarding | Welcome, owner/customer choice, Google sign-in, configuration/role errors, account loading and reauthentication, shop creation and first-use guidance. |
| Owner home | Shop identity, owed totals, Scan action, saved/customer lists, no-customer state, disputes access, sync status and Settings. |
| Customer identification | Scanner frame/instructions, camera permission/denial/settings, invalid or revoked code, unknown offline QR, known cached lookup, identity confirmation, new link confirmation and cancellation. |
| Owner customer workspace | Customer summary, acknowledged/provisional balance distinction, due/overdue information, credit/payment actions, local/server history, statement/reminder and dispute access. |
| Financial forms | Credit, manual Cash/UPI payment, due-date selection, optional notes, correction reason/revision/zero amount, amount validation, review, duplicate-tap protection, saving and result states. |
| Ledger and details | Local and server histories, pagination, dates/types/signed effects, original and corrected values, correction detail/reason, Pending and Needs attention recovery. |
| Customer home | My QR, My shops, no shops, refresh, last checked time and stale cached history. |
| Customer QR | Current code, account label, identity-only explanation, cached state, rotation confirmation/result/error and revoked-code behavior. |
| Customer ledger | Per-shop balance and dated entries, freshness, due summary, entry detail, report problem and access removal. |
| Disputes | Report form, entry context, Open/Resolved lists, pagination, owner response/resolve dialog, cached read-only state and denial. |
| Sharing | Date range, reconciled statement preview, opening/closing balance, PDF/CSV choices, editable reminder, privacy review, native share, cancellation/error and account-switch interruption. |
| Settings and help | Language choice, account/role identity, recovery guidance, tracked privacy requests, status history, access removal/deletion request confirmations, device-only Pending copy and safe sign-out. |
| Global states | Loading, empty, offline, stale, syncing, Pending, Needs attention, quota/rate limit, service unavailable, validation, permission denial, expired session, wrong-role/deep-link errors and inaccessible removed data. |

Coverage must include nested/modal surfaces, not just router destinations. Record each surface's source file, current rendered capture, proposed design, implementation state and verification evidence in the design packet.

## Redesign boundaries

Presentation, navigation, hierarchy, copy, accessibility and feedback may change. Preserve exact money/accounting behavior, immutable history, original operation IDs, durable outbox, account isolation, QR lookup semantics and authorization. Scan alone never posts; review remains before every financial save. Pending is device-only and never described as backed up. UPI remains a manually recorded method, not bank-verified payment. Corrections retain their original record. Removed access never exposes cached records. Sharing always requires an explicit user action.

Backend, migrations, API contracts, release scope and financial calculations are outside the agent's ownership. If a desired design requires changing these, document the dependency for the primary agent rather than changing them as part of UX01. Do not introduce invented analytics, fabricated activity, permissions or financial capabilities to fill a design.

## Design exploration

The user selected the first of three displayed owner-home concepts. The selection maps to the original first displayed image, preserved as [selected owner-home concept](../design/ux01-owner-home-option1.png). The other directions remain exploration history:

1. **Clean modern ledger (selected):** calm neutral surfaces, deep green primary actions, prominent debt-direction amounts, consistent cards/rows and a clear role-specific navigation system. Suitable for speed, compact devices and Hindi text.
2. **Traditional khata:** warm paper tones and familiar ledger organization. Familiarity may help, but texture/ruling must not reduce contrast or compete with amounts.
3. **Bold premium:** stronger color blocks, larger visual accents and more expressive typography. Distinctive, but must prove compact-screen readability and must not suggest an actual payment wallet.

Mockups are proposals, not screenshots of implemented screens. Actual baseline audit findings require freshly rendered and inspected captures; source inspection alone is labeled a source-backed assessment.

## Work sequence and deliverables

- **UX01-A — Discovery:** complete route/embedded/modal/state inventory; render representative current screens with synthetic data; identify friction and evidence limits.
- **UX01-B — Visual direction:** compare complete design approaches on owner home, customer QR and financial review; select a coherent direction; produce a written screen/state specification for review.
- **UX01-C — UI foundation:** after design review, introduce tokens for color, type, spacing, surfaces, borders, icons and motion; define shared amount, identity, status, ledger-row, form, empty/error and navigation components.
- **UX01-D — Owner journeys:** redesign onboarding, owner home, scanner/linking, customer workspace, financial forms, review/results, history/corrections and sync recovery.
- **UX01-E — Customer journeys:** redesign QR/rotation, My shops, history/detail, disputes and access removal.
- **UX01-F — Secondary journeys:** redesign statement/reminder sharing, settings, privacy status, recovery/help and sign-out confirmations.
- **UX01-G — Verification and delivery:** inspect before/after captures, run meaningful interaction/regression/accessibility checks, independent review, then prepare a stable-signer phone-test APK for delivery.

The app-wide theme/navigation change is architectural: establish the design brief, review the written design specification, then write and review the implementation plan before product implementation. Phase creation and source discovery are already authorized by the user's request. A phase document is not evidence that any redesigned product screen exists.

## Acceptance gates

- Every inventory surface and meaningful state is covered; none quietly keeps an incompatible legacy style.
- A user can identify the customer and amount before a save, then distinguish device-only Pending from acknowledged data.
- Debt direction, freshness, correction provenance and manual payment meaning remain explicit in both languages.
- At 320 logical-pixel width and 200% text scaling, critical text and controls remain readable/reachable; keyboard and Android Back behavior are checked.
- Main touch targets are at least 48 logical pixels. Text contrast meets WCAG AA targets (4.5:1 normal text, 3:1 large text); status never relies on color alone. Verify focus, semantics and TalkBack on device before claiming accessibility acceptance.
- Existing route guards, account/cache revocation, offline persistence, retry idempotency, statement reconciliation and financial interactions still pass regression. Test outcomes, not only screenshots or widget structure.
- Format/analyze and full Flutter checks pass; coverage remains at least 80%. Run API checks if shared contracts change through a separately reviewed dependency.
- Review synthetic rendered screenshots for each redesigned journey and inspect the actual final APK signer/package/version. Stable identity permits an update without clearing Pending data.
- Record remaining physical-device or Hindi-speaker checks honestly. This phase does not resolve production backup, policy or real-shop pilot gates by visual redesign.

## Progress

- [x] Create separate UX01 phase and dedicated agent assignment.
- [x] Finish initial source inventory and label source-backed findings.
- [ ] Capture and inspect current-screen visual evidence.
- [x] Select visual direction: user chose displayed option 1.
- [ ] Review complete written app design specification.
- [ ] Review implementation plan and execute redesigned UI.
- [ ] Complete screen/state coverage and regression/visual verification.
- [ ] Deliver redesigned APK and record phone acceptance.

## Initial dedicated-agent discovery (3 October 2026)

The dedicated agent completed read-only inspection of all 16 registered routes plus embedded customer lists, shop setup, link confirmation, ledger details, correction navigation, sync status and sign-out dialogs. No current rendered screenshots were captured. These findings are source-backed risks, not a visual audit or measured usability results.

### Source coverage

| Surface group | Current source |
|---|---|
| Role guards, session opening/error, owner/customer destinations and settings/help routes | [Router](../../udhaarkhata/lib/app/router.dart), [status page](../../udhaarkhata/lib/app/status_page.dart), [welcome](../../udhaarkhata/lib/features/auth/welcome_page.dart) |
| Theme and localization | [App](../../udhaarkhata/lib/app/app.dart), [localization](../../udhaarkhata/lib/app/localization.dart), [strings](../../udhaarkhata/lib/app/app_strings.dart) |
| Owner home/setup and customer workspace | [Owner shell](../../udhaarkhata/lib/features/shop/owner_shell.dart), [customer list/workspace](../../udhaarkhata/lib/features/shop/customer_list.dart) |
| Scan and linking | [Scanner](../../udhaarkhata/lib/features/qr/scanner_page.dart), [link confirmation](../../udhaarkhata/lib/features/qr/link_confirm_page.dart) |
| Credit, payment and correction | [Credit form](../../udhaarkhata/lib/features/ledger/credit_form.dart), [payment form](../../udhaarkhata/lib/features/ledger/payment_form.dart), [correction form](../../udhaarkhata/lib/features/ledger/correction_form.dart) |
| Local/server history and detail | [Local ledger](../../udhaarkhata/lib/features/ledger/local_ledger_view.dart), [history](../../udhaarkhata/lib/features/ledger/history_page.dart), [entry detail](../../udhaarkhata/lib/features/ledger/entry_detail.dart) |
| Customer QR/shops | [Customer shell](../../udhaarkhata/lib/features/ledger/customer_shell.dart), [QR](../../udhaarkhata/lib/features/qr/customer_qr_page.dart), [shops](../../udhaarkhata/lib/features/ledger/customer_shops.dart) |
| Disputes and sharing | [Disputes](../../udhaarkhata/lib/features/disputes/dispute_page.dart), [statement/reminder](../../udhaarkhata/lib/features/sharing/statement_share_page.dart) |
| Settings/help/sync/sign-out | [Settings](../../udhaarkhata/lib/features/settings/settings_page.dart), [recovery](../../udhaarkhata/lib/features/settings/recovery_help.dart), [sync status](../../udhaarkhata/lib/features/ledger/sync_status_view.dart), [sign-out](../../udhaarkhata/lib/features/auth/sign_out_button.dart) |

### Source-backed priorities

- The current visual foundation is a Material 3 green seed theme, without a shared application token/component system. Unify hierarchy, amount presentation, surfaces, status, fields and navigation.
- Owner home places extensive sync content before totals and Scan, and includes both server customers and saved customer lists. Design one clear customer workspace and a consistently reachable Scan action; retain the data-source distinction.
- Repeat scan currently opens the customer ledger before a separate credit action. Evaluate a faster linked-customer route without removing customer/amount review or deliberate save.
- Expanded history cards repeat metadata and controls. Explore compact rows with explicit detail disclosure; retain correction provenance, dates, signed effects and all recovery actions.
- Synced/provisional distinctions rely on long repeated prose. Use one shared balance/status component with essential truth always visible and details expandable.
- Some shop setup, saved ledger titles and semantics remain English literals. Include a full copy/semantics inventory, not only translation of top-level pages.
- Dispute cards emphasize opaque entry IDs and owner response shares a field below the cards. Bring recognizable entry context and response controls together without changing dispute authorization or API.
- Group Settings by everyday preferences, help and sensitive account/data actions; separate high-impact confirmations visually.

Owner detail is currently embedded and correction is pushed separately; customer history uses expanded cards and per-entry dispute actions rather than a standalone detail route. Redesign must account for these actual surfaces rather than invent missing functionality.

Recommended navigation proposal: owner Home, Customers and More, with consistently reachable Scan; customer My QR and My shops with clear Settings access. Selected visual direction is a clean modern ledger with restrained warm neutrals and deep green primary actions. The user chose displayed option 1; alternatives are a traditional khata treatment and a more expressive task-first direction. Selection accepts the visual direction; the complete written app design remains the next review artifact.

## Selected full-app design handoff

The dedicated agent completed the [complete UX01 design specification](../superpowers/specs/2026-10-03-ux01-redesign-design.md) from option 1. Review of this written design is the next gate before implementation planning; the selected color/layout direction does not need reconfirmation.
