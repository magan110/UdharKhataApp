# Udhaar Khata Flutter app

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../DOCUMENT-MAP.md). **Read with:** [Repository README](../README.md) · [Daily implementation plan](../docs/implementation/README.md) · [UI/UX spec](../UI-UX-DESIGN-SPEC.md) · [SRS](../SRS.md).
<!-- DOC_NAV_END -->

This directory contains the Android Flutter app. D01 established the toolchain; D02 added the welcome/loading/error shells, guarded owner/customer routes, typed API contracts, and repository interfaces. Follow the [daily implementation plan](../docs/implementation/README.md) and [actual progress](../docs/implementation/PROGRESS.md). The [project document map](../DOCUMENT-MAP.md) connects product, UI, backend, testing, and operations requirements.

From this directory, run `flutter pub get --enforce-lockfile`, `flutter analyze`, `flutter test --coverage`, and `flutter build apk --debug`. The generated iOS, web, desktop folders are not supported first-release targets. D03 adds account-isolated SQLite, atomic entry/outbox and cache/cursor adapters, plus durability and integrity tests. D04 wires Google sign-in, secure sessions, role selection and sign-out preserving Pending data; live OAuth is pending. D06 adds customer QR display/rotation; D07 adds owner scanning, explicit customer linking and a bounded customer list. Credit/payment/history follow in D08-D10. Synthetic identities are injected only in tests.

D04 configuration after approved OAuth setup: pass public `--dart-define=API_BASE_URL=https://...` and `--dart-define=GOOGLE_SERVER_CLIENT_ID=...apps.googleusercontent.com`. The Android OAuth client must match `com.udhaarkhata.app` and its signing fingerprint; the server client ID must be the approved web audience. No OAuth secret goes into the app. With either value absent, sign-in is disabled. Production and staging use distinct configurations.

On Windows with the Pub cache on C: and project on D:, Kotlin incremental caches can fail. Build from `android/` with `gradlew.bat assembleDebug '-Pkotlin.incremental=false' '-Pkotlin.compiler.execution.strategy=in-process'`; retain normal defaults on unaffected build hosts.

## Cloud staging debug APKs

Run the manual `Build downloadable Android APK` workflow. It passes the public staging API URL and Google web client ID as `--dart-define` values. Add the repository Actions secret `ANDROID_DEBUG_KEYSTORE_B64` once, using the standard Android debug keystore from the machine whose APK already signs in successfully. This keeps the Android signing identity stable across fresh cloud runners. The workflow refuses to build when the secret is missing or malformed; it never silently creates another key.

