#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def core_line_coverage(report):
    covered = 0
    total = 0
    for record in report.get("data", []):
        for source in record.get("files", []):
            filename = source.get("filename", "")
            if "/Sources/SweepdeckCore/" not in filename and not filename.startswith("Sources/SweepdeckCore/"):
                continue
            lines = source.get("summary", {}).get("lines", {})
            covered += lines.get("covered", 0)
            total += lines.get("count", 0)
    if total == 0:
        raise ValueError("Coverage report contains no executable SweepdeckCore lines.")
    return covered, total


def meets_floor(covered, total, threshold):
    return total > 0 and covered * 100 >= total * threshold


def main():
    if len(sys.argv) not in (2, 3):
        print(f"Usage: {Path(sys.argv[0]).name} <coverage-json> [minimum-percent]", file=sys.stderr)
        return 64
    coverage_path = Path(sys.argv[1])
    threshold = float(sys.argv[2]) if len(sys.argv) == 3 else 80.0
    if not 0 <= threshold <= 100:
        print("Coverage threshold must be between 0 and 100.", file=sys.stderr)
        return 64
    try:
        report = json.loads(coverage_path.read_text())
        covered, total = core_line_coverage(report)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"Could not read SwiftPM coverage report: {error}", file=sys.stderr)
        return 1
    percent = covered * 100 / total
    print(f"SweepdeckCore executable-line coverage: {covered}/{total} ({percent:.1f}%); required: {threshold:.1f}%")
    if not meets_floor(covered, total, threshold):
        print("SweepdeckCore line coverage is below the required floor.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
