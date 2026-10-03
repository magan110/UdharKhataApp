# Udhaar Khata repository instructions

<!-- DOC_NAV_START -->
> **Document map:** [Document map](DOCUMENT-MAP.md). **Read with:** [Scope](SCOPE.md) · [SRS](SRS.md) · [PRD](PRD.md) · [Daily implementation plan](docs/implementation/README.md).
<!-- DOC_NAV_END -->

Read [DOCUMENT-MAP.md](DOCUMENT-MAP.md) and [docs/implementation/README.md](docs/implementation/README.md) at the start of every implementation task. The map connects all authored project documents; the implementation index identifies the current daily phase, prerequisites, source documents, file ownership, checks, and Definition of Done. Read the selected daily phase in full before editing code. Do not skip phase prerequisites or claim a phase complete without its evidence.

The existing product and engineering documents are the source of truth for behavior and constraints. Use this precedence when documents disagree: `SCOPE.md` (release boundary), `SRS.md` and `PRD.md` (testable behavior), `SECURITY-REQUIREMENTS.md` (security), `API-SPECIFICATION.md` and `DATABASE-DESIGN-ERD.md` (wire/data contracts), `HLD.md`, `LLD.md`, and `SES.md` (design), then the daily implementation plan (execution order). A newer explicit user instruction supersedes these files. Record any resolved conflict in the phase evidence and update affected source documents together.

## Project document catalog

All documents below are important project references. Before changing a feature, read the selected daily phase and **all catalog documents relevant to that feature**; for cross-cutting changes, read across categories. Do not rely on the daily plan alone to infer requirements. Keep affected documents aligned with implemented behavior and tests.

| Area | Source documents |
|---|---|
| Vision, business and market | [Product Vision](PRODUCT-VISION.md), [BRD](BRD.md), [Market / Competitor Research](MARKET-COMPETITOR-RESEARCH.md) |
| Product scope and users | [Scope](SCOPE.md), [PRD](PRD.md), [User Personas](USER-PERSONAS.md), [User Journey / User Flow](USER-JOURNEY-USER-FLOW.md), [Use Cases / User Stories](USE-CASES-USER-STORIES.md) |
| D13–D21 delivery design | [Candidate design](docs/superpowers/specs/2026-10-02-d13-d21-design.md), [implementation plan](docs/superpowers/plans/2026-10-02-d13-d21.md), [operations](docs/ops/private-test-operations.md), [D21 evidence](docs/verification/d21-evidence.md) |
| D12 architectural design | [D12 sync design](docs/superpowers/specs/2026-10-02-d12-sync-design.md) (approved specification) and [implementation plan](docs/superpowers/plans/2026-10-02-d12-sync.md) (approved Native execution) |
| Requirements and delivery | [SRS](SRS.md), [SES](SES.md), [Project Plan / Roadmap](PROJECT-PLAN-ROADMAP.md), [Implementation Plan](docs/implementation/README.md), [Progress](docs/implementation/PROGRESS.md) |
| Architecture, data and API | [HLD](HLD.md), [LLD](LLD.md), [Database Design / ERD](DATABASE-DESIGN-ERD.md), [API Specification](API-SPECIFICATION.md) |
| UX01 dedicated redesign | [UX01 phase](docs/implementation/06-ui-ux-redesign.md), [dedicated UI/UX agent brief](docs/agents/ui-ux-redesign-agent.md) |
| User interface and help | [Wireframes](WIREFRAMES.md), [UI/UX Design Spec](UI-UX-DESIGN-SPEC.md), [User Manual / Help](USER-MANUAL-HELP.md) |
| Engineering quality and security | [Coding Standards / Development Guidelines](CODING-STANDARDS-DEVELOPMENT-GUIDELINES.md), [Security Requirements](SECURITY-REQUIREMENTS.md), [Test Plan](TEST-PLAN.md), [Test Cases / QA Checklist](TEST-CASES-QA-CHECKLIST.md) |
| Operations and release | [Deployment Runbook](DEPLOYMENT-RUNBOOK.md), [Monitoring / Logging](MONITORING-LOGGING.md), [Support / Maintenance SOP](SUPPORT-MAINTENANCE-SOP.md), [Release Notes](RELEASE-NOTES.md) |

The catalog is complete for the current root documentation set. When a new governing document is added, update this catalog and the implementation index. Draft or future-state statements in documents such as the user manual and release notes are not evidence that the feature exists; verify against code and tests.

After adding or changing Markdown links, run `python scripts/check_docs.py` and `python scripts/update_doc_navigation.py --check`. If a new Markdown file is added, register its purpose and related documents in `DOCUMENT-MAP.md` and `scripts/update_doc_navigation.py`, then run the navigation updater and link checker. Generated platform asset notes remain in the map for complete file coverage but do not govern the product.

The app is Flutter Android in `udhaarkhata/`; the planned Cloudflare Worker and D1 code goes in `services/api/`. Use integer paise, immutable posted ledger entries, server-side authorization, stable operation IDs, and a durable account-isolated offline outbox. A customer QR is a lookup ID, never payment authorization. Pending device entries are not cloud-backed up. Preserve those invariants in code, tests, UI text, and operations.

At the end of each daily phase, run the checks in that phase and update `docs/implementation/PROGRESS.md` with the date, evidence, unresolved issues, and next phase. Keep unchecked items unchecked if work is incomplete. Local coding, tests, and drafting are authorized; obtain explicit user approval before changing remote Cloudflare/Google resources, pushing, deploying, publishing, or using real customer data. Do not put credentials or real financial data in the repository.

The user-provided ECC Codex supplement also applies. If a repository `docs/CODEX-NAVIGATION-GUIDE.md` is later added, read it after this file before navigating or preparing PRs. It is absent as of this plan's creation.
