# Udhaar Khata

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [Repository instructions](AGENTS.md) · [Daily implementation plan](docs/implementation/README.md) · [Implementation progress](docs/implementation/PROGRESS.md) · [Flutter app README](udhaarkhata/README.md).
<!-- DOC_NAV_END -->

Android-first Flutter credit ledger with a Cloudflare Worker and D1 backend. D03 schemas are tested locally and in approved staging. D04 local Google verification, rotating sessions, secure credential storage and role/sign-out UI are implemented with synthetic tests; live Google OAuth and Worker deployment remain pending. User-facing ledger features follow in later phases. See implementation progress for evidence.

Start with [the document map](DOCUMENT-MAP.md), [the implementation plan](docs/implementation/README.md), and [progress](docs/implementation/PROGRESS.md). Product and engineering requirements are cataloged in [AGENTS.md](AGENTS.md). Run `python scripts/check_docs.py` after changing Markdown links.

## Layout and toolchain

- `udhaarkhata/`: Flutter Android app. Developed with Flutter **3.47.4** and Dart **3.13.3**; `pubspec.lock` pins package resolution. Android application ID is `com.udhaarkhata.app`. Minimum Android API is **24** (Android 7.0); validate this against actual pilot devices before OAuth/store setup. Android is the only committed release platform; other generated platform folders are not supported release targets.
- `services/api/`: TypeScript Cloudflare Worker foundation. Node **24.x** and npm **11.x** were used to generate `package-lock.json`; `npm ci` is the reproducible install. Wrangler is installed locally, not globally. D1 has a local-only binding, immutable numbered migrations and Workers-runtime invariant tests.
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

`npm run db:migrate:local` applies D1 migrations locally; repeating it applies no changes. `npm run db:check:local` runs `PRAGMA foreign_key_check`. `npm run dev` starts a local Worker only. Production Android signing is intentionally not configured, so a release artifact must not be distributed from this baseline. `flutter doctor -v` currently reports unaccepted Android licenses on this workstation; the unrelated Windows Visual Studio warning does not affect the Android-only target. Accept Android licenses through the SDK tool before relying on a clean Android build in CI or release.

For D02, `GET /health` returns a minimal success envelope; valid `POST /v1/auth/google` input returns `503 FEATURE_UNAVAILABLE`; `GET /v1/me` fails closed with `401 AUTH_REQUIRED`. Shared [contract fixtures](contracts/d02-fixtures.json) are checked by Dart and TypeScript tests. Body size is bounded to 64 KiB, including streamed bytes; responses and telemetry do not reveal credentials or user data.

## Configuration safety

Use `services/api/.dev.vars.example` only as a list of future local variable names; never enter secrets in tracked files. `services/api/wrangler.jsonc` is local-only and uses a zero placeholder database ID with `remote:false`; no remote D1 database has been created. Remote environment names, IDs, OAuth clients, API URL, signing key and backup destination will be defined in later phases and require explicit approval before remote changes. Android package ID must be checked against publisher ownership and finalized before registering Google OAuth clients.
