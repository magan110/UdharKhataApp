# Udhaar Khata Flutter app

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../DOCUMENT-MAP.md). **Read with:** [Repository README](../README.md) · [Daily implementation plan](../docs/implementation/README.md) · [UI/UX spec](../UI-UX-DESIGN-SPEC.md) · [SRS](../SRS.md).
<!-- DOC_NAV_END -->

This directory contains the Android Flutter app. D01 established the toolchain; D02 added the welcome/loading/error shells, guarded owner/customer routes, typed API contracts, and repository interfaces. Follow the [daily implementation plan](../docs/implementation/README.md) and [actual progress](../docs/implementation/PROGRESS.md). The [project document map](../DOCUMENT-MAP.md) connects product, UI, backend, testing, and operations requirements.

From this directory, run `flutter pub get --enforce-lockfile`, `flutter analyze`, `flutter test --coverage`, and `flutter build apk --debug`. The generated iOS, web, desktop folders are not supported first-release targets. D03 adds account-isolated SQLite, atomic entry/outbox and cache/cursor adapters, plus durability and integrity tests. D04 wires Google sign-in, secure sessions, role selection and sign-out preserving Pending data; live OAuth is pending. User-facing ledger features follow later. Synthetic identities are injected only in tests.

D04 configuration after approved OAuth setup: pass public `--dart-define=API_BASE_URL=https://...` and `--dart-define=GOOGLE_SERVER_CLIENT_ID=...apps.googleusercontent.com`. The Android OAuth client must match `com.udhaarkhata.app` and its signing fingerprint; the server client ID must be the approved web audience. No OAuth secret goes into the app. With either value absent, sign-in is disabled. Production and staging use distinct configurations.

On Windows with the Pub cache on C: and project on D:, Kotlin incremental caches can fail. Build from `android/` with `gradlew.bat assembleDebug '-Pkotlin.incremental=false' '-Pkotlin.compiler.execution.strategy=in-process'`; retain normal defaults on unaffected build hosts.
