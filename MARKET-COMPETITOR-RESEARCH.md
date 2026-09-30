# Udhaar Khata — Market and Competitor Research

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [Product vision](PRODUCT-VISION.md) · [BRD](BRD.md) · [Roadmap](PROJECT-PLAN-ROADMAP.md) · [Pilot and release phases](docs/implementation/05-pilot-release.md).
<!-- DOC_NAV_END -->

**Date researched:** 29 September 2026  
**Scope:** India; digital khata and adjacent small-business ledger apps  
**Product context:** [Product Vision](PRODUCT-VISION.md) · [BRD](BRD.md) · [SES](SES.md)

## Executive finding

India already has strong digital khata products. Khatabook and OkCredit market free ledgers with cloud backup, reminders, reports and payment features; Vyapar and myBillBook add wider billing and accounting tools. Udhaar Khata should **not** enter the market claiming that basic ledgers, offline use, customer visibility, or free pricing are new. [Khatabook](https://khatabook.com/or/), [OkCredit](https://okcredit.in/en/), [Vyapar](https://vyaparapp.in/free/invoice-reminder-software), [myBillBook](https://mybillbook.in/s/features/shared-ledger/)

The specific product hypothesis to test is **customer-presented QR identification at the counter**: the customer opens their QR, the owner scans it, confirms the person, enters the amount and submits. On the official pages reviewed, competitor QR descriptions mainly concern **merchant-presented payment QR codes**. That is a difference in the published flows, **not proof that no competitor offers a similar identification feature elsewhere**. [Khatabook QR explanation](https://khatabook.com/blog/get-your-free-khatabook-qr-code-delivery-at-home/), [OkCredit features](https://okcredit.in/en/)

**Decision:** Proceed to a narrow field pilot focused on transaction speed, customer adoption, accuracy and trust. Do not expand into invoicing or inventory until the QR workflow demonstrates a practical advantage.

## Research method and limits

This is desk research from company websites, pricing pages, and an Indian government report. It reflects **vendor-published claims**, not independent hands-on verification. Pricing, feature access and app flows can change by plan, device or date. The research does not include customer interviews, app instrumentation, verified active-user data, or a defensible market-size forecast. Absence of a feature from a marketing page is not evidence that the product lacks it.

## Market context

The Indian Ministry of MSME's 2025–26 annual report says that, as of **31 January 2026**, 7,61,12,097 MSMEs and informal micro enterprises were registered across Udyam and the Udyam Assist Platform, including 3,28,80,548 in the trading category. This shows a large base of small trading enterprises; it is **not** the number of shops that extend customer credit, own Android phones, would install Udhaar Khata, or can be acquired. [Ministry of MSME annual report 2025–26](https://msme.gov.in/sites/default/files/MSMEANNUALREPORT2025-26ENGLISH_0.pdf)

The most relevant initial segment is owner-run kirana and other neighborhood shops that regularly give small amounts of customer credit, operate with intermittent connectivity, and can introduce the app to returning customers face to face. This segmentation is a **product hypothesis**, not a measured market breakdown. OkCredit explicitly markets to kirana, general stores, pharmacies, garment shops, hardware stores and other credit-using businesses, indicating that these segments are already served by a specialist competitor. [OkCredit business categories](https://okcredit.in/en/)

### Addressable-market calculation to perform after discovery

Avoid treating all registered MSMEs as the app's addressable market. A practical bottom-up estimate would use:

`reachable shops × share that extend repeat customer credit × owner Android adoption × willingness to change ledger × obtainable distribution share`

Measure those inputs in a chosen city or neighborhood through shop interviews and a pilot. Separately estimate the share of credit customers willing to install an app and sign in with Google. Until those inputs exist, a TAM/SAM/SOM number would be invented.

## Competitor landscape

| Product | Verified published offer | Implication for Udhaar Khata |
|---|---|---|
| **Khatabook** | Digital ledgers, reports, automatic backup, payment reminders, multiple businesses, multilingual support and a merchant QR for receiving UPI payments. Its website makes large merchant-use claims that are company-reported. [Official site](https://khatabook.com/or/) | High brand and feature breadth. A plain digital ledger or payment QR is not enough differentiation. |
| **OkCredit** | Free Basic plan, credit/payment records, offline entries with later sync, backup, PDF statements, reminders, customer-facing record claims, UPI payment QR and 11 languages. Basic uses mobile-number sign-in. [Features](https://okcredit.in/en/), [Digital khata](https://okcredit.in/digital-khata-book), [Pricing](https://okcredit.in/pricing) | Strongest direct feature benchmark. Offline, free, reports and customer visibility already appear in its public offer. |
| **Vyapar** | Broader billing, inventory, accounting and reminder product; official material describes offline operation and later cloud sync. Availability of individual features depends on plan. [Reminder page](https://vyaparapp.in/free/invoice-reminder-software), [Feature videos](https://vyaparapp.in/videos) | Competes when a shop needs a full business suite. Its breadth may make a focused khata experience attractive to some owners, but this needs user testing. |
| **myBillBook** | Ledger, billing, GST/inventory tools, and a shared ledger for connected businesses. Shared ledger lets the counterparty read common vouchers when parties are paired by mobile number. Its ledger page advertises plans starting at ₹199/month; exact current plan terms should be checked before a pricing comparison. [Ledger product](https://mybillbook.in/s/ledger-accounting-software/), [Shared ledger](https://mybillbook.in/s/features/shared-ledger/) | Customer-visible ledgers are not a unique claim. Udhaar Khata's proposed difference is consumer QR identification at the counter and narrow credit workflow. |
| **Paper notebook / phone notes / spreadsheet** | No platform dependency; workflow and cost vary by shop. This is the practical alternative many owners may keep using. | Must beat the existing habit on speed, confidence and recovery, not merely offer more features. This row is a research hypothesis to validate in interviews. |

### Pricing caution

OkCredit's main marketing page describes the Basic product as free with unlimited customers and entries, while its pricing page lists paid tiers including an **Unlimited Transactions** plan at ₹30 for 30 days. The pages may describe different limits or offers; do not repeat an unqualified “unlimited free transactions” claim in our positioning without checking the actual current app and terms. [OkCredit main page](https://okcredit.in/en/), [OkCredit pricing](https://okcredit.in/pricing)

Likewise, competitor self-reported downloads, merchants, ratings and collection improvements are marketing claims, not independently verified active usage or outcomes in this document.

## Feature comparison for the intended first release

**Legend:** “Published” means the cited company page describes the capability. “Not verified” means the reviewed sources did not establish it; it does not mean absent.

| Capability | Udhaar Khata planned | Khatabook | OkCredit | Vyapar / myBillBook |
|---|---|---|---|---|
| Credit and payment ledger | Yes | Published | Published | Published |
| Offline entry | Yes, linked customers | Not verified here | Published | Vyapar published; myBillBook not verified here |
| Cloud recovery | Yes, for synced entries | Published | Published | Published in product claims |
| Customer sees ledger | Yes, Google sign-in | Not verified here | Published | myBillBook shared ledger published |
| QR shown by **customer** to identify account and add credit | Planned pilot hypothesis | Not verified here | Not verified here | Not verified here |
| QR shown by **merchant** to receive UPI payment | Later phase only | Published | Published | Not assessed here |
| Manual share reminder / PDF | Yes | Published | Published | Published in broader products |
| Google-only sign-in | Yes | Not verified here | No: site advertises mobile-number sign-in | Not assessed here |

Sources for this matrix: [Khatabook official site](https://khatabook.com/or/), [Khatabook payment QR](https://khatabook.com/blog/get-your-free-khatabook-qr-code-delivery-at-home/), [OkCredit features](https://okcredit.in/en/), [OkCredit digital khata](https://okcredit.in/digital-khata-book), [Vyapar reminder/offline page](https://vyaparapp.in/free/invoice-reminder-software), [myBillBook shared ledger](https://mybillbook.in/s/features/shared-ledger/). Product plans come from the [BRD](BRD.md), not independent market evidence.

## Opportunity and downside cases

### Opportunity hypotheses

1. **Faster repeat transactions.** For a customer already linked to a shop, scanning their QR may be quicker and less error-prone than searching names or phone contacts. This must be timed against competitors and paper use.
2. **Customer visibility at the moment of purchase.** If customers already have the app open to show their QR, they may be more likely to notice an incorrect entry and resolve it early. This is an inference to test, since customer app adoption adds friction.
3. **Narrow workflow.** A small app dedicated to credit can be easier to teach than a broad billing suite for shops that do not need GST, inventory, or invoicing. This is a hypothesis; direct competitors also advertise simple entry.

### Strong counterarguments

1. **Two-sided adoption:** The proposed flow requires the customer to install the app and use Google sign-in. OkCredit advertises that its customers do **not** need the app and can be added from phone contacts. This could make Udhaar Khata harder to start using, especially for walk-in credit customers. [OkCredit getting started](https://okcredit.in/en/)
2. **Competitors already solve the basics:** OkCredit publishes offline use, backup, reminders, PDF and customer visibility. A free price and ordinary ledger are table stakes. [OkCredit](https://okcredit.in/en/)
3. **QR misuse:** A screenshot can be shown by someone other than the account holder. Shopkeeper identity confirmation and a dispute path remain necessary; the QR itself does not authorize a debt.
4. **Free-tier ceiling:** Cloudflare D1's Workers Free allowance currently lists 5 GB total storage, 5 million rows read/day and 100,000 rows written/day. The product cannot promise indefinite free cloud service without a growth plan. [Cloudflare D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/)
5. **Habit and switching cost:** Shops already using Khatabook, OkCredit, or paper may resist moving historical balances. Import and onboarding needs may become more important than new features.

## Recommended validation plan

Run discovery before building the full feature set. The following sample sizes are **proposed research targets**, not statistical claims.

| Step | Proposed sample | What to learn | Pass signal for next step |
|---|---:|---|---|
| Shop interviews | 15–20 owners across 2–3 business types | Current ledger, frequency of repeat credit, phone use, customer lookup time, existing app, willingness to ask customers for QR | At least several owners identify a costly lookup or reconciliation problem and agree to try the QR flow |
| Customer interviews | 15–20 repeat credit customers | Willingness to install/sign in, comfort presenting QR, value of seeing balance and disputes | Enough customers in pilot shops are willing to onboard without pressure; record exact refusal reasons |
| Prototype timing | 5–8 owners, each doing repeated tasks | Time and mistakes for QR scan vs their current method, with familiar and new customers | QR is measurably faster or produces fewer errors for the target shop situation |
| Small pilot | 3–5 shops for 2–4 weeks | Repeat use, customer participation, sync reliability, disputes, support workload | Owners continue to use it for real credit after initial novelty; ledger reconciles exactly and no silent data loss occurs |

Capture baseline and pilot metrics: eligible transactions, QR usage share, median seconds per entry, new-customer onboarding completion, customer install/sign-in conversion, balance disputes per 100 entries, correction frequency, daily active shops, seven-day return, offline queue age, and D1/Worker usage. Set launch thresholds after baseline measurements rather than inventing conversion goals now.

## Product and go-to-market decision

**Build the narrow QR ledger pilot, then decide whether to expand.** Start with shops that already have repeat customers willing to use Android and Google sign-in. Teach the owner and a few regular customers together; observe real counter use. Market the app on the specific flow and transparency only after the pilot demonstrates them. Keep manual customer search or a future fallback under consideration if two-sided onboarding blocks adoption; changing the confirmed first-release scope requires a BRD update.

Do not use “first,” “only,” “unlimited free,” or “3× faster” in public claims without direct, current evidence. The first release should compete on a tested workflow, not feature count.

## Source register

| Source | Used for | Source type / caveat |
|---|---|---|
| [Ministry of MSME annual report 2025–26](https://msme.gov.in/sites/default/files/MSMEANNUALREPORT2025-26ENGLISH_0.pdf) | Registered MSME/UAP count as of 31 Jan 2026 | Government report; broad category, not digital-khata TAM |
| [Khatabook product site](https://khatabook.com/or/) | Published ledger, backup, payment, reports and language features | Vendor marketing |
| [Khatabook QR explainer](https://khatabook.com/blog/get-your-free-khatabook-qr-code-delivery-at-home/) | Merchant QR payment flow | Vendor explainer dated 2020; confirm current flow in app |
| [OkCredit product site](https://okcredit.in/en/) | Ledger, offline, reminders, customer onboarding and claims | Vendor marketing |
| [OkCredit digital khata page](https://okcredit.in/digital-khata-book) | Offline/cloud and customer visibility | Vendor marketing |
| [OkCredit pricing](https://okcredit.in/pricing) | Free and paid plan descriptions | Vendor page; apparent wording conflict with main page |
| [Vyapar reminder page](https://vyaparapp.in/free/invoice-reminder-software) | Broader suite, offline reminder claim | Vendor marketing; plan specifics vary |
| [myBillBook ledger page](https://mybillbook.in/s/ledger-accounting-software/) | Ledger, billing and starting-price clue | Vendor marketing; pricing may change |
| [myBillBook shared ledger](https://mybillbook.in/s/features/shared-ledger/) | Connected business ledger visibility | Vendor feature page; applicability to consumer customers differs |
| [Cloudflare D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/) | Current infrastructure limits | Official provider documentation; recheck before launch |

**Refresh this research before public positioning or pricing decisions.** Competitor websites show what is marketed, not necessarily everything available or the experience users actually get.
