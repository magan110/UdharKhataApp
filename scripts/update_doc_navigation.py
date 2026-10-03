"""Keep related-document links visible at the top of every authored project Markdown file."""

from pathlib import Path
import os
import sys


ROOT = Path(__file__).resolve().parents[1]
START = "<!-- DOC_NAV_START -->"
END = "<!-- DOC_NAV_END -->"

LABELS = {
    "docs/implementation/06-ui-ux-redesign.md": "UX01 UI/UX redesign",
    "docs/agents/ui-ux-redesign-agent.md": "UI/UX agent brief",
    'docs/superpowers/specs/2026-10-02-d13-d21-design.md': 'D13–D21 design',
    'docs/superpowers/plans/2026-10-02-d13-d21.md': 'D13–D21 implementation plan',
    'docs/ops/private-test-operations.md': 'Private-test operations',
    'docs/verification/d21-evidence.md': 'D21 candidate evidence',

    "docs/superpowers/plans/2026-10-02-d12-sync.md": "D12 implementation plan",
    "docs/superpowers/specs/2026-10-02-d12-sync-design.md": "D12 sync design",
    "AGENTS.md": "Repository instructions",
    "README.md": "Repository README",
    "DOCUMENT-MAP.md": "Document map",
    "API-SPECIFICATION.md": "API specification",
    "BRD.md": "BRD",
    "CODING-STANDARDS-DEVELOPMENT-GUIDELINES.md": "Coding standards",
    "DATABASE-DESIGN-ERD.md": "Database design",
    "DEPLOYMENT-RUNBOOK.md": "Deployment runbook",
    "HLD.md": "HLD",
    "LLD.md": "LLD",
    "MARKET-COMPETITOR-RESEARCH.md": "Market research",
    "MONITORING-LOGGING.md": "Monitoring and logging",
    "PRD.md": "PRD",
    "PRODUCT-VISION.md": "Product vision",
    "PROJECT-PLAN-ROADMAP.md": "Roadmap",
    "RELEASE-NOTES.md": "Release notes",
    "SCOPE.md": "Scope",
    "SECURITY-REQUIREMENTS.md": "Security requirements",
    "SES.md": "SES",
    "SRS.md": "SRS",
    "SUPPORT-MAINTENANCE-SOP.md": "Support SOP",
    "TEST-CASES-QA-CHECKLIST.md": "QA cases",
    "TEST-PLAN.md": "Test plan",
    "UI-UX-DESIGN-SPEC.md": "UI/UX spec",
    "USE-CASES-USER-STORIES.md": "Use cases and stories",
    "USER-JOURNEY-USER-FLOW.md": "User journeys",
    "USER-MANUAL-HELP.md": "User manual",
    "USER-PERSONAS.md": "Personas",
    "WIREFRAMES.md": "Wireframes",
    "docs/implementation/README.md": "Daily implementation plan",
    "docs/implementation/PROGRESS.md": "Implementation progress",
    "docs/implementation/01-foundation.md": "Foundation phases",
    "docs/implementation/02-online-ledger.md": "Online ledger phases",
    "docs/implementation/03-offline-trust.md": "Offline and trust phases",
    "docs/implementation/04-release-completeness.md": "Release completeness phases",
    "docs/implementation/05-pilot-release.md": "Pilot and release phases",
    "udhaarkhata/README.md": "Flutter app README",
    "udhaarkhata/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md": "iOS launch asset note",
}

