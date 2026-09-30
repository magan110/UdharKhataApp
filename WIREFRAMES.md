# Udhaar Khata — Low-Fidelity Wireframes

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [User journeys](USER-JOURNEY-USER-FLOW.md) · [Use cases and stories](USE-CASES-USER-STORIES.md) · [UI/UX spec](UI-UX-DESIGN-SPEC.md) · [PRD](PRD.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Platform:** Android phone, portrait  
**Status:** Concept layouts for review and prototype testing; no final colors, typography or pixel measurements  
**Related:** [User Flows](USER-JOURNEY-USER-FLOW.md) · [Use Cases](USE-CASES-USER-STORIES.md) · [PRD](PRD.md) · [SRS](SRS.md)

## 1. Reading these wireframes

Each frame shows **content order and actions**, not a fixed screen size. `[Button]` means tappable action; `(*)` marks a selected option. Scrollable content continues below the drawn phone. Balance text and sync state are shown as words so they remain understandable without color. Real QR artwork is intentionally represented as `[ QR CODE ]` here.

**Primary owner path:** W01 → W02 → W05 → W06 if new → W07 → W08 → W09.  
**Primary customer path:** W01 → W03 → W10 → W11 → W12 if disputing.  
**Payment path:** W09 → W13 → W08.  
**Secondary:** W09 → W14 for reminder/export; either role → W15 for settings/help.

The owner reviews the displayed customer and amount before Submit. Scanning the QR alone never records credit. A new customer requires internet to link; a cached linked customer can be charged offline.

## 2. W01 — Welcome and role selection

```text
┌──────────────────────────────────────┐
│             Udhaar Khata             │
│                                      │
│  Simple records for shop credit      │
│                                      │
│  How will you use this app?          │
│                                      │
│  [ I run a shop                → ]    │
│  Record credit and payments          │
│                                      │
│  [ I am a customer             → ]    │
│  Show my QR and see my balance       │
│                                      │
│  Google sign-in is required          │
│  Internet needed for first setup     │
└──────────────────────────────────────┘
```

**Action:** Role selection opens Google sign-in, then owner shop setup or customer My QR.  
**States:** Loading, cancelled sign-in, no internet, identity error. Choosing a role is not authorization; the server determines account permissions.

## 3. W02 — Owner shop setup

```text
┌──────────────────────────────────────┐
│ ←  Set up your shop                  │
│                                      │
│  Shop name *                         │
│  [ Ramesh Kirana Store           ]   │
│                                      │
│  Your customers will see this name   │
│  beside their ledger.                │
│                                      │
│  One shop per owner in this version  │
│                                      │
│  [ Create shop                  ]     │
└──────────────────────────────────────┘
```

**Action:** Create one active shop, then W05 owner home.  
**States:** Blank name validation, network failure/retry, existing shop opens instead of creating a duplicate.

## 4. W03 — Customer My QR

```text
┌──────────────────────────────────────┐
│ My QR                         ⚙      │
│                                      │
│  Show this to the shopkeeper         │
│                                      │
│          ┌──────────────┐            │
│          │              │            │
│          │  [ QR CODE ] │            │
│          │              │            │
│          └──────────────┘            │
│                                      │
│  Asha Sharma                         │
│  This QR identifies your account.    │
│  The shopkeeper enters the amount.   │
│                                      │
│ [ My shops ]                         │
│                                      │
│ Home           My shops        Help  │
└──────────────────────────────────────┘
```

**Action:** Customer presents screen; owner scans. My shops opens W10.  
**States:** First registration needs internet; once issued, QR displays offline. Revoked QR requires refreshed current QR. The QR has no name, balance, Google token or phone number encoded within it; the name is separate screen text.

## 5. W05 — Owner home

```text
┌──────────────────────────────────────┐
│ Ramesh Kirana Store           ⚙      │
│                                      │
│  Customers owe you                   │
│  ₹12,450.00                           │
│                                      │
│  [ Scan customer QR            ]     │
│                                      │
│  [ Search customers...          ]    │
│  Customers                           │
│  Asha Sharma       Owes ₹300.00    → │
│  Priya Nair        Owes ₹150.00    → │
│                                      │
│  Sync: All entries synced            │
│                                      │
│ Home          Scan QR         Help   │
└──────────────────────────────────────┘
```

**Action:** Scan opens W06 scanner; customer row opens W09.  
**States:** Empty shop prompts first scan while online. Offline banner gives last sync time. If pending entries exist, separate **Local total includes unsynced entries** from the last synced cloud total where needed to avoid misleading reminders or exports. Customer list is scoped to this shop.

## 6. W06 — QR scanner and first-link decision

```text
┌──────────────────────────────────────┐
│ ←  Scan customer QR            ?     │
│                                      │
│  Ask the customer to show My QR      │
│                                      │
│    ┌────────────────────────────┐    │
│    │                            │    │
│    │      CAMERA VIEWFINDER     │    │
│    │                            │    │
│    └────────────────────────────┘    │
│                                      │
│  Hold the QR inside the frame        │
│  [ Try again ]                       │
│                                      │
│  Connected • New customers can       │
│  be added now                        │
└──────────────────────────────────────┘
```

**Scan outcomes:** Linked customer → W07 amount form. Valid but new → W06a link confirmation. Invalid/unreadable/unsupported QR → explain and rescan. Camera denied → permission guidance. Unknown QR while offline → W06b; create neither customer nor credit.

### W06a — New customer confirmation

```text
┌──────────────────────────────────────┐
│ ←  Add customer                      │
│                                      │
│  Customer found                      │
│  Asha Sharma                         │
│                                      │
│  Confirm this is the person at       │
│  your counter.                       │
│                                      │
│  Name in your shop (optional)        │
│  [ Asha Sharma                    ]   │
│                                      │
│  [ Add customer and continue    ]    │
│  [ Cancel                      ]      │
└──────────────────────────────────────┘
```

**Action:** Link once, then open W07. Cancel returns with no link or entry. If a parallel request already linked the customer, open the existing ledger rather than creating a duplicate.

### W06b — New customer while offline

```text
┌──────────────────────────────────────┐
│ ←  Customer not found offline        │
│                                      │
│  Connect to the internet to add      │
│  this customer.                      │
│                                      │
│  Customers already in your shop      │
│  can still be served offline.        │
│                                      │
│  [ Retry scan when online      ]     │
│  [ Back to home                ]      │
└──────────────────────────────────────┘
```

## 7. W07 — Credit amount and confirmation

```text
┌──────────────────────────────────────┐
│ ←  Record credit                     │
│                                      │
│  Customer                            │
│  Asha Sharma                         │
│  Confirm this is the right person    │
│                                      │
│  Amount given on credit *            │
│  ₹ [ 150.00                      ]    │
│                                      │
│  Note (optional)                     │
│  [ Rice and oil                  ]    │
│  Due date (optional)          [ + ]  │
│                                      │
│  Amount to add: ₹150.00              │
│  [ Submit credit                ]     │
└──────────────────────────────────────┘
```

**Action:** Submit saves exactly one local entry and opens W08. The fixed button remains reachable with keyboard open; confirmation is on this form to keep the counter path short.  
**States:** Empty/zero/negative/excess amount, submit in progress, permission revoked, offline local save. Actual amount maximum is a launch decision. On cancellation, no entry is recorded.

## 8. W08 — Save result and sync status

```text
┌──────────────────────────────────────┐
│        Entry saved on this phone     │
│                                      │
│  Asha Sharma                         │
│  Credit: ₹150.00                     │
│  Customer owes you: ₹450.00          │
│                                      │
│  ◌ Waiting to sync                   │
│  Only this phone has this entry      │
│  until it reaches the cloud.         │
│                                      │
│  [ View customer ledger         ]    │
│  [ Scan next customer           ]    │
└──────────────────────────────────────┘
```

**Synced variant:** Heading **Entry synced**; status **Saved to cloud**.  
**Needs attention variant:** Heading **Entry needs attention**; keep entry on phone and show **View problem / Get help**. Do not erase it or imply that the customer sees it.  
**Duplicate retry:** If the first server response is lost, retry with the same operation ID and show the existing committed result.

## 9. W09 — Owner customer ledger

```text
┌──────────────────────────────────────┐
│ ←  Asha Sharma                 ⋮     │
│                                      │
│  Customer owes you                   │
│  ₹450.00                             │
│  1 entry waiting to sync             │
│                                      │
│ [ + Credit ]  [ Payment received ]   │
│                                      │
│  History                             │
│  Today   Credit        +₹150  ◌     │
│  Sep 27  Payment        -₹200  ✓     │
│  Sep 25  Credit         +₹500  ✓     │
│                                      │
│ [ Share reminder ]                   │
│ [ Statement / Export ]               │
└──────────────────────────────────────┘
```

**Action:** Select an entry for detail/correction; Payment received opens W13; reminder/export opens W14.  
**States:** No entries, paginated history, pending/rejected entry, dispute marker, offline last-sync banner. Status symbols above require readable text and screen-reader labels in the finished UI. The balance shown here includes local pending entries and must be labeled as a local view when not fully synced.

## 10. W10 — Customer My shops

```text
┌──────────────────────────────────────┐
│ My shops                      ⚙      │
│                                      │
│  My QR  [ Show QR              ]     │
│                                      │
│  Shops with my account               │
│  Ramesh Kirana Store                 │
│  You owe ₹300.00                   → │
│                                      │
│  Patel General Store                 │
│  You owe ₹80.00                    → │
│                                      │
│  Last synced: Today, 10:42 am        │
│                                      │
│ Home           My shops        Help  │
└──────────────────────────────────────┘
```

**Action:** Shop card opens W11; Show QR opens W03.  
**States:** No linked shops explains how to present QR. Offline/stale view shows last successful sync and avoids implying the balance includes new owner entries. Each shop card is independent.

## 11. W11 — Customer shop ledger and entry detail

```text
┌──────────────────────────────────────┐
│ ←  Ramesh Kirana Store               │
│                                      │
│  You owe Ramesh Kirana Store         │
│  ₹300.00                             │
│  Last synced: Today, 10:42 am        │
│                                      │
│  History                             │
│  Sep 27  Payment received  -₹200 →  │
│  Sep 25  Goods on credit   +₹500 →  │
│                                      │
│  [ About this balance          ]     │
└──────────────────────────────────────┘
```

```text
┌──────────────────────────────────────┐
│ ←  Entry detail                      │
│                                      │
│  Goods on credit                     │
│  ₹500.00                             │
│  25 Sep • Ramesh Kirana Store        │
│  Note: Groceries                     │
│  Status: Synced                      │
│                                      │
│  [ Report a problem             ]    │
└──────────────────────────────────────┘
```

**Action:** Customer may report a problem with their own synced entry, opening W12. No customer edit/delete control. Offline history remains viewable but reports need internet. Corrections appear as linked history rather than silently replacing an old amount.

## 12. W12 — Customer dispute and owner response

```text
┌──────────────────────────────────────┐
│ ←  Report a problem                  │
│                                      │
│  Entry: Goods on credit ₹500.00      │
│  Ramesh Kirana Store • 25 Sep        │
│                                      │
│  What seems wrong?                   │
│  [ Amount should be ₹450         ]   │
│                                      │
│  Reporting will not change your      │
│  balance automatically.              │
│                                      │
│  [ Send report                  ]     │
└──────────────────────────────────────┘
```

**Customer states:** Open, Resolved with owner note, offline internet-needed, duplicate active report.  
**Owner path:** Owner sees dispute in customer ledger, reviews original, may post a separate correction with reason, and resolves with explanation. Original and correction remain visible.

## 13. W13 — Payment received

```text
┌──────────────────────────────────────┐
│ ←  Payment received                  │
│                                      │
│  From Asha Sharma                    │
│  Currently owes: ₹300.00             │
│                                      │
│  Amount received *                   │
│  ₹ [ 200.00                      ]    │
│                                      │
│  Method recorded by you              │
│  (•) Cash       ( ) UPI              │
│                                      │
│  New balance: ₹100.00                │
│  [ Submit payment               ]     │
└──────────────────────────────────────┘
```

**Action:** Submit saves local entry and opens W08 result, with Payment wording.  
**States:** Reject zero, negative or amount above the currently recorded owed balance. If an offline payment conflicts with a changed server balance later, preserve it as Needs attention and show support path. Never label manual UPI entry as bank-verified.

## 14. W14 — Reminder and statement actions

```text
┌──────────────────────────────────────┐
│ ←  Share reminder                    │
│                                      │
│  To: Asha Sharma                     │
│  Balance: ₹300.00                    │
│  Last synced: Today, 10:42 am        │
│                                      │
│  Message preview                     │
│  [ Namaste Asha ji, ₹300 is ... ]    │
│                                      │
│  [ Share using another app      ]    │
│  [ Cancel                       ]     │
└──────────────────────────────────────┘
```

```text
┌──────────────────────────────────────┐
│ ←  Statement / Export                │
│                                      │
│  Customer: Asha Sharma               │
│  Period: [ Start ] to [ End ]        │
│                                      │
│  Opening balance     ₹0.00           │
│  Closing balance     ₹300.00         │
│                                      │
│  [ Generate PDF statement       ]    │
│  [ Export CSV                   ]     │
└──────────────────────────────────────┘
```

**Rules:** Owner previews before Android sharing; the app does not send messages automatically. Date-range report includes opening balance, dated entries, corrections and closing balance. If local entries are pending, the preview explicitly distinguishes synced from local-only data; exact export inclusion policy must be set before phase 3 implementation.

## 15. W15 — Settings, help and data controls

```text
┌──────────────────────────────────────┐
│ ←  Settings and help                 │
│                                      │
│  Language        English / हिन्दी   │
│  Account         Google account     │
│  Last sync       Today, 10:42 am     │
│                                      │
│  Help with QR and sync          →    │
│  Export my data                 →    │
│  Request account deletion      →    │
│  Sign out                       →    │
└──────────────────────────────────────┘
```

**Owner variant:** Export shop data and request shop/account deletion.  
**Customer variant:** Remove access to a linked shop and request customer account deletion.  
**Safety:** Before sign-out/account switch, warn about local Pending entries and provide a recovery path; do not silently discard them. Deletion status and retention wording must match the reviewed public policy.

## 16. Prototype review checklist

| Check | What a reviewer should verify |
|---|---|
| Counter speed | Linked scan → amount → Submit is short and usable one-handed; camera failure has a recovery action. |
| Identity | Customer display label is visible on link and amount screens; QR alone never posts. |
| Balance direction | Owner and customer screens use explicit text for who owes whom. |
| Sync truth | Pending, Synced and Needs attention are distinguishable without color; pending is never called backed up. |
| Offline exception | New customer QR clearly requires internet; linked customer entry works offline. |
| Privacy | Customer can see only their own shops; no personal/financial data is encoded in QR. |
| Trust | Dispute, correction and payment history are findable; no silent deletion/editing. |
| Accessibility | Layout tolerates Hindi text expansion, large type and screen readers; actions stay reachable. |
| Recovery | Lost-device text promises restoration only for server-acknowledged records. |

These wireframes should be tested with the provisional [personas](USER-PERSONAS.md) and real pilot users. Observations should update the [PRD](PRD.md) and the next **UI/UX Design Specification** before visual design or implementation is treated as final.
