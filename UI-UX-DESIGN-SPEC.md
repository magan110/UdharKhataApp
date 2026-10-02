# Udhaar Khata — UI/UX Design Specification

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [Wireframes](WIREFRAMES.md) · [PRD](PRD.md) · [SRS](SRS.md) · [User manual](USER-MANUAL-HELP.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Platform:** Flutter Android, portrait-first  
**Status:** Design baseline for prototype and first public release; validate with real shopkeepers and customers  
**Related:** [Wireframes](WIREFRAMES.md) · [User Flows](USER-JOURNEY-USER-FLOW.md) · [Personas](USER-PERSONAS.md) · [PRD](PRD.md) · [SRS](SRS.md)

## 1. Experience goal and constraints

The owner should identify a returning customer and record credit with a scan, amount entry and deliberate Submit. The customer should show a QR quickly and later understand each shop's balance from dated entries. Both must understand whether information is current, still only on the owner's phone, or needs attention.

The first release supports one shop per owner, a customer linked to many shops, Google sign-in, INR, English/Hindi, and offline owner entry for previously linked customers. A QR is an identifier, not consent to an amount or a payment code. First-time QR linking requires internet. The app is free for users; the interface must not imply that cloud capacity or recovery is unlimited.

**Design priorities, in order:** prevent wrong-person/wrong-amount entries; make sync truth unmistakable; keep the repeat counter path short; show an explainable balance; keep first-time onboarding understandable.

## 2. Navigation and information architecture

| Role | Primary navigation | Secondary paths |
|---|---|---|
| Owner | Home, Scan QR, Customers | Customer ledger → credit/payment/correction, disputes, reminder, statement/export; Settings/Help |
| Customer | My QR, My shops | Shop ledger → entry detail → report problem; Settings/Help |

Use role-specific navigation after verified sign-in. A customer never sees an owner control. A shop owner never sees another shop's data. The Android Back action returns to the prior screen without posting or linking anything implicitly. Losing camera permission or network does not trap the user; every error state includes an action that is possible in that state.

The primary owner flow maps to [W05–W09](WIREFRAMES.md), and the customer flow to [W03, W10–W12](WIREFRAMES.md). Screen IDs refer to the wireframe document; they are stable design references rather than route names.

## 3. Layout system

| Token / rule | Draft specification |
|---|---|
| Screen margins | 16 logical pixels on compact phones; increase to 24 on wider layouts after responsive review. |
| Spacing scale | 4, 8, 12, 16, 24 and 32 logical pixels; use tokens rather than arbitrary gaps. |
| Touch targets | Aim for at least 48 × 48 logical pixels for main actions, icons and list rows; maintain separation between adjacent destructive/financial actions. |
| Primary action | One prominent action per screen; on credit/payment forms keep Submit visible above system insets and keyboard when possible. |
| Content order | Screen title → identity/balance → task fields or history → primary action → secondary/help. |
| Scroll behavior | Long customer lists and ledgers scroll; headings and action context remain clear; no information hidden only below a fixed button. |
| Safe areas | Respect status/navigation bars, display cutouts, keyboard and Android text scaling. |
| Responsive behavior | Portrait is the initial reference; allow landscape/reflow and large text without clipped amount, label or action. |

These sizes are design targets for the Android app, not claims that the ASCII wireframes have pixel accuracy. The final component sizes must be tested on the supported Android devices selected in phase 0.

## 4. Visual tokens and semantic meaning

Use a restrained visual style with clear amount hierarchy. The proposed palette is a **starting token set**, not a final brand identity. Text contrast calculations below are against white only; every actual text/background combination, disabled state and dark theme (if added) must be measured again.

| Token | Draft value | Use |
|---|---|---|
| `surface` | `#FFFFFF` | Cards and main screen background |
| `surfaceMuted` | `#F8FAFC` | Secondary panels; not a text color |
| `textPrimary` | `#111827` | Amounts, titles and body text |
| `textSecondary` | `#475569` | Supporting text and timestamps |
| `brandPrimary` | `#14532D` | Main action fill, focused emphasis |
| `brandOnPrimary` | `#FFFFFF` | Text on main action |
| `creditText` | `#9A3412` | Credit entry amount and labels alongside explicit `Credit` text |
| `paymentText` | `#166534` | Payment entry amount and labels alongside explicit `Payment received` text |
| `pendingText` | `#92400E` | `Waiting to sync` status text |
| `errorText` | `#B91C1C` | Failure / Needs attention text |
| `outlineStrong` | `#64748B` | Input outline/focus boundaries when contrast is needed |

Calculated against white: `textPrimary` 17.74:1, `textSecondary` 7.58:1, `brandPrimary` 9.11:1, `creditText` 7.31:1, `paymentText` 7.13:1, `pendingText` 7.09:1 and `errorText` 6.47:1. These draft pairs meet WCAG's 4.5:1 normal-text threshold; they do **not** prove that the final app as a whole is accessible. [WCAG 2.2 contrast criterion](https://www.w3.org/TR/WCAG22/#contrast-minimum)

Do not use color alone to distinguish credit from payment, amount owed from amount received, or Pending from Synced. Use words, signs and accessible status labels. A balance uses a large number with a full sentence: **Customer owes you ₹300.00** or **You owe Ramesh Kirana Store ₹300.00**.

## 5. Typography, numbers and language

- Use the platform's readable sans-serif text system with a Devanagari-capable fallback. Verify glyphs for Hindi, ₹, punctuation and numerals on actual devices.
- Suggested hierarchy: page title 24–28 sp, balance 28–36 sp, section title 18–20 sp, body 16 sp, supporting text 14 sp. Do not use size alone for meaning.
- Enable Android text scaling; test 200% text scale on the smallest supported phone. Labels and monetary values must wrap or reflow without truncating the number or hiding Submit.
- Show INR with symbol and two decimal places in ledger and export. Accept a decimal amount through a numeric keyboard, normalize to integer paise, and reject malformed, zero, negative or over-limit values. Do not place a minus sign on the amount input for Payment received; the ledger row shows its balance effect.
- Show dates in the user's chosen language with an unambiguous day/month/year where space allows. Relative labels such as Today may accompany, but not replace, a precise timestamp in entry detail or export.
- Store copy as localized resources with placeholders for shop/customer/amount. Flutter's current internationalization documentation describes generated localization from ARB resources. [Flutter internationalization](https://docs.flutter.dev/ui/internationalization)
- Hindi labels below are **draft copy for language review**, not final translations: `Credit` → `उधार`, `Payment received` → `भुगतान मिला`, `Waiting to sync` → `सिंक होना बाकी है`. A Hindi speaker should review debt direction, tone and clarity before release.

## 6. Core components and interactions

### 6.1 Amount entry

The form shows the selected customer above the amount, with a full amount label and current known balance. Put the amount field first, optional note/due date after it, and the review line immediately above Submit. The owner must tap Submit after seeing customer and amount. When Submit is tapped, disable duplicate taps while local save completes, but keep the same operation ID if a network retry follows.

For Payment received, show the current recorded amount owed, Cash/UPI manual-method options, and projected new balance. Reject an amount above the currently recorded owed balance in v1; if a queued offline payment later conflicts with server state, show Needs attention and keep the local operation for recovery. Never label UPI as verified.

### 6.2 Customer identity card

After QR resolution show a readable display label, optional shop nickname, and text asking the owner to confirm the person. If a QR is new, **Add customer** is a separate action before credit entry. If already linked, go directly to credit entry. QR scan alone never creates a ledger entry. Avoid displaying a customer's Google email unless a separately reviewed identity need requires it.

### 6.3 Ledger row and balance card

Each row shows type, signed balance effect, date and any applicable sync/dispute marker. Tap opens entry detail. Correction detail links back to original and shows reason. Do not silently replace an incorrect historical entry. The balance card must distinguish local balance including Pending entries from cloud-synced balance when they differ; owner reminder/export preview must disclose which figure it uses.

### 6.4 Sync status

| State | Exact user meaning | Recommended text/action |
|---|---|---|
| Waiting to sync | Saved on this phone, not acknowledged by cloud | `Saved on this phone. Connect to the internet to back it up.` Show last sync time. |
| Synced | Server acknowledged and stored entry | `Synced. Customer can see it after refreshing.` |
| Needs attention | Server rejected or retry cannot proceed | `This entry has not synced. Review the problem.` Keep entry and a help/export path. |
| Customer offline cache | Last server data viewed on this device | `Last updated [date and time]. New shop entries may not appear yet.` |
| Cloud unavailable/quota | New links/cloud actions cannot complete | `Cloud service is temporarily unavailable. Existing customer entries will stay on this phone until sync works.` |

Use inline status on each entry and a summary on owner home; reserve banners for actionable problems. A transient toast alone is insufficient for a pending financial entry. Status icons need text equivalents and screen-reader announcements. Never say `Backed up` for Pending.

### 6.5 QR scanner and code display

Scanner has a clearly framed camera region, short instruction and retry action. First request camera permission at the moment of scanning; if denied, explain how to retry or use Android settings. Decode only supported Udhaar Khata customer identifiers. Invalid, unsupported and revoked codes receive distinct messages. An unknown QR while offline shows **Internet needed to add this customer**, with no unverified placeholder.

The customer QR screen shows a large code and separate display label. It states that the code identifies an account and that the owner enters the amount. A previously issued code remains displayable offline. QR contents must have no PII, balance or credentials. If the customer rotates their code, show the current code after server confirmation and stop presenting the old code as current.

### 6.6 Dispute, reminder, export and account controls

- Customer can report a problem only for their own synced entry while online. Show the entry being disputed, a reason field and a notice that reporting does not change the balance. Status is Open or Resolved with owner response.
- Owner reminder has editable preview, current known amount and last-sync context. Android share sheet opens only after owner action. Cancelling means no message was sent by the app.
- Statement/export flow asks for customer and date range, shows opening/closing balances, and lets owner generate PDF or CSV. Export totals must reconcile with entry history. Explicitly label any included local Pending entries; final inclusion rule is a phase-3 decision.
- Deletion/access removal screens state the requested scope and status. Warn before sign-out or account switching when unsynced local entries exist. Retention wording must match the reviewed launch policy.

## 7. Screen-specific behavior

| Wireframe | First focus | Primary action | Empty/error focus |
|---|---|---|---|
| W01 Welcome | Role choice | Continue with Google | Network/sign-in error with retry; no accidental account creation. |
| W02 Shop setup | Shop name | Create shop | Required-name guidance; existing-shop route. |
| W03 Customer QR | QR and label | Show to owner | Initial registration needs internet; revoked/current-code explanation. |
| W05 Owner home | Amount customers owe + Scan QR | Scan customer QR | No customers → scan prompt; pending sync → persistent status. |
| W06 Scanner | Camera frame | Successful scan | Permission, invalid, revoked, unknown offline outcomes. |
| W06a Link customer | Identity label | Add customer and continue | Cancel leaves no link/entry. |
| W07 Credit form | Customer + amount | Submit credit | Amount error near field; offline save status after submit. |
| W08 Save result | Amount + sync truth | Next scan or ledger | Needs attention retains record and help path. |
| W09 Owner ledger | Customer balance + history | Credit or Payment received | Empty history, pending/rejected entries, dispute markers. |
| W10 Customer shops | Each shop's owed amount | Open shop | No shops → show QR instruction; cached age. |
| W11 Customer ledger | You owe [shop] + entries | Open entry | Offline/stale history label; forbidden data not rendered. |
| W12 Dispute | Entry and reason | Send report | Offline → internet-needed; duplicate dispute → existing status. |
| W13 Payment | Customer + current owed + amount | Submit payment | Excess amount blocked; manual method wording. |
| W14 Reminder/export | Current known amount / date range | Share or generate | Cancel no send; pending amount clearly identified. |
| W15 Settings/help | Language, sync and data controls | Chosen setting/action | Pending data warning before clearing local account. |

## 8. Feedback, errors and motion

- Show field errors next to the field and preserve entered values. State what the user can do: `Enter an amount greater than ₹0`, `Connect to the internet to add this customer`, `This QR is no longer active; ask for the current QR`.
- A financial Submit gets a persistent result screen or ledger row; do not rely on a brief snackbar as the only receipt. If the app cannot tell whether a network request succeeded, show a checking/retry state and reuse the same operation ID.
- Use progress indicators for sign-in, QR lookup, link creation and cloud sync; keep locally available ledger screens responsive while those requests run.
- Avoid unnecessary animation in the counter path. Respect system reduced-motion preference where available. Do not communicate success solely through motion, sound or color.
- Confirm actions with lasting effects such as QR rotation, access removal or deletion request. Simple Back/Cancel from an untouched form needs no confirmation.

## 9. Accessibility acceptance

Treat WCAG 2.2 AA as a **reference target for applicable mobile UI principles**, with manual Android testing in addition to automated checks. WCAG 2.2 specifies at least 4.5:1 contrast for normal text and 3:1 for large text; its minimum pointer target criterion is 24 × 24 CSS pixels with exceptions. This app's draft 48 × 48 logical-pixel target is a stricter product choice for primary Android controls, not a direct WCAG unit conversion. [WCAG 2.2](https://www.w3.org/TR/WCAG22/)

- Screen reader announces role, screen title, customer identity, amount, currency, balance direction and sync state in a sensible order. QR artwork has a useful label such as `Your customer QR code`; decorative graphics are skipped.
- Text scaling, display zoom, Hindi expansion and narrow devices do not hide amounts, entry statuses or Submit. Validate the primary paths with large text and TalkBack. Flutter provides accessibility guidance and testing tools for this work. [Flutter accessibility](https://docs.flutter.dev/ui/accessibility)
- Focus moves to a new screen title, field error or status result after transitions; after a dispute/entry post, the new status is announced without forcing the user to hunt for it.
- Money controls have visible labels, not placeholder-only labels. Credit/payment direction is in words and plus/minus signs as well as color.
- All actions have a non-gesture route. Camera permission denial offers an accessible retry/settings path.

## 10. Prototype, review and handoff gates

Prototype tests should include a busy owner, an owner using poor connectivity, a regular customer and a customer hesitant to install an app, as described in [User Personas](USER-PERSONAS.md). These personas are provisional; actual participants and observed behavior take precedence. Measure scan-to-local-save time, wrong-person/amount errors, comprehension of Pending versus Synced, Hindi clarity, and customer onboarding refusal reasons.

Before handoff to implementation, produce reviewed high-fidelity screens or component examples, finalized tokens and translations, error copy, state variants and accessibility annotations for every [wireframe](WIREFRAMES.md). Before public release, the [SRS](SRS.md) privacy, reliability, accessibility and performance tests must pass on supported Android devices.

## 11. Open design decisions

| Decision | Required before |
|---|---|
| Final brand identity, iconography and dark-theme scope | Visual design approval |
| Maximum entry amount, note length, and precise amount input formatting | Phase 1–2 validation |
| Payment allocation rule for overdue totals | Phase 3 due-date UI |
| Whether PDF/CSV includes local Pending entries or server-acknowledged entries only; exact warning text | Phase 3 export implementation |
| Hindi terminology and reminder tone reviewed with native speakers | Phase 3 exit |
| Customer access removal, re-linking and retention copy | Public release |

These choices must not change approved permissions, money semantics or recovery claims without updates to the [BRD](BRD.md), [PRD](PRD.md), [SRS](SRS.md) and [SES](SES.md).

### D06 implementation checkpoint

Customer QR uses exactly `udhaar://customer/v1/{publicId}` with a 256-bit random lowercase hex lookup ID and no personal, financial or credential fields. Own-QR read and online rotation enforce the customer session. Rotation revokes the old mapping atomically, preserves internal links and permits at most three attempts per customer per ten minutes. The customer screen renders a readable QR with account label and explains that it does not authorize payment. Account-specific secure-storage cache labels saved codes as unverified; uncertain rotation persists a recovery marker and hides the old code until online confirmation. Offline presentation works in an already verified open session, even if an attempted auth renewal fails: credentials are discarded and the account database is locked, while only the cached public QR remains with a Sign in again action. This confers no cloud or ledger authorization. Failed rotations retain an explicit failure notice after recovering the current QR. Full offline session restoration after cold startup remains D12. D07 owner resolution/linking and physical-device QR scanning remain separate gates. Synthetic authorization/rotation/cache/UI and independent rendered-image decoding evidence is recorded in implementation progress.


### D07 implementation checkpoint

Owner scanning accepts only the bounded exact `udhaar://customer/v1/{publicId}` format, requests camera permission only on scan, and provides permission retry/settings and invalid/version/revoked/internet-needed states. An online lookup authorizes the shop before displaying minimal customer identity and makes no link or financial change. Explicit Add customer creates one active relationship using an atomic, scoped D1 batch and operation receipt; same-ID/body retries replay, changed bodies conflict, and concurrent different IDs for the same shop/customer return the existing link. Live QR/ownership/customer predicates are checked at commit. Removed access is not restored by scanning. Original confirmed command bodies are saved in account/shop-specific secure storage before POST and retained after response loss/restart; new scans cannot replace an unresolved confirmation. The bounded customer list states overflow and returning customers open an authorized ledger screen. Credit/payment/history and complete pagination remain D08-D10; owner offline cache/sync remain later gates. Physical camera/device and remote D07 deployment evidence are recorded separately in implementation progress.

Customer My shops reads the signed-in customer’s active links from `/v1/me`, with loading, empty and retry states. Reopening the tab, app resume, pull-to-refresh and Refresh shops request a fresh profile. The existing first-100 limit is stated when there are more links. This list shows shop names only; balances and history remain D08–D10.

### D08 online credit implementation contract (2026-10-01)

Approved pilot limits v1: positive credit ₹0.01–₹1,00,000.00 (1–10,000,000 integer paise), optional trimmed note up to 500 UTF-16 code units, valid optional YYYY-MM-DD due date, financial JSON body at most 4,096 bytes, and existing first-100 list ceiling. General JSON/auth bodies retain the 65,536-byte ceiling. The Worker validates strict credit fields and canonical UUID v4 operation identity; unknown/forged effect fields and payment/correction variants are rejected in D08. A first online command accepts device occurrence time from 24 hours before server time to 5 minutes ahead. Receipt replay precedes this mutable clock check. Payments, corrections, full history/pagination and offline local ledger remain their later phases.

The owner opens a linked customer, enters amount/note/date, reviews customer identity and the explicit Customer owes you direction, then confirms. Review has no financial effect. The app durably saves an account/shop/link-specific command before POST and never generates a replacement ID after uncertainty. Reopening the form recovers that body with Check same credit; a response must match shop, link, type, amount/effect, note/date, occurrence time and sequence before acknowledgement. Unverified responses, storage failures, auth/network failure and rejected requests retain the saved record for recovery; it is not silently discarded. This online recovery record is not the D11 offline ledger/outbox, and does not provisionally change the visible balance.

The Worker uses the existing immutable ledger triggers and atomic entry-plus-receipt batch; live authorization is rechecked at commit and replay requires current access. Receipt retries return the original committed balance/version even after later entries, explicitly labeled as the balance when this credit was recorded. Owner link/list reads refresh the current balance. Customer My shops receives its own active link balances/versions from the same profile query and can refresh them. New minimal balance reads authorize the entire current snapshot in one SQL query; no history page or aggregate overdue total is inferred. No new migration is needed.

D08 phone feedback repair: credit due date opens a calendar picker and displays DD-MM-YYYY in both form and review; Clear due date removes this optional value. Wire/storage dates stay ISO YYYY-MM-DD. Authentication-required observations request a guarded, deferred session refresh, coalesced across screens and suppressed during/after signout. Owner and customer dated transaction rows, notes and entry details remain D10.

### D09 payment screen checkpoint (2026-10-01)

Owner customer ledger → Record payment received → amount and Cash/UPI → review customer/method/amount → Confirm payment received. Review changes no balance. All stages state that receipt is manually recorded, not bank verified. A verified result labels the original balance when recorded and offers Back to customer for refreshed state.

An uncertain saved request offers Check same payment and cannot be edited or replaced. A confirmed balance rejection shows Payment rejected; no payment was recorded, the supplied authorized balance snapshot labelled with its as-of time (or a last server read for older responses), and Edit amount and method. Editing preserves the entered amount until the user changes it; the rejected original is archived before reopening a draft. User confirmation creates the corrected operation. Full transaction history with credit/payment times on both roles remains D10.

### D10 online history checkpoint (2 October 2026)

Online D10 screens show server snapshot dates and refresh controls. Owner home displays total owed (including retained ledgers) and Load more customers. View transaction history opens dated entry cards; My shops supports Load more and opens own-shop history. Dates use DD-MM-YYYY with device-local time; due dates keep their calendar date. Explicit Customer owes you / You owe shop text accompanies money. Cash/UPI payments are manual owner records, never bank verification. Loading and no-transactions states differ from network/access errors; failed page loads retain the dated older snapshot with Retry page, while removed access hides records. No Pending/offline cache is claimed.


### D11 local ledger/outbox checkpoint (2 October 2026)

Owner customer forms use a previously verified saved ledger without waiting for HTTP. Review remains inert; Confirm shows Credit saved · Pending or Payment saved · Pending only after the SQLite commit succeeds. The screen labels the balance provisional, including Pending, and states that Pending entries are only on this device and are not backed up to the cloud. Owner history shows dated immutable rows with Synced/Pending/Needs attention, last server snapshot and a separate Synced balance. Refresh from server is explicit; View confirmed server history preserves D10 paginated online reads. Saved customer ledgers remain reachable after a transient shop-read failure in an already verified session. Home server totals are explicitly Synced-only. Cash/UPI retains the manual-receipt explanation. Customer history continues to show only server-acknowledged records. Fully offline startup remains D12.

D11 cache-limit recovery: an oversized uncached customer still offers View confirmed server history directly. An existing legacy credit/payment request can open Check same credit/payment after a minimal authorized customer read; complete offline bootstrap is required only for new local commands.
