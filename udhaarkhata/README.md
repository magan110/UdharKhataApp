# Udhaar Khata Flutter app

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../DOCUMENT-MAP.md). **Read with:** [Repository README](../README.md) · [Daily implementation plan](../docs/implementation/README.md) · [UI/UX spec](../UI-UX-DESIGN-SPEC.md) · [SRS](../SRS.md).
<!-- DOC_NAV_END -->

This directory contains the Android Flutter app. D01 established the toolchain; D02 added the welcome/loading/error shells, guarded owner/customer routes, typed API contracts, and repository interfaces. Follow the [daily implementation plan](../docs/implementation/README.md) and [actual progress](../docs/implementation/PROGRESS.md). The [project document map](../DOCUMENT-MAP.md) connects product, UI, backend, testing, and operations requirements.

From this directory, run `flutter pub get --enforce-lockfile`, `flutter analyze`, `flutter test --coverage`, and `flutter build apk --debug`. The generated iOS, web, desktop folders are not supported first-release targets. D03 adds account-isolated SQLite, atomic entry/outbox and cache/cursor adapters, plus durability and integrity tests. Google sign-in and user-facing ledger features remain scheduled in later phases. Synthetic signed-in identities are injected only in tests.
