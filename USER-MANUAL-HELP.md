# Udhaar Khata — User Manual / Help Documentation

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [PRD](PRD.md) · [UI/UX spec](UI-UX-DESIGN-SPEC.md) · [Release notes](RELEASE-NOTES.md) · [Support SOP](SUPPORT-MAINTENANCE-SOP.md).
<!-- DOC_NAV_END -->

**Version:** 1.0 draft  
**Date:** 29 September 2026  
**For:** Planned Android v1, shop owners and customers  
**Publication status:** **Draft for a future app. The screens and features described here are not yet available or tested.**  
**Source:** [PRD](PRD.md) · [SRS](SRS.md) · [UI/UX Design Specification](UI-UX-DESIGN-SPEC.md) · [Support / Maintenance SOP](SUPPORT-MAINTENANCE-SOP.md)

## 1. What the app is for

Udhaar Khata is a simple record of credit between a shop and a customer. A customer signs in with Google and shows a personal QR code. The shop owner scans it, confirms the customer, enters a credit amount and taps **Submit**. The owner can also record a payment received. Each shop/customer pair has its own dated ledger and balance. The customer can view only their own ledger in each shop.

The first release is planned for Android and Indian rupees (₹). One owner account manages one shop; a customer can be linked to several shops. The app is intended to be free to users. A QR code is for finding the customer's account; it is **not** a payment code or approval of an amount. The shop owner must check the displayed customer and amount before submitting.

**Payment labels are manual.** If the owner marks a payment “Cash” or “UPI,” the app records what the owner entered. It does not receive money or verify a bank transfer. Udhaar Khata does not automatically message customers or collect payments.

## 2. Before you start

You need an Android phone, a Google account, and internet for your first sign-in. A customer needs their own app/account to show their QR. A shop owner needs camera permission to scan; the app should ask when scanning starts. The exact supported Android versions, app-store location and support contact will be added after the app is built and tested.

Choose the correct role on the welcome screen:

- **I run a shop** — create your shop, add customers by QR, record credit/payments and manage your shop's ledgers.
- **I am a customer** — show your QR, see the shops that added you, view what you owe and report a problem with an entry.

Your role is connected to your Google account. Use the **same Google account** when you return or change phones. A different account does not show your old shop or customer history. For this first release, one account has one role; ask support if you selected the wrong role before using the app for real records.

## 3. Quick start for a shop owner

### 3.1 Set up your shop

1. Open Udhaar Khata and choose **I run a shop**.
2. Continue with Google while connected to the internet.
3. Enter a nonblank shop name and tap **Create shop**. Customers will see this shop name beside their ledger.
4. On Home, look for **Scan customer QR**, your customer list and the sync status.

The first release allows one shop per owner account. If you sign in again with the same Google account, open the existing shop instead of creating another.

### 3.2 Add a new customer and record credit

1. Ask the customer to open **My QR** on their phone and show the screen. Both phones need internet for a first-time link.
2. Tap **Scan customer QR** and allow camera access if asked. Keep the QR inside the scanner frame.
3. If the customer is new to your shop, check the displayed name with the person in front of you. Tap **Add customer**. You may set a shop nickname if the app offers it.
4. On the credit screen, check the customer's name again. Enter a positive amount in rupees, such as `500.00`. Add a note or due date only if useful.
5. Review the customer and amount, then tap **Submit** once. Scanning or tapping Back before Submit does not record credit.
6. Check the saved entry's status. **Synced** means the cloud acknowledged it. **Waiting to sync** means it is saved on this phone but has not reached the cloud yet.

Example: recording ₹500 credit increases **Customer owes you** by ₹500. The customer sees the entry only after it is Synced and their app refreshes.

### 3.3 Serve a returning customer

Ask them to show My QR and scan it. If this customer is already linked to your shop, the app opens their credit form. You can also find them from your own customer list. A previously verified link may work without internet: enter the amount and Submit, then keep the entry **Waiting to sync** until connection returns. A new, unknown QR **cannot** be added offline.

### 3.4 Record a payment received

1. Open the linked customer's ledger and choose **Payment received**.
2. Enter the amount you actually received. Choose **Cash** or **UPI** as your own record of the method.
3. Check the customer, amount and expected remaining balance, then Submit.

