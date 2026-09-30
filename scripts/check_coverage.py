"""Check LCOV line coverage without a platform-specific coverage tool."""

import argparse
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("file", type=Path)
    parser.add_argument("--minimum", type=float, default=80)
    args = parser.parse_args()
    records = args.file.read_text(encoding="utf-8").splitlines()
    total = sum(int(line[3:]) for line in records if line.startswith("LF:"))
    covered = sum(int(line[3:]) for line in records if line.startswith("LH:"))
    if not total:
        raise SystemExit("No executable source lines in coverage report")
    percent = covered * 100 / total
    print(f"Line coverage: {covered}/{total} = {percent:.2f}% (minimum {args.minimum:g}%)")
    return 0 if percent >= args.minimum else 1


if __name__ == "__main__":
    raise SystemExit(main())