# Each list is intentionally short and topical. DOCUMENT-MAP.md connects all files.
RELATED = {
    "docs/implementation/06-ui-ux-redesign.md": ["docs/agents/ui-ux-redesign-agent.md", "UI-UX-DESIGN-SPEC.md", "WIREFRAMES.md", "docs/implementation/PROGRESS.md"],
    "docs/agents/ui-ux-redesign-agent.md": ["docs/implementation/06-ui-ux-redesign.md", "AGENTS.md", "USER-PERSONAS.md"],
    'docs/superpowers/specs/2026-10-02-d13-d21-design.md': ['SRS.md', 'SECURITY-REQUIREMENTS.md', 'docs/implementation/PROGRESS.md'],
    'docs/superpowers/plans/2026-10-02-d13-d21.md': ['docs/superpowers/specs/2026-10-02-d13-d21-design.md', 'docs/verification/d21-evidence.md'],
    'docs/ops/private-test-operations.md': ['DEPLOYMENT-RUNBOOK.md', 'MONITORING-LOGGING.md', 'SECURITY-REQUIREMENTS.md', 'docs/verification/d21-evidence.md'],
    'docs/verification/d21-evidence.md': ['SRS.md', 'TEST-PLAN.md', 'TEST-CASES-QA-CHECKLIST.md', 'docs/ops/private-test-operations.md'],

    "docs/superpowers/plans/2026-10-02-d12-sync.md": ["docs/superpowers/specs/2026-10-02-d12-sync-design.md", "docs/implementation/03-offline-trust.md", "docs/implementation/PROGRESS.md"],
    "docs/superpowers/specs/2026-10-02-d12-sync-design.md": ["docs/implementation/03-offline-trust.md", "API-SPECIFICATION.md", "SECURITY-REQUIREMENTS.md", "docs/implementation/PROGRESS.md"],
    "AGENTS.md": ["SCOPE.md", "SRS.md", "PRD.md", "docs/implementation/README.md"],
    "README.md": ["AGENTS.md", "docs/implementation/README.md", "docs/implementation/PROGRESS.md", "udhaarkhata/README.md"],
    "PRODUCT-VISION.md": ["MARKET-COMPETITOR-RESEARCH.md", "BRD.md", "SCOPE.md", "PRD.md"],
    "MARKET-COMPETITOR-RESEARCH.md": ["PRODUCT-VISION.md", "BRD.md", "PROJECT-PLAN-ROADMAP.md", "docs/implementation/05-pilot-release.md"],
    "BRD.md": ["PRODUCT-VISION.md", "MARKET-COMPETITOR-RESEARCH.md", "SCOPE.md", "PRD.md"],
    "SCOPE.md": ["BRD.md", "PRD.md", "SRS.md", "PROJECT-PLAN-ROADMAP.md"],
    "PRD.md": ["SCOPE.md", "USER-PERSONAS.md", "USER-JOURNEY-USER-FLOW.md", "SRS.md", "UI-UX-DESIGN-SPEC.md"],
    "USER-PERSONAS.md": ["PRODUCT-VISION.md", "PRD.md", "USER-JOURNEY-USER-FLOW.md", "UI-UX-DESIGN-SPEC.md"],
    "USER-JOURNEY-USER-FLOW.md": ["USER-PERSONAS.md", "USE-CASES-USER-STORIES.md", "PRD.md", "WIREFRAMES.md"],
    "USE-CASES-USER-STORIES.md": ["USER-JOURNEY-USER-FLOW.md", "PRD.md", "SRS.md", "TEST-CASES-QA-CHECKLIST.md"],
    "WIREFRAMES.md": ["USER-JOURNEY-USER-FLOW.md", "USE-CASES-USER-STORIES.md", "UI-UX-DESIGN-SPEC.md", "PRD.md"],
    "UI-UX-DESIGN-SPEC.md": ["WIREFRAMES.md", "PRD.md", "SRS.md", "USER-MANUAL-HELP.md"],
    "SRS.md": ["SCOPE.md", "PRD.md", "SES.md", "TEST-PLAN.md", "TEST-CASES-QA-CHECKLIST.md"],
    "SES.md": ["SRS.md", "HLD.md", "LLD.md", "DATABASE-DESIGN-ERD.md", "API-SPECIFICATION.md"],
    "HLD.md": ["SES.md", "LLD.md", "SECURITY-REQUIREMENTS.md", "DATABASE-DESIGN-ERD.md"],
    "LLD.md": ["HLD.md", "DATABASE-DESIGN-ERD.md", "API-SPECIFICATION.md", "CODING-STANDARDS-DEVELOPMENT-GUIDELINES.md"],
    "DATABASE-DESIGN-ERD.md": ["LLD.md", "API-SPECIFICATION.md", "SECURITY-REQUIREMENTS.md", "TEST-CASES-QA-CHECKLIST.md"],
    "API-SPECIFICATION.md": ["SRS.md", "LLD.md", "DATABASE-DESIGN-ERD.md", "SECURITY-REQUIREMENTS.md", "TEST-CASES-QA-CHECKLIST.md"],
    "SECURITY-REQUIREMENTS.md": ["SRS.md", "API-SPECIFICATION.md", "DATABASE-DESIGN-ERD.md", "TEST-PLAN.md", "DEPLOYMENT-RUNBOOK.md"],
    "CODING-STANDARDS-DEVELOPMENT-GUIDELINES.md": ["LLD.md", "SECURITY-REQUIREMENTS.md", "TEST-PLAN.md", "docs/implementation/README.md"],
    "PROJECT-PLAN-ROADMAP.md": ["SCOPE.md", "PRD.md", "SRS.md", "docs/implementation/README.md", "TEST-PLAN.md"],
    "TEST-PLAN.md": ["SRS.md", "SECURITY-REQUIREMENTS.md", "TEST-CASES-QA-CHECKLIST.md", "PROJECT-PLAN-ROADMAP.md"],
    "TEST-CASES-QA-CHECKLIST.md": ["SRS.md", "USE-CASES-USER-STORIES.md", "TEST-PLAN.md", "SECURITY-REQUIREMENTS.md"],
    "DEPLOYMENT-RUNBOOK.md": ["SECURITY-REQUIREMENTS.md", "MONITORING-LOGGING.md", "SUPPORT-MAINTENANCE-SOP.md", "RELEASE-NOTES.md"],
    "MONITORING-LOGGING.md": ["DEPLOYMENT-RUNBOOK.md", "SECURITY-REQUIREMENTS.md", "SUPPORT-MAINTENANCE-SOP.md", "TEST-PLAN.md"],
    "SUPPORT-MAINTENANCE-SOP.md": ["DEPLOYMENT-RUNBOOK.md", "MONITORING-LOGGING.md", "USER-MANUAL-HELP.md", "RELEASE-NOTES.md"],
    "RELEASE-NOTES.md": ["PROJECT-PLAN-ROADMAP.md", "DEPLOYMENT-RUNBOOK.md", "TEST-CASES-QA-CHECKLIST.md", "USER-MANUAL-HELP.md"],
    "USER-MANUAL-HELP.md": ["PRD.md", "UI-UX-DESIGN-SPEC.md", "RELEASE-NOTES.md", "SUPPORT-MAINTENANCE-SOP.md"],
    "docs/implementation/README.md": ["PROJECT-PLAN-ROADMAP.md", "SRS.md", "SECURITY-REQUIREMENTS.md", "docs/implementation/PROGRESS.md"],
    "docs/implementation/PROGRESS.md": ["docs/implementation/README.md", "PROJECT-PLAN-ROADMAP.md", "TEST-PLAN.md"],
    "docs/implementation/01-foundation.md": ["docs/implementation/README.md", "SRS.md", "HLD.md", "DATABASE-DESIGN-ERD.md", "SECURITY-REQUIREMENTS.md"],
    "docs/implementation/02-online-ledger.md": ["docs/implementation/README.md", "PRD.md", "API-SPECIFICATION.md", "DATABASE-DESIGN-ERD.md", "UI-UX-DESIGN-SPEC.md"],
    "docs/implementation/03-offline-trust.md": ["docs/implementation/README.md", "LLD.md", "SRS.md", "SECURITY-REQUIREMENTS.md", "TEST-CASES-QA-CHECKLIST.md"],
    "docs/implementation/04-release-completeness.md": ["docs/implementation/README.md", "PRD.md", "SRS.md", "DEPLOYMENT-RUNBOOK.md", "USER-MANUAL-HELP.md"],
    "docs/implementation/05-pilot-release.md": ["docs/implementation/README.md", "PROJECT-PLAN-ROADMAP.md", "TEST-PLAN.md", "DEPLOYMENT-RUNBOOK.md", "RELEASE-NOTES.md"],
    "udhaarkhata/README.md": ["README.md", "docs/implementation/README.md", "UI-UX-DESIGN-SPEC.md", "SRS.md"],
    "udhaarkhata/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md": ["udhaarkhata/README.md", "SCOPE.md"],
}