A payment reduces what the customer owes. If the ledger shows ₹500 owed and you record ₹200 received, the new balance is ₹300 owed. In v1, the payment amount cannot exceed the currently recorded owed amount. The app does not confirm that a UPI transfer arrived; check your real payment source separately. If an offline payment later conflicts with the cloud balance, the entry shows **Needs attention** for review rather than becoming an advance.

### 3.5 Review a ledger and correct an entry

Open **Customers**, choose the person, and read their balance and dated entries. Each row says whether it is Credit, Payment received or Correction. The owner view may include a **local provisional balance** with Waiting-to-sync entries; distinguish it from the last synced cloud balance.

If you entered a wrong amount, open the original entry and choose **Correct entry**. Enter the amount the original entry should effectively represent, or zero to cancel it, and write a reason. Review and Submit. The app adds a linked correction; it keeps the original and the correction visible to both sides after sync. For example, correcting a ₹500 credit to ₹450 reduces the owed balance by ₹50. Do not add a fake payment to hide a mistaken credit.

If a correction would make the balance negative because payments were already recorded, the app may reject it. Review the ledger and use the app's help path; do not keep retrying or create duplicate entries. Only the shop owner can post corrections. A customer can report a problem but cannot edit the owner's ledger.

### 3.6 Due dates, reminders and statements

You may add an optional due date when recording credit. A due date can appear on that entry. The app must not present an aggregate “overdue amount” until a clear rule for applying payments to dated credits has been approved and tested.

To remind a customer, open their ledger and choose **Reminder**. Review the shop, customer, balance and last-sync/provisional label in the preview. Edit or cancel if needed. The Android share menu opens only after you choose to share; the app does **not** send reminders automatically. Check the destination yourself.

To make a statement, choose the customer and date range, then **PDF** or **CSV**. The statement should show opening balance, dated credit/payment/correction effects and closing balance. Check the customer and period before sharing; a recipient can keep the file after it leaves your phone. An export must not silently mix phone-only Pending entries with cloud-acknowledged entries. The release will state whether a separately labeled local provisional export is available.

## 4. Quick start for a customer

### 4.1 Show your QR

1. Open Udhaar Khata and choose **I am a customer**.
2. Continue with Google while online for first setup.
3. Open **My QR** and show it to the shopkeeper. The name beside the code helps them confirm they selected the right person; your name, balance and Google details are **not encoded in the QR**.

After it has been issued, your QR can be displayed from the app's cache without internet. If you rotate the QR in Settings, use the newly displayed code for new shops. An old revoked code cannot add a new shop link. Existing shop links remain with your account, subject to the app's access rules.

### 4.2 See what you owe

Open **My shops**, choose a shop, then read **You owe [shop] ₹X** and the dated entries. Each shop has a separate ledger. You cannot see another customer's balance or post entries. If you are offline, you can read the last synced history on your phone; the screen should show **Last updated [date/time]**. New owner entries may not be there yet. Refresh when online to see acknowledged changes.

If an entry is wrong, open it and choose **Report a problem**. Enter a short reason and submit while online. You can follow its **Open** or **Resolved** status and any owner note. Reporting a problem does **not** change the amount owed by itself; the owner may add a visible correction if an entry needs changing. Discuss a real-world cash/UPI disagreement with the shop as well, because the app does not verify payments.

### 4.3 Stop viewing a shop or request account deletion

Use Settings/Help to request removal of your app access to a shop or deletion of your account. Follow the request status shown in the app. Removing your view does not automatically erase the shop owner's historical ledger. The exact retention, re-linking and deletion timeline will be stated in the published privacy policy before release. If you need a copy of your data or have a privacy question, use the approved in-app contact route once it is live.

## 5. Understand sync and balances

| What you see | What it means | What to do |
|---|---|---|
| **Waiting to sync** | Owner saved the entry on this phone; the cloud has not acknowledged it. Customer cannot see it yet. | Keep app data on this phone. Connect to internet and use **Retry sync** if offered. Do not create a second entry just to retry. |
| **Synced** | Cloud acknowledged the entry. Customer can see it after their app refreshes. | No action unless the amount is wrong; owner can correct visibly. |
| **Needs attention** | The cloud did not accept the entry or it requires owner review. It is not posted. | Open the entry, read the reason and use Help. Do not blindly submit another charge. |
| **Last updated [time]** | Customer is seeing a saved copy of their last cloud view. | Refresh online before treating it as current. |
| **Cloud service unavailable** | Online lookup/sync may be delayed, including by capacity limits. | Returning customers may be served locally; a new QR link waits for internet/service. Check Pending status later. |

