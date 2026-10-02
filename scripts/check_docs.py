"""Validate links and navigation across all project Markdown documents."""

from collections import defaultdict, deque
from pathlib import Path
import os
import re
from urllib.parse import unquote

from update_doc_navigation import END, RELATED, ROOT, START


HREF = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
HEADING = re.compile(r"^#{1,6}\s+(.+?)\s*#*\s*$", re.MULTILINE)
EXPECTED = set(RELATED) | {"DOCUMENT-MAP.md"}


def slugs(text: str) -> set[str]:
    seen = defaultdict(int)
    output = set()
    for heading in HEADING.findall(text):
        # GitHub-style heading identifiers; sufficient for this repository's titles.
        plain = re.sub(r"`([^`]*)`", r"\1", heading)
        plain = re.sub(r"\[[^\]]+\]\([^)]+\)", "", plain)
        plain = re.sub(r"[^\w\- ]", "", plain.lower()).replace(" ", "-")
        slug = f"{plain}-{seen[plain]}" if seen[plain] else plain
        seen[plain] += 1
        output.add(slug)
    return output


def main() -> int:
    errors = []
    authored = {
        p.relative_to(ROOT).as_posix()
        for p in ROOT.rglob("*.md")
        if not any(part in {".git", ".dart_tool", "node_modules", "build", ".superpowers"} for part in p.relative_to(ROOT).parts)
    }
    if authored != EXPECTED:
        errors.append(f"Inventory differs: unregistered={sorted(authored - EXPECTED)}, missing={sorted(EXPECTED - authored)}")

    graph = defaultdict(set)
    for name in sorted(EXPECTED & authored):
        path = ROOT / name
        text = path.read_text(encoding="utf-8-sig")
        if not text.startswith("# "):
            errors.append(f"{name}: missing H1")
        if name != "DOCUMENT-MAP.md":
            if text.count(START) != 1 or text.count(END) != 1:
                errors.append(f"{name}: expected one navigation block")
            elif "DOCUMENT-MAP.md" not in text.split(START, 1)[1].split(END, 1)[0]:
                errors.append(f"{name}: navigation block lacks map link")
            else:
                navigation = text.split(START, 1)[1].split(END, 1)[0]
                for companion in RELATED[name]:
                    expected_href = os.path.relpath(ROOT / companion, (ROOT / name).parent).replace("\\", "/")
                    if f"]({expected_href})" not in navigation:
                        errors.append(f"{name}: navigation lacks related document {companion}")
        for href in HREF.findall(text):
            if re.match(r"^[a-z][a-z0-9+.-]*:", href, re.IGNORECASE):
                continue
            target_path, _, fragment = href.partition("#")
            if not target_path:
                destination = path
            else:
                destination = (path.parent / unquote(target_path.strip("<>"))).resolve()
            if not destination.exists():
                errors.append(f"{name}: missing link target {href}")
                continue
            if fragment and destination.suffix.lower() == ".md":
                if unquote(fragment) not in slugs(destination.read_text(encoding="utf-8-sig")):
                    errors.append(f"{name}: missing heading fragment {href}")
            try:
                target_name = destination.relative_to(ROOT).as_posix()
            except ValueError:
                continue
            if target_name in EXPECTED:
                graph[name].add(target_name)

    for name in sorted(EXPECTED):
        seen = {name}
        queue = deque([name])
        while queue:
            current = queue.popleft()
            for nxt in graph[current] - seen:
                seen.add(nxt)
                queue.append(nxt)
        if seen != EXPECTED:
            errors.append(f"{name}: cannot reach {sorted(EXPECTED - seen)}")

    missing_from_map = (EXPECTED - {"DOCUMENT-MAP.md"}) - graph["DOCUMENT-MAP.md"]
    if missing_from_map:
        errors.append(f"DOCUMENT-MAP.md: missing catalog links to {sorted(missing_from_map)}")

    if errors:
        print("Documentation checks failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"Documentation checks passed: {len(EXPECTED)} Markdown files, valid local targets/fragments, complete map, all mutually reachable.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
