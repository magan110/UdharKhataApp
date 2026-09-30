# Udhaar Khata — User Personas

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [Product vision](PRODUCT-VISION.md) · [PRD](PRD.md) · [User journeys](USER-JOURNEY-USER-FLOW.md) · [UI/UX spec](UI-UX-DESIGN-SPEC.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 provisional  
**Date:** 29 September 2026  
**Research status:** Hypothesis-based personas; no Udhaar Khata user interviews have been completed  
**Related:** [Product Vision](PRODUCT-VISION.md) · [Scope](SCOPE.md) · [PRD](PRD.md) · [Market Research](MARKET-COMPETITOR-RESEARCH.md)

## 1. How to use this document

These personas are **design tools, not descriptions of interviewed people or proven market segments**. Names and example circumstances are fictional. They represent different jobs, constraints and adoption risks implied by the approved product scope. They should guide prototype tests and be rewritten after observing actual shopkeepers and customers.

The first release has two external roles: **shop owner** and **customer**. One person can fit more than one situation; device quality, network access and confidence with apps may change from day to day. Design decisions should respond to observed behavior rather than age, gender or occupation stereotypes.

| Persona | Role | Main job | Primary risk to validate |
|---|---|---|---|
| P1 — Ramesh, busy counter owner | Shop owner | Record repeat credit quickly while serving a queue | Is scanning genuinely faster than current customer lookup? |
| P2 — Shabnam, connectivity-constrained owner | Shop owner | Keep an accurate ledger through network outages | Do offline states and recovery limits remain understandable? |
| P3 — Asha, regular credit customer | Customer | Present account and verify what she owes | Does a shared ledger build trust and get used? |
| P4 — Imran, reluctant customer | Customer | Complete a purchase with little setup | Will mandatory app install and Google sign-in block adoption? |
| S1 — Support operator | Internal secondary user | Resolve sync, access and deletion issues safely | Can support help without overexposing financial data? |

## 2. P1 — Ramesh, busy counter owner

**Illustrative context:** Runs one neighborhood shop, serves several customers in quick succession, and gives small amounts of repeat credit. Uses an Android phone at the counter and currently searches a paper book or another ledger app for a familiar customer's name. Details are hypothetical until field research confirms them.

**Goal:** Complete a correct credit entry without holding up the next customer.

**Jobs to do**

- Identify the right returning customer immediately.
- Enter the amount once and see the updated balance.
- Record a partial payment and explain the remaining amount later.
- Correct mistakes without losing the record of what changed.

**Moment of use:** A customer shows their QR while others are waiting. Ramesh scans, checks the displayed identity, enters ₹150 and taps Submit. If offline, he must know whether the entry is safely saved on his phone and whether it has reached the cloud.

**Needs and frustrations to test**

| Need or possible frustration | Product implication |
|---|---|
| Searching names may be slow or error-prone | Scan should take the owner directly to a linked customer's amount form. |
| QR scanning could be slower if camera or lighting is poor | Fast retry and clear camera feedback; measure against existing lookup during pilot. |
| A wrong customer or amount is costly | Show customer identity and amount before submission; preserve correction history. |
| A short network outage cannot stop the counter | Save linked-customer entries locally, label them Waiting to sync. |
| A simple balance is not enough in a disagreement | Dated history and exportable statement. |

**Representative scenario:** A regular customer takes goods worth ₹150. Ramesh scans the customer's QR, confirms the displayed name, enters ₹150, and sees the updated owed amount. Later the customer pays ₹50, so Ramesh records Payment received and the balance drops by ₹50. The UPI/Cash method is recorded manually, without suggesting bank verification.

**Success signal:** The QR workflow is faster or produces fewer lookup mistakes than Ramesh's existing method; he can explain a balance from entries without recalculating by hand. The [PRD](PRD.md#3-goals-and-success-measures) proposes a pilot median under 15 seconds from successful linked scan to local save, subject to real-device measurement.

**Research questions:** How often do repeat customers buy on credit? How long does current lookup take? Would Ramesh ask customers to install an app? What proof does he need before trusting a pending offline entry?

## 3. P2 — Shabnam, connectivity-constrained owner

**Illustrative context:** Owns one small shop and uses an Android phone with inconsistent mobile data. The issue is connectivity, not an assumed lack of technical ability. She may have entries waiting to sync at closing time.

**Goal:** Keep working and know exactly which records are recoverable if the phone is lost.

**Jobs to do**

- Find a previously linked customer even when the network drops.
- Record credit or a received payment offline without repeating an entry later.
- See which entries have synced and which still need attention.
- Recover acknowledged records on a replacement phone.

**Moment of use:** The network is down when a returning customer presents a QR. The scan finds the locally linked customer, and Shabnam saves ₹200 credit. The app shows **Waiting to sync**. When internet returns, it syncs once. A first-time customer's QR requires an online check and must not be accepted as an unverified account.

**Needs and frustrations to test**

| Need or possible frustration | Product implication |
|---|---|
| Unclear offline state may lead to duplicate entries | Separate Saved on this phone from Synced to cloud in plain language. |
| A retry after an error may charge twice | Use one operation identity across retries and show the original outcome. |
| A lost phone may contain unsynced records | Show last successful sync and explain the recovery boundary before an incident. |
| A new customer appears during an outage | Explain that internet is needed to add the customer; do not create an unverified ledger. |

**Success signal:** Shabnam can perform the offline task, correctly explain the pending state, and verify after reconnection that exactly one entry reached the cloud. A recovery drill restores every server-acknowledged entry and does not falsely imply that pending entries were restored.

**Research questions:** How long do outages usually last? Does the phone change hands? What wording makes Pending versus Synced understandable? Would an explicit sync reminder be useful or annoying?

## 4. P3 — Asha, regular credit customer

**Illustrative context:** Buys from one or more local shops and sometimes settles later. Has an Android phone and a Google account. She is willing to show a QR if it is quick and if she can see what each shop records.

**Goal:** Know what she owes each shop and challenge an incorrect entry without a public argument at the counter.

**Jobs to do**

- Show one personal QR to the shopkeeper without sharing her phone number or balance in the code.
- See each shop's balance and dated transactions separately.
- Distinguish a current synced balance from an older cached balance.
- Report a specific questionable entry and see its status.

**Moment of use:** Asha presents her QR. The owner scans and enters ₹300. After the shop entry syncs and her app refreshes, she sees the shop's new balance. If an entry appears incorrect, she opens it and reports a dispute. Reporting does not change the amount until the owner posts a correction.

**Needs and frustrations to test**

| Need or possible frustration | Product implication |
|---|---|
| A single balance without explanation may be hard to trust | Show transaction type, date, amount, payments and corrections. |
| Different shops should not learn about one another | Keep shop ledgers and access separate. |
| Offline history could be stale | Show the last successful sync time and refresh state. |
| A screenshot of her QR can be copied | QR must not expose ledger data or authorize a charge; owner confirms identity. |
| A disagreement can be uncomfortable | Provide a private dispute path tied to one entry. |

**Success signal:** Asha can open the right shop ledger, explain the displayed amount from dated entries, and find the dispute action without help. She understands that presenting her QR identifies her account but does not prove she approved an amount.

**Research questions:** Would Asha install an app just for a shop ledger? Does seeing entries change her willingness to present a QR? What notification, if any, would help her notice new entries without adding unwanted messaging cost?

## 5. P4 — Imran, reluctant customer

**Illustrative context:** A repeat customer with an Android phone who wants to finish the purchase quickly. He may not want another app, may have limited storage/data, or may prefer not to use a Google account for shop credit. These are hypotheses to investigate, not traits assigned to a demographic group.

**Goal:** Complete the purchase without an unexpected setup burden or privacy concern.

**Jobs to do**

- Understand why the shop asks for an app and what information it shares.
- Decide whether the benefit of a visible ledger outweighs installation and sign-in effort.
- Use the QR quickly on later visits if he chooses to join.

**Moment of use:** The owner asks Imran to install Udhaar Khata before entering a new credit sale. Imran hesitates because he has little time. The current first-release scope cannot create a verified shared ledger for him until he signs in and his QR is linked online.

**Product implication:** Onboarding should be brief and truthful about what the QR does and what data the owner sees. The app must not claim that QR use is mandatory for every shop purchase. If a meaningful share of eligible customers refuses installation, product leadership should revisit the approved QR-only onboarding scope rather than quietly creating unverified customer identities.

**Success signal:** Research records how many invited customers complete sign-in, how long it takes, and why others decline. A decision on fallback onboarding is made from pilot evidence, not assumed away.

**Research questions:** Is installing a customer app acceptable for occasional credit? Would a shop invite customers before their next purchase? Which matters more: no phone number, visibility, speed, or simply avoiding an extra app?

## 6. S1 — Support operator (secondary persona)

**Illustrative context:** A person responsible for a small public service's support and operations, possibly the product owner at first. Handles reports about wrong entries, failed sync, lost phones, and data access/deletion.

**Goal:** Help users without changing balances silently or exposing unrelated financial records.

**Needs:** A request ID, scoped account/shop identifiers, sync-state and error metadata, a documented recovery runbook, and an audit trail for any authorized export or deletion. Routine support should not require full access to transaction notes or all shop ledgers.

**Success signal:** The operator can explain whether an entry is Pending, Synced or rejected; route a balance dispute to the owner; and rehearse restoring acknowledged data in a separate environment. Admin actions remain restricted and auditable.

## 7. Cross-persona design tensions

| Tension | Affected personas | First-release decision |
|---|---|---|
| Fast owner entry vs customer control | P1 and P3 | Owner reviews before posting; customer sees synced entry and can dispute it. Customer approval of each amount is outside v1. |
| Offline work vs cloud recovery | P2 and P3 | Local Pending is visible; only server-acknowledged data is recoverable on a new phone. |
| QR simplicity vs identity abuse | P1, P3 and P4 | QR carries a public lookup ID only; owner confirms person and amount; server checks account permissions. |
| Shared ledger value vs two-sided onboarding | P1, P3 and P4 | Both parties use the app in v1; measure refusal and conversion in discovery/pilot. |
| Free service vs reliable growth | All | Monitor D1/Worker quotas and define a capacity response before larger rollout. |

## 8. Validation and update plan

During discovery, recruit a range of owner and customer situations rather than selecting only willing early adopters. The [Market Research plan](MARKET-COMPETITOR-RESEARCH.md#recommended-validation-plan) proposes 15–20 owner interviews, 15–20 customer interviews, prototype timing and a 3–5 shop pilot. Record actual behaviors and direct quotes with consent. Do not present the fictional names or scenarios above as research evidence.

For each persona, confirm or revise: job frequency, current method, device/connectivity context, Google sign-in feasibility, QR adoption, transaction speed, trust concerns and recovery expectations. Split or merge personas only if observed needs differ enough to change a product decision. Update affected [PRD](PRD.md), [SRS](SRS.md) and [Scope](SCOPE.md) requirements if findings alter first-release behavior.