For example, on the working Windows build machine with GitHub CLI already authenticated, upload the existing key directly through standard input:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\.android\debug.keystore")) | gh secret set ANDROID_DEBUG_KEYSTORE_B64 --repo magan110/UdharKhataApp
```

Keep the keystore, passwords and access tokens out of Git, chat, logs and downloadable artifacts. No Google client secret is needed. The runner restores the key into a temporary `ANDROID_USER_HOME`, uses Android's existing debug signing configuration and removes the temporary key after the build. Production signing remains a separate configuration.

Each downloadable ZIP includes the exact APK and `apk-audit.json`. The build runs `apksigner verify --print-certs` on that APK, verifies `com.udhaarkhata.app` with `aapt`, checks both staging define values in its debug kernel and records its SHA-1 and APK SHA-256. The required `expected_signing_sha1` defaults to the verified certificate `3C:CE:D2:62:9B:40:A7:5F:ED:A4:DB:DA:AB:21:E3:57:96:9F:16:C6` and rejects an APK signed with a different certificate. The `Inspect Android APK signing` workflow can also inspect an APK artifact from a previous build run without rebuilding it.

In Google project `udhaar-khata-staging-510306`, the Android OAuth client must identify package `com.udhaarkhata.app` and the exact APK certificate SHA-1 reported by this audit. Keep the existing web client ID `1098240805044-90hnifajs9hvtvcive1d65r3q2cqnu03.apps.googleusercontent.com` as the app's server client ID. If the working local key is reused and its Android client is already registered, another client is unnecessary. Google or Cloudflare resource changes require separate approval.

The Android Google sign-in plugin documents that configuration errors can be reported as `canceled` after account selection. That message does not confirm user cancellation or prove a certificate mismatch. Compare the exact APK's fingerprint with the registered Android client, then test sign-in, sign-out and both roles on the phone. Certificate/build verification alone is not a successful live Google sign-in test.


D07 uses pinned `mobile_scanner` 7.4.2 with bundled Android ML Kit (available without a first-use model download). Camera permission is requested when opening Scan customer QR. Permission denial offers retry and Android app settings. Unknown customer lookup/linking needs internet; scans never open arbitrary URLs or post financial entries. Confirmed uncertain links are recovered from account/shop-specific Android secure storage using the original request ID and body. No credentials are copied into these records. Full owner offline cache and sync remain later phases.

Customer My shops reads the signed-in customer’s active links from `/v1/me`, with loading, empty and retry states. Reopening the tab, app resume, pull-to-refresh and Refresh shops request a fresh profile. The existing first-100 limit is stated when there are more links. This list shows shop names only; balances and history remain D08–D10.

### D08 online credit implementation contract (2026-10-01)

Approved pilot limits v1: positive credit ₹0.01–₹1,00,000.00 (1–10,000,000 integer paise), optional trimmed note up to 500 UTF-16 code units, valid optional YYYY-MM-DD due date, financial JSON body at most 4,096 bytes, and existing first-100 list ceiling. General JSON/auth bodies retain the 65,536-byte ceiling. The Worker validates strict credit fields and canonical UUID v4 operation identity; unknown/forged effect fields and payment/correction variants are rejected in D08. A first online command accepts device occurrence time from 24 hours before server time to 5 minutes ahead. Receipt replay precedes this mutable clock check. Payments, corrections, full history/pagination and offline local ledger remain their later phases.

The owner opens a linked customer, enters amount/note/date, reviews customer identity and the explicit Customer owes you direction, then confirms. Review has no financial effect. The app durably saves an account/shop/link-specific command before POST and never generates a replacement ID after uncertainty. Reopening the form recovers that body with Check same credit; a response must match shop, link, type, amount/effect, note/date, occurrence time and sequence before acknowledgement. Unverified responses, storage failures, auth/network failure and rejected requests retain the saved record for recovery; it is not silently discarded. This online recovery record is not the D11 offline ledger/outbox, and does not provisionally change the visible balance.

The Worker uses the existing immutable ledger triggers and atomic entry-plus-receipt batch; live authorization is rechecked at commit and replay requires current access. Receipt retries return the original committed balance/version even after later entries, explicitly labeled as the balance when this credit was recorded. Owner link/list reads refresh the current balance. Customer My shops receives its own active link balances/versions from the same profile query and can refresh them. New minimal balance reads authorize the entire current snapshot in one SQL query; no history page or aggregate overdue total is inferred. No new migration is needed.


## D11 local ledger/outbox checkpoint (2 October 2026)

D11 adds an owner device ledger on the existing account-private SQLite database. Opening a customer online first caches a complete authorized history snapshot only after all pages reconcile by entry sum, count and server high-water. Later opens use that dated local snapshot; explicit Refresh from server fetches a new one. Unknown links need internet. Automatic bootstrap is capped at 10,000 acknowledged entries; larger ledgers retain the paginated confirmed-server-history view.

Owner credit/payment confirmation creates a UUID once and atomically saves the immutable provisional entry, canonical outbox payload, account/shop-bound local integrity hash and balance effect before reporting success. No new-command HTTP is issued in D11, even online. Synced balance is reconstructed from acknowledged entries; provisional balance adds Pending effects and excludes Needs attention. Payments cannot make the known local balance negative. Pending is only on this device and is not cloud-backed up; customer views remain acknowledged-only.

Unresolved D08/D09 secure-storage commands retain their original Check same credit/payment recovery path and block new local replacements until resolved. General serial push/pull, server reconciliation, permanent-rejection handling and offline cold-start session restoration remain D12; offline QR lookup and replacement-phone recovery drills remain D13. D11 makes no server/API, Google configuration or signing-key change.
