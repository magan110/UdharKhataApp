# Udhaar Khata Flutter app

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../DOCUMENT-MAP.md). **Read with:** [Repository README](../README.md) · [Daily implementation plan](../docs/implementation/README.md) · [UI/UX spec](../UI-UX-DESIGN-SPEC.md) · [SRS](../SRS.md).
<!-- DOC_NAV_END -->

This directory contains the Android Flutter app. D01 established the toolchain; D02 added the welcome/loading/error shells, guarded owner/customer routes, typed API contracts, and repository interfaces. Follow the [daily implementation plan](../docs/implementation/README.md) and [actual progress](../docs/implementation/PROGRESS.md). The [project document map](../DOCUMENT-MAP.md) connects product, UI, backend, testing, and operations requirements.

From this directory, run `flutter pub get --enforce-lockfile`, `flutter analyze`, `flutter test --coverage`, and `flutter build apk --debug`. The generated iOS, web, desktop folders are not supported first-release targets. D03 adds account-isolated SQLite, atomic entry/outbox and cache/cursor adapters, plus durability and integrity tests. D04 wires Google sign-in, secure sessions, role selection and sign-out preserving Pending data; live OAuth is pending. User-facing ledger features follow later. Synthetic identities are injected only in tests.

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
