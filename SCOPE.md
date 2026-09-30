# Udhaar Khata — Scope Document

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [BRD](BRD.md) · [PRD](PRD.md) · [SRS](SRS.md) · [Roadmap](PROJECT-PLAN-ROADMAP.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**Project:** Free Android customer-credit ledger  
**Scope baseline:** [Product Vision](PRODUCT-VISION.md), [BRD](BRD.md), [PRD](PRD.md), [SRS](SRS.md), [SES](SES.md)

## 1. Purpose

This document defines the boundary of the **first public release** of Udhaar Khata and the work needed to reach it. It is the reference for deciding whether a feature request belongs in the release, should be scheduled later, or requires a change to the approved scope. The PRD describes screen behavior, the SRS gives testable requirements, and the SES describes implementation.

## 2. Product outcome

A shopkeeper can record customer credit quickly by scanning a QR code shown by the customer, entering an amount, and submitting it. The shopkeeper can record payments and explain the balance using a dated history. The customer can see their own history and report a disputed entry. Existing linked customers can be served when the shopkeeper has no internet; new customer linking requires internet. The app is free for owners and customers.

**Success condition:** A shopkeeper can use the app for real daily credit without losing or duplicating entries, and a customer can understand the resulting balance. The [PRD success measures](PRD.md#3-goals-and-success-measures) and the release gates below specify how that claim will be tested.

## 3. Scope boundaries

| Boundary | First-release decision |
|---|---|
| Geography and currency | India-focused; INR only |
| Platform | Flutter Android app; no iOS or browser app |
| Accounts | Google sign-in for both owners and customers |
| Shops | One owner account manages one shop; no staff role |
| Customers | A customer may be linked to multiple shops, with a separate ledger for each |
| QR direction | Customer shows their identity QR; shopkeeper scans it to find/link that customer |
| Payments | Owner manually records cash or UPI received; no bank or UPI verification |
| Cloud | Cloudflare Worker API and D1 store acknowledged data; local SQLite supports offline work |
| Price to users | Free in the first release; no promise of unlimited provider capacity |
| Languages | English and Hindi |
| Release path | Private test → small-shop pilot → public Android release after gates pass |

The QR identifies an account. It does not authorize a debt or prove that a payment happened. The owner reviews the displayed customer and amount before submitting.

## 4. Work included in the first public release

### 4.1 Accounts and relationships

- Owner and customer Google sign-in and role-specific onboarding.
- Owner shop creation, with one active shop per owner.
- Customer registration, personal QR generation and offline display of an already issued QR.
- Owner QR scan: resolve online, offer **Add customer** when the customer is new to that shop, and open the existing ledger when already linked.
- One shop/customer relationship per pair; one customer may be linked to several shops.
- Access checks so each owner sees only their shop and each customer sees only their own ledgers.

### 4.2 Ledger operations

- Credit sale entry, payment received, and correction with the original history retained.
- Amounts in INR, exact integer-paise balance calculations, optional notes and optional credit due dates.
- Cash/UPI as manually entered payment labels.
- Owner home with shop total, customer list and per-customer ledger; customer home with linked shops, balances and dated histories.
- Customer dispute report on a specific entry and owner resolution with a note; dispute actions do not silently change balances.
- Duplicate prevention on customer linking and transaction submission/retry.

### 4.3 Offline operation and recovery

- Local storage of owner records and cached customer relationships.
- Offline scan and entry for a customer previously linked to that shop. Unknown QR scans cannot create a customer while offline.
- Durable pending sync queue, retry after reconnection, visible **Waiting to sync**, **Synced**, and **Needs attention** states.
- Customer offline reading of last synced history, marked with the last sync time.
- New-phone restore of server-acknowledged data and clear explanation that records still pending on a lost phone cannot be restored from D1.

### 4.4 Sharing, controls and operations

- Owner-reviewed reminder through the Android share menu; no automatic dispatch.
- PDF customer statement and CSV export with opening/closing balances for a selected period.
- English and Hindi core screens and messages, accessible labels and controls.
- Owner data export and deletion-request workflow; customer shop-access removal and account-deletion request, subject to a published retention policy.
- Production monitoring, quota alerts, operational backup and tested restoration before public use.
- Help path for disputes, QR errors, sync problems, lost phones, and data requests.

The first release includes both the P0 and P1 items in the [PRD scope table](PRD.md#5-release-scope-and-priorities). P1 is a later delivery phase inside the first-release commitment, not an optional launch feature.

## 5. Explicitly excluded from this release

| Exclusion | Reason or later trigger |
|---|---|
| Supplier/payables ledger | First release concentrates on money customers owe the shop. |
| Multiple staff or multiple shops per owner | Adds permissions, concurrent editing and recovery complexity. |
| Customers without an app/Google account | The approved flow requires a customer QR. Pilot may show a need for an alternative onboarding path. |
| Manual customer creation without a verified customer account | Would weaken the approved shared-ledger identity model; requires separate design. |
| Automated SMS, WhatsApp or other messaging | Adds delivery cost, consent and support work. Owner can share a prepared reminder manually. |
| UPI collection, payment gateway, bank confirmation | Manual payment entries only; no money moves through the app. |
| Refunds, advances, negative customer balances | v1 records payment only up to the amount owed. |
| Bill photos, inventory, invoices, GST filing, loans or AI | Separate products/features beyond the core khata workflow. |
| iOS, web, desktop, additional currencies/languages | Android, INR, English and Hindi first. |
| Unlimited free cloud storage or unlimited scale | Cloudflare free plans have quotas and may change. |

These exclusions are not judgments that the features are unimportant. They keep the first release testable around the approved daily-credit journey.

## 6. Project deliverables

| Deliverable | Completion evidence |
|---|---|
| Flutter Android application | Signed test build passes the owner and customer end-to-end journeys on supported devices. |
| Cloudflare Worker and D1 | Versioned schema/migrations and authenticated API pass authorization, money and duplicate-operation tests. |
| Offline data and sync | Airplane-mode and reconnect tests prove a locally saved entry survives restart and reaches cloud once. |
| User-facing help and policies | English/Hindi help for critical flows; reviewed privacy, retention and deletion wording ready before launch. |
| Operational procedures | Monitoring and quota alerts, backup/restore runbook and completed restore drill. |
| Test evidence | Requirement-linked test results, accessibility review, security review and pilot findings. |
| Release package | Approved Android release artifact, store material, release notes and support contacts. |

This scope document does not authorize deployment or publication; those are separate external actions under the workspace instructions.

## 7. Phase boundaries

| Phase | Scope delivered | Exit gate |
|---|---|---|
| **0 — Foundation** | App shell, Google identity, shop/customer roles, local/cloud schema, test environments | Sign-in works and cross-account access is denied. |
| **1 — Online ledger** | QR registration, scan/link, credit/payment, balances and history | Complete online customer journey; exact balance and duplicate tests pass. |
| **2 — Offline and trust** | Local queue, reconnect sync, customer view, correction, dispute | Repeat QR works offline, unknown QR is blocked offline, sync posts once, customer isolation holds. |
| **3 — Release completeness** | Due dates, manual reminder, PDF/CSV, Hindi, data controls, accessibility, backups | Exports reconcile; language/data controls work; restore drill passes. |
| **4 — Pilot and launch** | Private testing, small-shop pilot, fixes, production readiness | Performance, security, data recovery, quota and pilot acceptance gates pass before public release. |

There is no fixed calendar or staffing commitment yet. The next **Project Plan / Roadmap** document will add sequencing, owners, estimates and dependencies as planning assumptions rather than inventing dates.

## 8. Acceptance and handoff

The first release is in scope-complete condition when all [SRS requirements](SRS.md) assigned to phases 0–4 have verification evidence and the [PRD](PRD.md) P0/P1 flows work in the pilot. Specifically:

1. An online first visit creates one customer link and one credit entry after owner confirmation.
2. A returning visit works offline and syncs exactly once after reconnection.
3. Owner/customer balances reconcile to the immutable transaction history, including payments and corrections.
4. Customers can see only their own ledgers and report their own entry disputes.
5. Exports reconcile; reminders require owner action; English/Hindi critical flows are usable.
6. A lost-phone recovery drill restores acknowledged data and correctly explains missing pending data.
7. Monitoring, quota response, backup/restore, privacy/retention and support processes are ready for public use.

A passing build alone is not enough; phase evidence and a real shop pilot are required before launch.

## 9. Dependencies and assumptions

- Google OAuth configuration, Android app signing, Cloudflare account/environments, D1 and Worker deployment access must be available for implementation. No credentials belong in source files.
- Shops and customers in the first pilot have supported Android devices and Google accounts. The customer must install/sign in before presenting a QR.
- Internet is available for first registration, first-time shop/customer linking, server sync, new-device recovery and dispute submission. Existing linked customer entry can proceed offline.
- D1/Worker free allowances may support the pilot but are finite; use monitoring and a capacity decision before admitting a larger public population.
- Privacy, retention, deletion and backup details are resolved before real public financial data is accepted.
- Exact amount limits, supported Android versions and overdue payment-allocation rules are fixed at the phase gates named in the [SRS open decisions](SRS.md#11-open-decisions-and-change-control).

## 10. Change control

Requests that add excluded capabilities, expand platforms/roles, change QR identity or consent behavior, allow payments beyond the balance, or change data retention alter the approved scope. Record each request with its user problem, expected benefit, affected requirements, cost, risk and phase. Update the [BRD](BRD.md), [PRD](PRD.md), [SRS](SRS.md) and [SES](SES.md) as needed before implementation.

Changes discovered during the pilot should be judged against the core outcome: **faster, clearer and recoverable customer-credit records for owner and customer.**
