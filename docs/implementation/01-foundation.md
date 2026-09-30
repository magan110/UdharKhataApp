# Milestone 1 — foundation (D01–D05)

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../DOCUMENT-MAP.md). **Read with:** [Daily implementation plan](README.md) · [SRS](../../SRS.md) · [HLD](../../HLD.md) · [Database design](../../DATABASE-DESIGN-ERD.md) · [Security requirements](../../SECURITY-REQUIREMENTS.md).
<!-- DOC_NAV_END -->

**Exit gate:** internal Android build signs in, creates one shop, and connects to a locally tested or approved staging Worker/D1; invalid identity and cross-account calls fail. Source: [Roadmap phase 0](../../PROJECT-PLAN-ROADMAP.md#phase-0--foundation), [SRS F-001–005](../../SRS.md), [Security](../../SECURITY-REQUIREMENTS.md), [Deployment](../../DEPLOYMENT-RUNBOOK.md). A staging deployment is a separate approved external action; local evidence can complete engineering work before that approval.

## D01 — repository and reproducible tooling

**Dependencies:** none. **Files:** root `.gitignore`, `README.md`, `.github/workflows/ci.yml` when GitHub is used, `udhaarkhata/pubspec.yaml`, `udhaarkhata/android/app/build.gradle.kts`, `services/api/package.json`, `services/api/package-lock.json`, `services/api/tsconfig.json`, `services/api/wrangler.toml` or JSONC equivalent, `docs/implementation/PROGRESS.md`.

1. Inspect installed Flutter/Android SDK, Node and Git; record versions and `flutter doctor` output. Initialize a local Git repository only if requested/appropriate for the existing workspace; protect generated and secret files in `.gitignore` regardless. Keep generated Flutter platform folders for now but declare Android as the sole supported release target.
2. Replace default Android application ID with a stable, owned namespace selected before OAuth registration; set app label and minimum Android API based on target shop devices. Remove debug signing from release configuration; leave signing configuration external and unavailable until release. Document compatibility in root README.
3. Pin supported toolchain/dependency versions via Flutter lockfile, npm lockfile and Node engine. Add scripts for typecheck, lint, test and local Worker development. Add example-only environment files with names, never values or secrets.
4. Add CI jobs for Flutter analyze/test and Worker typecheck/test/audit, using no live credentials. CI may initially report skipped device tests explicitly; never report green for omitted critical checks.

**Checks:** clean dependency installation; `flutter doctor`, `flutter analyze`, `flutter test`, `npm ci`, `npm run typecheck`, `npm test`, `npm audit`; inspect release Gradle signing and secret ignores. **DoD:** reproducible local commands are documented, baseline checks run, default package/signing issues are resolved, and no secret/remote resource was created silently.

## D02 — architecture skeleton and error contracts

**Dependencies:** D01. **Files:** `udhaarkhata/lib/main.dart`, `lib/app/{app.dart,router.dart}`, `lib/core/{auth,db,network,sync}/`, `lib/features/{qr,shop,ledger,disputes,sharing,settings}/`, `services/api/src/index.ts`, `src/http/{router,errors,schemas}.ts`, `src/policy/`, `services/api/test/`, `README.md`.

1. Build Flutter bootstrap, theme, loading/error shells and owner/customer route guards without pretending sign-in works. Define repository interfaces and feature controllers so widgets do not issue SQL/HTTP directly.
2. Build Worker request pipeline: request ID, route/method dispatch, bounded JSON body, content-type validation, stable error envelope, no-store headers, safe structured telemetry. Add `/health` or equivalent that reveals no D1 or account data.
3. Define shared contract examples/test fixtures for ID, paise, timestamps, cursor and errors. Keep TypeScript and Dart models explicit; no generated cross-language magic. Establish test helpers for fake authentication and synthetic tenants.

**Checks:** app smoke/widget test; Worker request shape/404/405/invalid JSON/body-limit tests; formatter, analyzer, typecheck, lint. **DoD:** app launches into a safe unauthenticated shell, Worker has a tested stable envelope, and folders match the planned responsibility boundaries.

## D03 — cloud and device schemas

**Dependencies:** D02. **Files:** `services/api/migrations/0001_initial.sql`, later numbered migrations only; `services/api/src/db/{queries,transaction}.ts`, `services/api/test/db/*.test.ts`, `udhaarkhata/lib/core/db/{database,migrations,repositories}.dart`, `udhaarkhata/test/core/db/`, `DATABASE-DESIGN-ERD.md` if a justified schema change is needed.

1. Translate the [ERD](../../DATABASE-DESIGN-ERD.md) into D1 SQL: accounts, shops, QR identifiers, shop/customer links, ledger entries, balance/version projection, operation receipts, disputes, sessions, data requests and indexes. Retain foreign keys, uniqueness, immutable entry protection and conditional balance/payment guards. Check Cloudflare D1 transaction/batch semantics against the actual runtime before relying on a multi-statement atomic guarantee.
2. Add migration runner/documented Wrangler `--local` commands. Test fresh creation, repeat migration, representative upgrade, foreign-key check, uniqueness, overflow bounds and rollback. Never edit an applied migration; add a new one.
3. Add account-scoped local SQLite tables for cached links, entries, outbox, pull cursors and last-sync stamps. Ensure entry+outbox and data+cursor update in one local transaction. Store currency as signed integer paise within safe range; do not use floating point.

**Checks:** D1 local migration tests and `PRAGMA foreign_key_check`; local SQLite reopen/restart tests, schema version tests, malformed row constraints. **DoD:** both schemas are executable, repeatable, and tested against the ledger invariants with synthetic rows.

## D04 — Google identity and app sessions

**Dependencies:** D03. **Files:** `services/api/src/auth/{google,sessions,guards}.ts`, `src/http/auth-routes.ts`, `test/auth/*.test.ts`, `udhaarkhata/lib/core/auth/{google_auth,session_store,auth_repository}.dart`, `lib/app/router.dart`, Android manifest/OAuth configuration references, `SECURITY-REQUIREMENTS.md` for final policy.

1. Configure distinct development/staging/production Google OAuth client identifiers through non-secret configuration; registration in Google console waits for approval. Implement Google ID token verification on Worker using issuer, audience, expiry, signature and immutable `sub`. Requested role applies only on first registration; returning user cannot switch role by request.
2. Implement opaque access and rotating refresh credentials, hashed session storage, device-scoped revocation and logout. Decide and record exact lifetimes and replay behavior. Keep refresh tokens out of URLs, logs and SQLite. Add rate controls to public auth routes.
3. Integrate Android Google sign-in and secure token storage. Route by server-confirmed role; show sign-in cancelled/expired/network outcomes. On sign-out, count pending entries and preserve/lock old-account data rather than deleting it.

**Checks:** altered/wrong-audience/expired token rejection, `sub` mapping, role-conflict, refresh rotation/replay/logout, account A/B switch, release artifact secret scan. **DoD:** synthetic server tests pass and app auth UI is wired; live OAuth evidence is recorded only after approved OAuth setup, otherwise mark the live sub-gate pending.

## D05 — one shop and baseline authorization

**Dependencies:** D04. **Files:** `services/api/src/policy/{owner,customer}.ts`, `src/shop/{routes,service}.ts`, `test/policy/*.test.ts`, `udhaarkhata/lib/features/shop/{shop_setup,owner_home}.dart`, `lib/app/router.dart`.

1. Implement `POST /v1/shops`, `GET /v1/shops/{shopId}`, `GET /v1/me`. Enforce one active shop per owner and nonblank normalized name; decide and document repeat-create behavior from the API contract.
2. Add reusable policy checks: owner of current shop; active customer relationship; entry belongs to that relationship. Check on every protected route and at command commit, never trust client role/shop IDs.
3. Build owner first-run shop form, safe empty home, customer empty linked-shops home and role-aware navigation. Test two owners/two customers and a customer shared across shops.

**Checks:** route authorization matrix, ID/path tampering, duplicate shop race, Flutter role/empty-state widget tests and Android debug build. **DoD:** foundation demo works with synthetic/local infrastructure; first staging deployment and OAuth live sign-in are separately recorded as approved external gates. No phase-1 route starts before policy tests pass.
