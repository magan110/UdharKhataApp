# Milestone 2 — online ledger (D06–D10)

<!-- DOC_NAV_START -->
> **Document map:** [Document map](../../DOCUMENT-MAP.md). **Read with:** [Daily implementation plan](README.md) · [PRD](../../PRD.md) · [API specification](../../API-SPECIFICATION.md) · [Database design](../../DATABASE-DESIGN-ERD.md) · [UI/UX spec](../../UI-UX-DESIGN-SPEC.md).
<!-- DOC_NAV_END -->

**Exit gate:** an online new customer is linked once; owner posts ₹500 credit and ₹200 payment; owner/customer acknowledged views show ₹300; retry produces one effect. Source: [Roadmap phase 1](../../PROJECT-PLAN-ROADMAP.md#phase-1--online-ledger), [API](../../API-SPECIFICATION.md), [SRS F-006–019 and F-022](../../SRS.md), [UI spec](../../UI-UX-DESIGN-SPEC.md).

## D06 — customer QR identity

**Dependencies:** D05. **Files:** `services/api/src/qr/{routes,service}.ts`, `test/qr/*.test.ts`, `udhaarkhata/lib/features/qr/{qr_model,customer_qr_page}.dart`, `lib/core/db/qr_repository.dart`, `lib/app/router.dart`.

1. Generate a cryptographically random public QR ID of at least 128 bits at customer registration. Store only current active mapping and rotation history needed to reject revoked IDs. Encode exactly `udhaar://customer/v1/{publicId}` (or update API/SES together if format changes); never put name, Google ID, token, balance or notes in QR.
2. Implement own-QR read and rotate API. Rotation is online and revokes old ID for new links while existing links remain by internal customer ID. Rate-limit rotation and avoid public ID in route/path logs.
3. Render QR and accessible text explanation on customer app, cache the active QR for offline display, and distinguish cached/stale state.

**Checks:** decode QR payload, entropy/uniqueness, rotation old/new behavior, offline display, unauthorized role rejection, log inspection. **DoD:** customer can present a safe QR online/offline after registration; rotation works online and old ID cannot establish a new link.

## D07 — owner scan, resolve and link

**Dependencies:** D06. **Files:** `services/api/src/qr/resolve.ts`, `src/ledger/link.ts`, `src/http/qr-routes.ts`, `test/qr/link*.test.ts`, `udhaarkhata/lib/features/qr/{scanner_page,resolve_controller,link_confirm_page}.dart`, `lib/features/shop/customer_list.dart`, Android camera manifest entry.

1. Ask camera permission only on scan. Parse only supported scheme/version and bounded payload; show specific invalid, unsupported, denied and revoked states. Do not open QR content as an arbitrary URL.
2. Call `POST /v1/customer-qr/resolve` with shop ID and public QR ID. Verify owner/shop before minimal customer display response. Show identity and **Add customer** for new link; existing link opens ledger. Scanning alone changes no ledger/link.
3. On explicit confirmation, call `POST /v1/shops/{shopId}/customers` with stable operation ID and unique `(shop,customer)` constraint. Recheck QR active and ownership at commit. Retry same body/ID returns same link; changed body/ID conflicts; concurrent different IDs still create one link.

**Checks:** first/repeat/concurrent scans, copied/invalid/revoked QR, account/shop tampering, permission denial, no-link-before-confirm, link list refresh. **DoD:** new and returning online customer flow works, with one link and no financial side effect from scan.

## D08 — credit posting and balances

**Dependencies:** D07. **Files:** `services/api/src/ledger/{commands,balance,queries}.ts`, `src/http/ledger-routes.ts`, `test/ledger/credit*.test.ts`, `udhaarkhata/lib/features/ledger/{money,credit_form,entry_model,ledger_repository}.dart`, `lib/features/shop/owner_home.dart`, central validation constants in both apps.

1. Choose documented pilot caps for positive entry amount, note length, body size and page size; validate both clients, but Worker is authoritative. Parse rupee input to integer paise without float; reject zero/negative/overflow/extra decimal places.
2. Implement owner credit command with UUID operation ID, canonical request hash, active link/ownership check, immutable entry, sequence/version and balance projection in an atomic D1 operation. Same ID/body replays result; same ID/different body returns conflict.
3. Build customer identity + amount review, explicit **Customer owes you** direction, submit/duplicate-tap handling, and owner balance/list display. Ensure visible state says acknowledged only after server receipt during this online phase.

**Checks:** ₹500 credit, boundary amounts, concurrent duplicate requests, rollback on injected failure, independent `SUM(effect)` reconciliation, unauthorized writes. **DoD:** a valid credit appears exactly once in authoritative history and balance; invalid input changes nothing.

## D09 — payment and retry integrity

**Dependencies:** D08. **Files:** `services/api/src/ledger/{payment,idempotency}.ts`, `test/ledger/payment*.test.ts`, `udhaarkhata/lib/features/ledger/{payment_form,post_controller}.dart`, API examples if response details change.

1. Add manually recorded Cash/UPI payment, positive paise only; do not imply bank verification. At D1 commit, reject payment larger than current authoritative balance using an atomic guard; no negative balance/advance in v1.
2. Use the same idempotency receipt contract as credit. Preserve operation identity across timeout/lost response and return original result on same-hash retry. A second tap after a successful command must not create another operation.
3. Build payment preview with customer, amount, method and **received** wording. Show `BALANCE_CONFLICT` with current authorized balance and a correction path, never silently adjust amount.

**Checks:** ₹500→₹200→₹300, full payment, zero/overpay, two concurrent payments against one balance, lost-response retry, wrong-shop write. **DoD:** payment cannot overdraw or duplicate; owner and customer server views reconcile.

## D10 — read models and online journey gate

**Dependencies:** D09. **Files:** `services/api/src/ledger/read-routes.ts`, `src/http/cursors.ts`, `test/ledger/reads*.test.ts`, `udhaarkhata/lib/features/{shop,ledger}/` list/detail/history pages, `lib/core/network/api_client.dart`, widget/integration tests.

1. Implement scoped owner customer list, per-link ledger/balance, customer own-shop list and own ledger. Derive customer identity from session, never a supplied customer ID. Add bounded pagination with opaque route/scope-bound cursor and stable server-sequence order.
2. Build owner home totals, customer list, dated ledger and customer linked-shop/history screens. Show loading, empty, network, stale and permission-loss states; no local pending state yet unless clearly separate.
3. Run complete synthetic online journey across two owners and customers, including shared customer across two shops. Audit API responses for leaks and check balance from independent entry replay.

**Checks:** API contract tests, cursor tampering and paging, cross-tenant reads, Flutter widget flows, Android device/emulator journey, ₹300 scenario. **DoD:** phase-1 gate evidence shows correct screens, balance and retry invariants; failures are fixed before offline work begins.