def link(from_doc: str, to_doc: str) -> str:
    relative = os.path.relpath(ROOT / to_doc, (ROOT / from_doc).parent).replace("\\", "/")
    return f"[{LABELS[to_doc]}]({relative})"


def update_document(name: str, related: list[str], check: bool = False) -> bool:
    path = ROOT / name
    raw = path.read_bytes().decode("utf-8-sig")
    newline = "\r\n" if "\r\n" in raw else "\n"
    primary = link(name, "DOCUMENT-MAP.md")
    companions = " · ".join(link(name, target) for target in related)
    block = f"{START}{newline}> **Document map:** {primary}. **Read with:** {companions}.{newline}{END}"
    if START in raw or END in raw:
        if raw.count(START) != 1 or raw.count(END) != 1:
            raise ValueError(f"Malformed navigation markers: {name}")
        before, tail = raw.split(START, 1)
        _, after = tail.split(END, 1)
        result = before + block + after
    else:
        first_line, separator, rest = raw.partition(newline)
        if not separator or not first_line.startswith("# "):
            raise ValueError(f"Expected H1 title: {name}")
        result = first_line + newline + newline + block + newline + rest
    if result != raw:
        if not check:
            path.write_bytes(result.encode("utf-8"))
        return True
    return False


def main() -> None:
    if set(RELATED) != set(LABELS) - {"DOCUMENT-MAP.md"}:
        raise ValueError("Navigation inventory and labels differ")
    check = "--check" in sys.argv[1:]
    changed = [name for name, related in RELATED.items() if update_document(name, related, check)]
    if check:
        if changed:
            print(f"Navigation out of date in {len(changed)} files: {', '.join(changed)}")
            raise SystemExit(1)
        print("Document navigation blocks are up to date.")
    else:
        print(f"Updated {len(changed)} document navigation blocks.")


if __name__ == "__main__":
    main()
