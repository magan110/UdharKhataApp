# Udhaar Khata

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [Repository instructions](AGENTS.md) · [Daily implementation plan](docs/implementation/README.md) · [Implementation progress](docs/implementation/PROGRESS.md) · [Flutter app README](udhaarkhata/README.md).
<!-- DOC_NAV_END -->

Android-first Flutter credit ledger with a Cloudflare Worker scaffold and planned D1 backend. **Current implementation:** D01 and D02 complete. The app opens a welcome screen with guarded owner/customer shells, loading/retry states, and repository boundaries. The local Worker implements request IDs, validation, safe errors, and health. Google sign-in and the ledger are scheduled for later phases; the API is not deployed.

Start with [the document map](DOCUMENT-MAP.md), [the implementation plan](docs/implementation/README.md), and [progress](docs/implementation/PROGRESS.md). Product and engineering requirements are cataloged in [AGENTS.md](AGENTS.md). Run `python scripts/check_docs.py` after changing Markdown links.

## Layout and toolchain

- `udhaarkhata/`: Flutter Android app. Developed with Flutter **3.47.4** and Dart **3.13.3**; `pubspec.lock` pins package resolution. Android application ID is `com.udhaarkhata.app`. Minimum Android API is **24** (Android 7.0); validate this against actual pilot devices before OAuth/store setup. Android is the only committed release platform; other generated platform folders are not supported release targets.
- `services/api/`: TypeScript Cloudflare Worker foundation. Node **24.x** and npm **11.x** were used to generate `package-lock.json`; `npm ci` is the reproducible install. Wrangler is installed locally, not globally. Cloudflare D1 configuration and migrations arrive in D03.
- `.github/workflows/ci.yml`: read-only build checks with no Cloudflare/Google credentials or deployment steps.

## Local checks

```powershell
Set-Location udhaarkhata
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
python ../scripts/check_coverage.py coverage/lcov.info
flutter build apk --debug

Set-Location ../services/api
npm ci
npm run typecheck
npm run lint
npm test
npm run test:coverage
npm run build
npm audit --audit-level=high
```

`npm run dev` starts a local Worker only. Production Android signing is intentionally not configured, so a release artifact must not be distributed from this baseline. `flutter doctor -v` currently reports unaccepted Android licenses on this workstation; the unrelated Windows Visual Studio warning does not affect the Android-only target. Accept Android licenses through the SDK tool before relying on a clean Android build in CI or release.

For D02, `GET /health` returns a minimal success envelope; valid `POST /v1/auth/google` input returns `503 FEATURE_UNAVAILABLE`; `GET /v1/me` fails closed with `401 AUTH_REQUIRED`. Shared [contract fixtures](contracts/d02-fixtures.json) are checked by Dart and TypeScript tests. Body size is bounded to 64 KiB, including streamed bytes; responses and telemetry do not reveal credentials or user data.

## Configuration safety

Use `services/api/.dev.vars.example` only as a list of future local variable names; never enter secrets in tracked files. `services/api/wrangler.jsonc` is local-only and has no remote D1 binding. Remote environment names, IDs, OAuth clients, API URL, signing key and backup destination will be defined in later phases and require explicit approval before remote changes. Android package ID must be checked against publisher ownership and finalized before registering Google OAuth clients.
