# Udhaar Khata — Product Vision Document

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [Market research](MARKET-COMPETITOR-RESEARCH.md) · [BRD](BRD.md) · [Scope](SCOPE.md) · [PRD](PRD.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Related documents:** [Business Requirements](BRD.md) · [Software Engineering Specification](SES.md)

## Product vision

**Make everyday shop credit as easy to record as scanning a customer's QR code, and as easy to understand as checking a clear balance.**

Udhaar Khata is a free Android app for small shopkeepers and their customers. A customer shows a personal QR code at the counter. The shopkeeper scans it, enters the credit amount, checks the customer and amount, and submits. When the customer pays, the shopkeeper records the payment. Both can see a dated account history, so neither has to rely on memory or a paper notebook.

The product should remain useful during poor connectivity. Previously linked customers can be served offline; records sync to Cloudflare D1 when the internet returns. A new customer must be linked online so their account can be verified.

## The problem we are solving

Small shops often extend informal credit. Paper books and private notes make it easy to lose an entry, miscalculate a balance, or disagree about when a payment was made. Entering a customer's name and details for every visit also slows the counter. Customers have limited visibility into what a shop has recorded for them.

Udhaar Khata gives the shopkeeper a quick way to identify a returning customer and maintain a reliable ledger. It gives the customer a view of the same dated entries and a way to flag a disputed one.

## Who it serves

| Person | What they need | Product promise |
|---|---|---|
| Shop owner | Record credit and payments quickly, know who owes what, keep working without internet | Scan a familiar customer, enter the amount, and get an accurate ledger with visible sync status |
| Customer | Show the right account easily and understand the shop's records | Present one QR code, see each shop's balance and history, and report a disputed entry |

The first release supports one owner account per shop. A customer may be linked to several shops and sees each shop separately. Staff access and multiple shops per owner come later.

## The defining experience

1. **Customer signs in with Google** and opens their personal QR code.
2. **Shopkeeper scans the QR.** For a new customer, the app offers **Add customer**; for a linked customer, it opens the entry screen.
3. **Shopkeeper enters the credit amount, checks the customer and amount, and submits.** The same ledger supports recording a payment received.
4. **Both see the updated account history** after sync. An offline owner entry is clearly marked as waiting to sync until it reaches the cloud.
5. **A disagreement has a clear path:** the customer flags a specific entry; the owner reviews it and records any correction without erasing the original history.

The QR code identifies the customer account. It does not approve a charge or transfer money. The shopkeeper confirms the person and amount before submitting.

## Value and positioning

Udhaar Khata starts with one job: **a shared, understandable record of shop credit.** Its main advantages are a fast QR flow at the counter, customer visibility, and continued operation for linked customers when the network fails. The app is free for both shopkeepers and customers.

The product does not need inventory, invoicing, lending, bank integration, or AI to make this first job useful. Those features should be considered only after the ledger is trusted and the core flow works in real shops.

## Product principles

1. **Fast at the counter.** A returning customer's credit entry should take a scan, amount entry, and deliberate submission.
2. **A balance must be explainable.** Every amount has a dated entry; corrections preserve the original record.
3. **Never hide sync uncertainty.** Show whether an entry is on the phone, acknowledged by the cloud, or needs attention.
4. **The customer can see their account.** Show a separate balance and history for every linked shop, with a last sync time when viewing cached data.
5. **Ask only for what the job needs.** Sign in with Google; avoid collecting contacts or putting personal and financial data into QR codes.
6. **Keep costs measurable.** Design within D1 and Workers free allowances during the pilot, monitor usage, and plan for growth before public scale.

## First-release promise

The first public Android release will provide Google sign-in, customer QR display, shopkeeper scanning and linking, credit and payment recording, balances, dated histories, corrections, disputes, optional due dates, manually shared reminders, PDF statements, CSV export, English and Hindi, and offline use for previously linked customers. It will also show sync and recovery status clearly.

The release will use Flutter for Android, local SQLite storage, a Cloudflare Worker API, and Cloudflare D1. These are delivery choices; the customer-facing promise is a quick, trustworthy ledger.

## What is outside the first release

Supplier balances, staff accounts, multiple shops per owner, photos of bills, automatic reminders, verified payment collection, refunds and advances, inventory, invoices, and additional platforms or currencies. These can be evaluated in later phases based on pilot evidence.

## How we will know it is working

The private test and shop pilot should demonstrate:

- A returning customer's scan-to-saved-credit flow has a pilot median below 15 seconds on supported devices.
- Displayed balances reconcile exactly with the underlying entries; retries never create duplicate charges.
- A previously linked customer can be charged offline and the entry syncs once after reconnection.
- Customers can find their own shop history and flag a disputed entry; they cannot see another customer's records.
- Shopkeepers understand the difference between **Waiting to sync** and **Synced**.
- Cloudflare usage stays within the pilot's agreed free-tier budget, with alerts before limits are reached.

These are goals to validate, not measured results. Feedback should come from actual shopkeepers and customers using the app during normal transactions.

## Roadmap direction

| Stage | Outcome |
|---|---|
| Foundation | Secure sign-in, shop/customer identity, cloud and local data foundations |
| Core ledger | QR linking, credit, payments, balances, and transaction history |
| Trust and offline use | Reliable sync, correction history, customer view, and disputes |
| Complete first release | Statements, reminders, due dates, Hindi, export, deletion workflow, and accessibility |
| Pilot and public launch | Field validation, recovery and security checks, quota review, and Android release |

The [BRD](BRD.md) defines acceptance criteria for each stage. The [SES](SES.md) defines the technical design and test gates.

## Risks and decisions to manage

- **Mistaken identity:** Someone can show a screenshot of another person's QR. The shopkeeper must confirm the displayed customer before submitting an amount.
- **Offline recovery:** A record still waiting to sync exists only on that phone. The app must communicate this before users rely on cloud recovery.
- **Cloud limits:** D1's free tier is finite, and Workers have separate limits. Serving the public for free requires monitoring, efficient queries, and a funding or capacity decision if usage grows.
- **Financial privacy:** Customer linking, account access, export, and deletion need careful permissions and a reviewed public privacy/retention policy before launch.

## One-sentence test for future features

**Does this make shop credit faster to record, easier to verify, or safer to recover for both the shopkeeper and customer?** If not, it does not belong in the first release.
