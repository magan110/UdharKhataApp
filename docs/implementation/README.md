# Udhaar Khata — implementation plan

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../DOCUMENT-MAP.md). **Read with:** [Roadmap](../../PROJECT-PLAN-ROADMAP.md) · [SRS](../../SRS.md) · [Security requirements](../../SECURITY-REQUIREMENTS.md) · [Implementation progress](PROGRESS.md).
<!-- DOC_NAV_END -->

**Baseline:** 29 September 2026. **Mode:** one numbered phase per working day; each day ends with a reviewable checkpoint. This is an execution plan, not a claim that a full feature can always be finished in one calendar day. If a phase fails its gate, continue it the next day and do not relabel incomplete work as done.

## Repository audit and decisions

**Baseline at planning time (before D01):** The root had 26 planning Markdown documents. `udhaarkhata/` was a generated Flutter project with a single Hello World `lib/main.dart`, default Android package, debug signing for release, `flutter_lints`, and no test directory or product code. There was no Worker, D1 migration, CI, root Git repository, or `AGENTS.md`. The historical audit explains the initial task list; see [actual progress](PROGRESS.md) and the [document map](../../DOCUMENT-MAP.md) for the current state. No real credentials, remote environments, or production data were present at that baseline.

The product contract is Android-first, INR, one shop per owner, multiple shops per customer, Google sign-in for both roles, customer-presented QR, owner-posted credit/payment, D1-authoritative acknowledged ledger, device-local pending entries, English/Hindi, and a free first release subject to provider capacity. See [Scope](../../SCOPE.md), [PRD](../../PRD.md), [SRS](../../SRS.md), [SES](../../SES.md), [API](../../API-SPECIFICATION.md), [database](../../DATABASE-DESIGN-ERD.md), [security](../../SECURITY-REQUIREMENTS.md), and [test cases](../../TEST-CASES-QA-CHECKLIST.md).

### Concrete implementation defaults

These are engineering defaults for the build, not invented product promises. Validate package/platform compatibility when each phase starts and pin the selected versions in lockfiles.

| Decision | Default and rationale | Close in |
|---|---|---|
| Layout | Keep existing `udhaarkhata/` path as Flutter app; add `services/api/` for TypeScript Worker and D1 SQL migrations. Do not move generated platform folders merely to match LLD's proposed `apps/mobile/`. | D01 |
| Flutter layers | `lib/app`, `lib/core/{auth,db,network,sync}`, `lib/features/*`; repository/use-case boundary. Use `flutter_riverpod` for state, `go_router` for role-aware routes, `sqflite` for local SQLite, `flutter_secure_storage` for credentials, `google_sign_in`, `mobile_scanner`, `qr_flutter`, `http`, `intl`, and Flutter `gen-l10n`. Add PDF/share packages when needed. Prefer simple handwritten models until generated code earns its cost. | D02–D04 |
| Worker | TypeScript, Wrangler, `zod` boundary schemas, Cloudflare Workers Vitest integration, native D1 prepared statements and versioned SQL migrations. No ORM or separate server runtime. | D02–D03 |
| App session | Server-verified Google ID token (`sub`, issuer, audience, expiry, signature); short-lived opaque access credential and rotating opaque refresh credential, hashed at rest with server-side session rows. Revoke on logout; reauthenticate after uncertain refresh replay. Never use email as identity. Final lifetimes and retention must be recorded before pilot. | D04–D05 |
| Local protection | App-private per-account SQLite; credentials in Android secure storage; disable Android backup/device transfer for ledger/outbox until reviewed. Account switch locks old database. Decide on SQLCipher after device/security review, document residual risk. | D04, D12 |
| API | `/v1`, JSON camelCase, integer paise, `X-Request-Id`, no-store financial responses. `POST /v1/customer-qr/resolve` keeps QR lookup IDs out of URL paths. | D03 onward |
| Conflict handling | D1 is authoritative after acknowledgement. Local writes get UUID operation IDs before save; retry same body/ID. Rejected local operations remain visible as Needs attention. Never silently merge or discard money entries. | D09–D13 |
| Due amounts | Allocate payments to oldest unpaid credit by due date then stable server order; do not display overdue total until verified against corrections and partial payments. | D16 |
| Constraints | Use central versioned constants for amount, note, QR, page and export limits; choose conservative pilot defaults from user research and abuse testing, then mirror in mobile validation and API. No unlimited inputs. | D08, D18 |

## Daily sequence and dependency gates

