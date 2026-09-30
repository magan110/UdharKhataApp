# Udhaar Khata — project document map

This is the navigation hub for every Markdown file currently in the repository. Start with [AGENTS.md](AGENTS.md) for source-of-truth precedence and work rules, then use the paths below to read the documents relevant to a task. Each file links back here and directly to its closest companions. The generated iOS launch-image README is an asset note, not a product specification.

**Current implementation:** [Progress](docs/implementation/PROGRESS.md) records what exists. Many requirements and user-help pages describe a planned release; they are not proof that the feature is coded. The [daily plan](docs/implementation/README.md) defines implementation order and phase gates.

## Choose a reading path

| Task | Read in this order |
|---|---|
| Understand the product and its evidence | [Vision](PRODUCT-VISION.md) → [Market research](MARKET-COMPETITOR-RESEARCH.md) → [BRD](BRD.md) → [Scope](SCOPE.md) → [PRD](PRD.md) |
| Build a user journey or screen | [Personas](USER-PERSONAS.md) → [Journeys](USER-JOURNEY-USER-FLOW.md) → [Use cases](USE-CASES-USER-STORIES.md) → [PRD](PRD.md) → [SRS](SRS.md) → [Wireframes](WIREFRAMES.md) → [UI/UX spec](UI-UX-DESIGN-SPEC.md) |
| Change backend, data, or API | [SRS](SRS.md) → [SES](SES.md) → [HLD](HLD.md) → [LLD](LLD.md) → [Database design](DATABASE-DESIGN-ERD.md) → [API contract](API-SPECIFICATION.md) → [Security](SECURITY-REQUIREMENTS.md) |
| Implement a daily phase | [Roadmap](PROJECT-PLAN-ROADMAP.md) → [Daily plan](docs/implementation/README.md) → selected phase file → [Progress](docs/implementation/PROGRESS.md) → relevant specifications above |
| Verify or release | [Test plan](TEST-PLAN.md) → [QA cases](TEST-CASES-QA-CHECKLIST.md) → [Security](SECURITY-REQUIREMENTS.md) → [Deployment](DEPLOYMENT-RUNBOOK.md) → [Monitoring](MONITORING-LOGGING.md) → [Support](SUPPORT-MAINTENANCE-SOP.md) → [Release notes](RELEASE-NOTES.md) |

## Complete document catalog