**Protect Pending entries:** Do not uninstall the app, clear storage, reset the phone or discard it while important entries say Waiting to sync or Needs attention. These records may exist only on that phone. If you change Google accounts on the same phone, review the Pending count and follow the app's safe account-switch instructions first. A new phone can download entries that had reached **Synced**; it cannot fetch entries that never left the old phone.

## 6. Common problems and answers

| Problem | What to check or do |
|---|---|
| I cannot sign in | Check internet and Google account selection; try again. Use the same Google account as before. If an error shows a request ID, note it for support. Do not clear app data when Pending entries exist. |
| The camera will not open | Allow camera permission when asked, or enable it in Android app settings and return to Scan QR. Use the app's retry action. |
| The QR is unreadable or invalid | Increase screen brightness, hold the phones steady, use only the customer's **My QR** code, and retry. Unsupported or revoked codes need a current QR from the customer. |
| A new customer's QR says internet needed | First-time lookup and Add customer require internet. Reconnect, scan and confirm the person before entering credit. |
| I scanned the QR but no credit appears | Scanning only finds the customer. The owner must enter an amount, review it and tap Submit. |
| The owner sees a charge but the customer does not | Check whether the owner's entry is Waiting to sync or Needs attention. Customers see only acknowledged records after refreshing. Compare last sync times. |
| The balance looks wrong | Compare both apps at the same synced version/time. The owner may be seeing a provisional Pending amount. For an acknowledged wrong entry, customer can Report a problem and owner can Correct entry. Contact support for an unexplained synced mismatch. |
| A payment is rejected | Check that the amount is positive and does not exceed the current owed balance. If an offline payment is Needs attention, review the server balance before any new action. |
| My old QR stopped working | You may have rotated it. Open My QR online and show the current code. An existing shop relationship may still be found through the owner's customer list. |
| I changed phones | Sign in with the same Google account. Only Synced records restore from the cloud; phone-only Pending records from a lost old phone cannot be recovered there. |
| Export or sharing failed | Check internet for cloud statement generation, selected shop/customer and date range. A reminder opens Android's share menu only after you choose to share. Keep financial files private. |
| The app says service unavailable | Keep existing linked entries on the phone until they sync. New customer linking may be paused. Do not assume a Waiting-to-sync entry is backed up. |

## 7. Privacy, safety and help

The app should ask only for permissions it needs. Camera access is for scanning QR codes; the planned first release does not require contacts or location. Shop owners can see records for their own shop. Customers can see only their own linked shop ledgers. A QR code reveals a random lookup value, but someone can copy a QR image; the owner should confirm the person at the counter before recording credit. Keep statements and screenshots private, especially when using Android sharing.

If you need help, open **Settings → Help/Contact** when available. Provide your role, app version, approximate time, displayed sync status and request ID if shown. Do **not** send your Google sign-in token, a full QR screenshot or another person's financial record through ordinary support chat. For a wrong acknowledged entry, use the in-app dispute/correction route where possible. For privacy/data requests, use the tracked request option in Settings. The support address, hours and privacy-policy link are **not yet assigned** and must be added before public release.

## 8. Short glossary

| Term | Plain meaning |
|---|---|
| **Credit / udhaar** | Goods or services given now, with money to be paid later; increases what customer owes. |
| **Payment received** | Cash/UPI amount manually recorded by shop owner; reduces what customer owes. |
| **Balance owed** | Sum of credit, payments and corrections for one shop/customer pair. |
| **Correction** | A new visible record that changes the effective amount of an older entry without erasing it. |
| **Dispute / Report a problem** | Customer's report about an acknowledged entry; it does not change the balance itself. |
| **QR** | A code to find the customer account; it does not authorize an amount or pay money. |
| **Waiting to sync** | Saved only on owner's phone so far. |
| **Synced** | Saved and acknowledged by cloud service. |
| **Needs attention** | Not posted to cloud; owner must review the problem. |