| Day/phase | Milestone | Deliverable | Prerequisite |
|---|---|---|---|
| D01 | Foundation | Repository/tooling baseline, project IDs and CI skeleton | none |
| D02 | Foundation | App and Worker architecture skeleton | D01 |
| D03 | Foundation | D1/local schemas, migrations, invariants | D02 |
| D04 | Foundation | Google identity, sessions, account isolation | D03 |
| D05 | Foundation | Shop setup, role routing, authorization gate | D04 |
| D06 | Online ledger | Customer QR issue/display/rotate | D05 |
| D07 | Online ledger | Owner scan, resolve, confirm and link | D06 |
| D08 | Online ledger | Credit write and exact balances | D07 |
| D09 | Online ledger | Manual Cash/UPI payment and idempotent retry | D08 |
| D10 | Online ledger | Owner/customer history, pagination and online gate | D09 |
| D11 | Offline/trust | Local ledger/outbox transaction | D10 |
| D12 | Offline/trust | Sync push/pull and account switching | D11 |
| D13 | Offline/trust | Offline QR, failures, restore boundary | D12 |
| D14 | Offline/trust | Immutable corrections | D13 |
| D15 | Offline/trust | Disputes and trust gate | D14 |
| D16 | Release completeness | Due dates, payment allocation | D15 |
| D17 | Release completeness | Reminder preview, PDF/CSV | D16 |
| D18 | Release completeness | English/Hindi, accessibility, help | D17 |
| D19 | Release completeness | Data controls, retention, backup/restore | D18 |
| D20 | Release completeness | Observability, quotas, release candidate | D19 |
| D21 | Pilot/release | Full synthetic regression and security review | D20 |
| D22 | Pilot/release | Private test and usability repair | D21 |
| D23 | Pilot/release | Real-shop pilot after approval and readiness | D22 |
| D24 | Pilot/release | Launch decision packet and release preparation | D23 |

Open each milestone file for **exact sequence, files, checks, and Definition of Done**: [D01–D05 foundation](01-foundation.md), [D06–D10 online ledger](02-online-ledger.md), [D11–D15 offline and trust](03-offline-trust.md), [D16–D20 release completeness](04-release-completeness.md), [D21–D24 pilot and launch](05-pilot-release.md). Record actual progress in [PROGRESS](PROGRESS.md). The older [roadmap](../../PROJECT-PLAN-ROADMAP.md) gives staffing and elapsed-week estimates; these daily checkpoints are a finer dependency sequence, not a replacement for its effort estimate. Research/prototype with owners and customers should run alongside D01–D05; if QR onboarding fails, revise scope before D06.

## Rules shared by every phase

1. Read `AGENTS.md`, this index, selected daily phase, and linked source requirements. Check `PROGRESS.md` for unresolved blockers.
2. Implement the phase's numbered steps in order. Add tests for money, authorization, data integrity, sync and error handling; avoid tests that only restate UI implementation.
3. Run the phase checks plus affected prior regression. Capture command/result and screenshots or sanitized request traces when the phase asks for them. Never use real account/ledger data in logs or test fixtures.
4. Update API, database, SRS, PRD and security documents together when a behavior or contract changes. Record an ADR or decision in `PROGRESS.md` for meaningful deviations.
5. A failed gate blocks advancement. Complete local prep before asking for external approval. Cloudflare/Google console changes, staging/production deployment, store distribution, real-user recruitment and real-user data require explicit user approval under the repository supplement.

## Verification baseline and source references

Flutter: `flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and Android debug build where the toolchain is available. Worker: `npm ci`, `npm run typecheck`, `npm test`, `npm run lint` (once defined), `npm audit --audit-level=high`; migrations are applied/tested **locally** first. CI uses locked dependencies and no production secrets. Follow [Test Plan](../../TEST-PLAN.md), [QA cases](../../TEST-CASES-QA-CHECKLIST.md), [Coding Standards](../../CODING-STANDARDS-DEVELOPMENT-GUIDELINES.md), and [Deployment Runbook](../../DEPLOYMENT-RUNBOOK.md).

The selected tooling aligns with [Flutter architecture](https://docs.flutter.dev/app-architecture/guide), [Flutter offline-first guidance](https://docs.flutter.dev/app-architecture/design-patterns/offline-first), [Cloudflare D1 migrations](https://developers.cloudflare.com/d1/reference/migrations/), and [Cloudflare Workers Vitest integration](https://developers.cloudflare.com/workers/testing/vitest-integration/write-your-first-test/). Recheck official documentation and dependency compatibility at implementation time; this plan deliberately avoids claiming immutable package versions or free-tier quotas.
