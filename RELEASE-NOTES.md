# Udhaar Khata — Release Notes

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [Roadmap](PROJECT-PLAN-ROADMAP.md) · [Deployment runbook](DEPLOYMENT-RUNBOOK.md) · [QA cases](TEST-CASES-QA-CHECKLIST.md) · [User manual](USER-MANUAL-HELP.md).
<!-- DOC_NAV_END -->

**Document version:** 1.0 draft  
**Prepared:** 29 September 2026  
**Release:** Planned Android v1  
**Publication status:** **Not published. No build, test result or deployment is evidenced.**  
**Source of intended scope:** [PRD](PRD.md) · [SRS](SRS.md) · [Project Plan](PROJECT-PLAN-ROADMAP.md) · [Test Cases / QA Checklist](TEST-CASES-QA-CHECKLIST.md)

## 1. Release record to complete before publication

These fields must be filled from the approved release candidate, not guessed from this plan. A release note may state only features that are implemented, verified and included in the shipped binary/backend.

| Field | Current value | Publication evidence required |
|---|---|---|
| Public version and Android build number | `[NOT ASSIGNED]` | Signed artifact metadata and store track. |
| Release date and rollout channel | `[NOT SCHEDULED]` | Approved rollout record. |
| Supported Android versions/devices | `[NOT DECIDED]` | Phase-0 decision and device matrix results. |
| Flutter app source commit and artifact checksum | `[NOT BUILT]` | CI build and signing record. |
| Worker version and API version | `[NOT DEPLOYED]` / planned `/v1` | Cloudflare deployment record and compatibility check. |
| D1/local SQLite migration versions | `[NOT APPLIED]` | Migration output and restore/reconciliation results. |
| QA/security status | `[NOT RUN]` | Passed [Test Plan](TEST-PLAN.md) and [SEC gates](SECURITY-REQUIREMENTS.md#8-required-security-tests-and-release-gates). |
| Backup/restore status | `[NOT CONFIGURED]` | Isolated restore drill and named owner. |
| Known issues and workaround | `[NOT ASSESSED]` | Triage from final candidate, severity and user impact. |
| Support contact and privacy-policy link | `[NOT SET]` | Live, reviewed destinations in app/store listing. |
| Product/release approver | `[NOT ASSIGNED]` | Recorded launch decision. |

**Release-note rule:** Delete or rewrite a planned feature below if it is not in the approved release candidate. Do not mark “No known issues” until the defect tracker and pilot feedback have been reviewed. Do not reuse these notes for public posting while any field above says “not” or has a placeholder.

## 2. Draft public notes for the planned first release

The following is **proposed copy**, not a statement that the app is available today. It should be edited for the actual store listing and translated/reviewed in English and Hindi after the build passes.

> **Udhaar Khata for Android — planned first release**
>
> Keep a simple, shared record of customer credit. Customers sign in with Google and show their QR code. A shop owner scans it, adds the customer to their shop when needed, and records the credit amount after reviewing the customer's name and amount. The owner can also record payments received as Cash or UPI, and both sides can view the dated balance and history for their own shop relationship.
>
> For a customer already linked to a shop, the owner can save an entry without internet. It stays marked **Waiting to sync** until the cloud confirms it. Customers see acknowledged entries after refreshing. Owners can correct an entry with a visible history; customers can report a disputed entry. The owner can preview a reminder before sharing it, and generate PDF/CSV statements. English and Hindi are planned for core flows.
>
> **Important:** A QR is for finding a customer, not for authorizing a charge. Cash/UPI labels are entered by the owner; the app does not verify a bank transfer. Entries that have not synced are stored on the owner's phone and cannot be restored from the cloud if that phone is lost.

The final public wording must say whether correction, dispute, due date, reminder, PDF/CSV, Hindi and data-request features are actually in the shipped release. The PRD includes all of them in first-release scope, but none is implemented yet. Free-to-user access is the intended product policy; never claim unlimited storage or guaranteed uninterrupted free cloud service.

## 3. Planned feature detail for reviewer confirmation

| Area | Planned behavior to confirm in release candidate | Acceptance evidence |
|---|---|
| Sign-in and shop | Google sign-in for owner/customer; one shop per owner; customer can link to multiple shops. | TC-001–006, account-isolation review. |
| Customer QR | Customer sees versioned lookup QR, including cached offline display; owner sees linked/new outcome; new link requires internet and owner confirmation. | TC-007–014. |
| Credit and payment | Owner confirms person/amount, records positive INR credit and manually received Cash/UPI payment; exact paise balance; payment no greater than owed. | TC-015–020, D1 reconciliation. |
| Shared history | Owner sees own shop/customer entries; customer sees only their own ledgers in each linked shop. | TC-024–025 and full access matrix. |
| Offline and sync | Existing linked customer may be served offline; local outbox survives restart, uses same operation ID on retry and shows Pending/Synced/Needs attention. | TC-027–037, response-loss fault test. |
| Correction and dispute | Original entry stays visible; correction adds signed adjustment/reason; customer dispute and owner resolution leave balance unchanged unless separately corrected. | TC-021–023, TC-038–039. |
| Due dates and reminders | Optional due date on credit; owner previews reminder and chooses sharing destination; no automatic message. | TC-026, TC-040. |
| Reports and data controls | Customer PDF/CSV statement with opening/closing balances; tracked export/deletion/access-removal requests. | TC-041–044, policy review. |
| Language/accessibility | English/Hindi critical paths, explicit debt direction, readable status text and screen-reader support. | TC-045, device review. |
| Recovery and operations | A new phone restores acknowledged data; encrypted D1 backup/restore, quotas and support route are in place. | TC-035, TC-049–053 and runbook drill. |

Do not collapse the reviewer table into a blanket “all features shipped” statement. Product owner and QA should mark each row **Included / Delayed by approved scope change / Removed** with a test link before publishing customer-facing notes.

## 4. Planned limitations and user guidance

These are design limits of the intended first release. Keep them in the final notes if they remain true, and place critical ones in the app's Help screens rather than relying only on store text.

- **Android and INR only.** iOS, web and other currencies are outside v1. Supported Android OS versions must be published after device testing.
- **Google sign-in and customer app required for QR linking.** A new customer cannot be added from an unknown QR while the owner is offline. Returning customers with a previously verified link can be served offline.
- **Pending entries are phone-only.** “Waiting to sync” means the server has not acknowledged the entry. Keep the owner app/data available until sync completes; a new phone restores only acknowledged records.
- **Customer view may be stale while offline.** The app should show the last successful sync time and avoid implying it includes unseen owner changes.
- **Cash/UPI entries are manual records.** No bank verification, payment collection, refund or advance handling is promised.
- **Corrections remain visible.** A posted entry is not silently overwritten or deleted; an owner correction creates a linked record with reason.
- **Due date is not necessarily an overdue total.** The release must not show a calculated overdue amount until a deterministic payment-allocation rule is approved and tested.
- **QR can be copied.** The shop owner should confirm the person and amount on the screen before Submit. A QR image is an account lookup, not identity proof at the counter.
- **Sharing is owner-controlled.** Reminders are previewed and sent only through a chosen Android share destination. A shared PDF/CSV leaves the app under the recipient's handling.
- **Cloud capacity is finite.** During quota or service interruption, known-link owner entries may remain Pending. The app must explain that they are not yet backed up; first-time linking may be unavailable.

## 5. Known issues and changes since prior release

For the **first** actual release, “Changes since previous version” may read “Initial release.” Until that release exists, use this table as a required final-review field rather than fabricating fixes or known defects.

| ID | Severity | Affected users/flow | Symptom and safe workaround | Owner/target fix | Disclosure decision |
|---|---|---|---|---|---|
| `[ISSUE-ID]` | `[P2/P3 only for launch]` | `[FLOW]` | `[OBSERVED FACTS]` | `[OWNER/VERSION]` | `[PUBLIC/IN-APP/SUPPORT]` |

Open P0/P1 defects in balance, cross-tenant privacy, duplicate posting, outbox durability, recovery or mandatory first-release behavior block public release under the [Test Plan defect policy](TEST-PLAN.md#10-entry-exit-and-defect-policy). If a P1 feature is deliberately delayed, first approve and update BRD/PRD/SRS and the launch gate; then describe the revised scope plainly. Do not hide a missing feature under “known issue.”

## 6. Upgrade, compatibility and rollback note

For each future release, document whether old locally Pending operations can still sync after upgrade. The Worker must keep `/v1` payload and operation-ID compatibility through the approved support window, and a mobile SQLite migration must preserve unresolved outbox records. A server rollback changes Worker code but does not roll back D1 schema; the [Deployment Runbook](DEPLOYMENT-RUNBOOK.md#7-incident-triage-and-rollback-decision-tree) governs recovery. Do not promise that uninstalling/reinstalling the app restores Pending entries.

Release notes must distinguish an Android app update, a Worker-only change, and a D1 migration. A backend fix may reach users without an app-store update, but it still needs a versioned internal change record, tests and monitoring. An app-store update should include only user-visible changes that match the tested artifact.

## 7. Publication checklist and sign-off

Before posting release notes to an app store, website or users, the release owner records:

- [ ] Actual version/build, release date, supported devices and rollout channel are filled in section 1.
- [ ] Every claimed feature is included in the signed build and passed its listed test cases on the deployed Worker/D1 version.
- [ ] Pending/new-phone recovery language matches observed behavior and in-app copy.
- [ ] Manual UPI label is not described as verified payment or collection.
- [ ] Known issues were reviewed against the current defect tracker and pilot evidence; blocking P0/P1 items are absent.
- [ ] English/Hindi public and in-app wording is reviewed for debt direction and trust-critical states.
- [ ] Privacy policy, support contact, request status path and quota/outage guidance are live and accurate.
- [ ] Product, QA/security and operations approve the final text and link it to the release packet.

Publication is an external action and follows the release approval process in the [Deployment Runbook](DEPLOYMENT-RUNBOOK.md). The next document, **Monitoring & Logging**, will define how the deployed service's health, sync and quota claims are observed without collecting sensitive ledger content.


### D11 local ledger/outbox checkpoint (2 October 2026)

Local D11 implementation adds durable owner entry/outbox commits, Pending/provisional history, complete authorized cache bootstrap and an additive local schema upgrade preserving existing operations. New entries remain device-only Pending until D12 sync is implemented. This is a local implementation checkpoint, not a production-release or phone-acceptance claim. Publication, stable-key APK audit and Android airplane-mode/force-stop checks remain pending. D10 staging deployment is unchanged.

D11 delivery on 2 October 2026: approved source publication, cloud CI and [stable-key APK build](https://github.com/magan110/UdharKhataApp/actions/runs/36994390185) succeeded against `d32c30c1045b8ffa13fceeeac60291b6208c6a1d`. The exact APK audit matches the existing certificate, package and staging settings; [APK ZIP](https://github.com/magan110/UdharKhataApp/actions/runs/36994390185/artifacts/11221465345) is available for phone testing. Device acceptance is pending, and new entries remain locally Pending until D12 sync.