## 9. Draft Hindi quick reference for review

The app plans English and Hindi critical flows. The following are **draft terms**, not final translations; a Hindi speaker should review clarity and debt direction before publication.

| English | Draft Hindi |
|---|---|
| Credit / udhaar | उधार |
| Payment received | भुगतान मिला |
| Waiting to sync | सिंक होना बाकी है — यह प्रविष्टि अभी केवल इस फ़ोन में है। |
| Synced | सिंक हो गया — क्लाउड ने प्रविष्टि स्वीकार कर ली है। |
| Needs attention | ध्यान दें — प्रविष्टि अभी क्लाउड में दर्ज नहीं हुई है। |
| Customer owes you ₹X | ग्राहक को आपको ₹X देने हैं। |
| You owe [shop] ₹X | आपको [दुकान] को ₹X देने हैं। |
| Internet needed to add this customer | इस ग्राहक को जोड़ने के लिए इंटरनेट चाहिए। |

Do not publish the Hindi help or app labels until reviewed by speakers and tested with TalkBack, text scaling and real shop/customer participants. The English instructions also require a final check against the implemented screen labels, supported devices, privacy policy and actual support contact.

## 10. Publication checklist

- [ ] Replace this draft status with the tested app version and supported Android versions.
- [ ] Match every button/route name above to the shipped app and remove any feature delayed by an approved scope change.
- [ ] Test owner and customer steps on release-signed devices, online and offline, in English and Hindi.
- [ ] Confirm Pending/Synced/Needs attention, new-phone recovery and UPI wording against observed behavior.
- [ ] Publish approved privacy, retention, data-request and support links; remove placeholders.
- [ ] Review Hindi text, accessibility labels and statement/reminder privacy guidance.
- [ ] Link final help from the app and store listing only after product, QA, support and privacy sign-off.

This manual is the last document in the requested planning set. Its procedures become user instructions only after the app has been implemented and verified against the [Test Cases / QA Checklist](TEST-CASES-QA-CHECKLIST.md). Until then, it is a reviewable product draft.


### D11 local ledger/outbox checkpoint (2 October 2026)

For the current D11 checkpoint, open a customer online once to save a verified ledger. In that signed-in session, you can then open the saved customer, review a credit/payment and confirm without internet. The success message says Pending; it is only on this phone. View transaction history shows the provisional balance and each entry status. A payment cannot exceed the locally known balance. Refresh from server updates acknowledged records; View confirmed server history shows cloud records separately. New D11 entries wait locally even online: automatic upload/retry is the next D12 phase and is not yet implemented. After app restart, the queue remains stored, but this checkpoint still needs online session verification before opening it; offline cold-start access is D12. Never uninstall or clear app data to recover Pending entries. Existing uncertain online requests still offer Check same credit/payment; resolve that original before adding another local entry.

D11 cache-limit recovery: an oversized uncached customer still offers View confirmed server history directly. An existing legacy credit/payment request can open Check same credit/payment after a minimal authorized customer read; complete offline bootstrap is required only for new local commands.

## D12 owner sync help (local checkpoint)

Saving a credit or manual Cash/UPI payment first stores it on this phone as Pending. Pending is not backed up to the cloud. Sync runs after saving and when the app resumes; you can also choose Sync now. Synced means the server acknowledged the original entry. Customer screens show acknowledged entries after refresh. Offline views show the last verification and complete server snapshot dates; a partial refresh does not make the whole history current.

Needs attention keeps the original amount, date, method and note for review. It is excluded from balance totals and later entries for that customer wait behind it. Review confirmed server history before recording another entry. D12 does not edit, replace or silently delete the rejected command. If access was removed, the explanation and original rejected entry remain available to its account. For a ledger above the offline cache limit, use View confirmed server history online; existing queued entries stay on the phone.

After online verification, an existing account cache may reopen offline for up to 30 days. Offline use does not extend that period. Sign in online again after expiry, clock rollback, or an uncertain session refresh. Sign-out locks the saved ledger and warns about phone-only entries. Another account cannot open it. This checkpoint is not yet delivered as a D12 APK; phone verification remains pending.