| Document | Purpose and closest handoff |
|---|---|
| [Product Vision](PRODUCT-VISION.md) | Intended outcome; feeds market validation, BRD, and scope. |
| [Market / Competitor Research](MARKET-COMPETITOR-RESEARCH.md) | Evidence and limits behind product assumptions; feeds vision, BRD, and pilot. |
| [BRD](BRD.md) | Business goals and rules; feeds scope, PRD, and roadmap. |
| [Scope](SCOPE.md) | First-release boundary; constrains PRD, SRS, and roadmap. |
| [PRD](PRD.md) | Product behavior and priorities; feeds journeys, UI design, SRS, and tests. |
| [User Personas](USER-PERSONAS.md) | Owner/customer contexts; feeds journeys and UI review. |
| [User Journey / User Flow](USER-JOURNEY-USER-FLOW.md) | End-to-end flow; feeds use cases, wireframes, and tests. |
| [Use Cases / User Stories](USE-CASES-USER-STORIES.md) | Actor actions and acceptance scenarios; feeds SRS, wireframes, and QA. |
| [Wireframes](WIREFRAMES.md) | Planned screen structure; pairs with journeys and UI/UX specification. |
| [UI/UX Design Spec](UI-UX-DESIGN-SPEC.md) | Interaction, states, accessibility, and wording; pairs with PRD and wireframes. |
| [SRS](SRS.md) | Testable functional, data, and nonfunctional requirements; governs SES, design, and tests. |
| [SES](SES.md) | Engineering specification; connects requirements to HLD, LLD, data, and API. |
| [HLD](HLD.md) | Architecture and trust boundaries; leads to LLD and security review. |
| [LLD](LLD.md) | Modules and algorithms; leads to database, API, and implementation. |
| [Database Design / ERD](DATABASE-DESIGN-ERD.md) | D1/local schema and ledger invariants; pairs with API and security. |
| [API Specification](API-SPECIFICATION.md) | Wire contract; pairs with database, LLD, and test cases. |
| [Security Requirements](SECURITY-REQUIREMENTS.md) | Threats and release controls; constrains code, tests, deployment, and operations. |
| [Coding Standards / Development Guidelines](CODING-STANDARDS-DEVELOPMENT-GUIDELINES.md) | Implementation and review rules; pairs with LLD, security, and test plan. |
| [Project Plan / Roadmap](PROJECT-PLAN-ROADMAP.md) | Milestones, dependencies, and risks; the daily plan refines its phases. |
| [Test Plan](TEST-PLAN.md) | Test levels and gates; drives QA cases and release evidence. |
| [Test Cases / QA Checklist](TEST-CASES-QA-CHECKLIST.md) | Executable scenarios; traces SRS and security requirements. |
| [Deployment Runbook](DEPLOYMENT-RUNBOOK.md) | Environment, migration, release, and restore procedure; pairs with monitoring and security. |
| [Monitoring / Logging](MONITORING-LOGGING.md) | Signals, redaction, quotas, and alerts; pairs with deployment and support. |
| [Support / Maintenance SOP](SUPPORT-MAINTENANCE-SOP.md) | Incidents, data requests, maintenance; pairs with runbook and user help. |
| [Release Notes](RELEASE-NOTES.md) | Draft release record and public changes; must match verified code and user manual. |
| [User Manual / Help](USER-MANUAL-HELP.md) | Planned owner/customer guidance; validate against implemented screens before publication. |
| [Implementation index](docs/implementation/README.md) | Daily sequence, defaults, shared rules, and gates. |
| [Foundation D01–D05](docs/implementation/01-foundation.md) | Setup, architecture, schema, identity, and shop authorization. |
| [Online ledger D06–D10](docs/implementation/02-online-ledger.md) | QR, linking, credit, payment, and history. |
| [Offline and trust D11–D15](docs/implementation/03-offline-trust.md) | Outbox, sync, offline QR, corrections, and disputes. |
| [Release completeness D16–D20](docs/implementation/04-release-completeness.md) | Due dates, sharing, localization, privacy, backups, and monitoring. |
| [Pilot and release D21–D24](docs/implementation/05-pilot-release.md) | Regression, private test, pilot, and launch decision. |
| [Progress](docs/implementation/PROGRESS.md) | Actual phase state and evidence; never infer completion from a specification. |
| [Root README](README.md) | Current repository/tooling entry point. |
| [Flutter README](udhaarkhata/README.md) | App-specific orientation and links back to plan/specs. |
| [iOS launch asset README](udhaarkhata/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md) | Generated platform asset note; iOS is outside the first-release product scope. |

## Change propagation

When a decision changes, update its owning document and downstream contract/test documents in the same work item. Examples: a new QR format touches [PRD](PRD.md), [SRS](SRS.md), [SES](SES.md), [API](API-SPECIFICATION.md), [Security](SECURITY-REQUIREMENTS.md), [UI/UX](UI-UX-DESIGN-SPEC.md), and [QA cases](TEST-CASES-QA-CHECKLIST.md); a ledger rule touches [SRS](SRS.md), [LLD](LLD.md), [database](DATABASE-DESIGN-ERD.md), [API](API-SPECIFICATION.md), [test plan](TEST-PLAN.md), and [QA cases](TEST-CASES-QA-CHECKLIST.md). Update [progress](docs/implementation/PROGRESS.md) with implementation evidence. Run `python scripts/check_docs.py` after editing Markdown to catch broken file links and missing navigation.
