#!/usr/bin/env python3
"""Print recent XCTest and SwiftPM helper crash stacks from a macOS runner."""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path
from typing import Any


PROCESS_MARKERS = (
    "xctest",
    "swiftpm-testing-helper",
    "sweepdeckappearancetests",
    "sweepdeckpackagetests",
)
REPORT_SUFFIXES = {".crash", ".ips"}


def parse_json_documents(contents: str) -> list[dict[str, Any]]:
    try:
        document = json.loads(contents)
        if isinstance(document, dict):
            return [document]
    except json.JSONDecodeError:
        pass

    documents = []
    for line in contents.splitlines():
        try:
            document = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(document, dict):
            documents.append(document)
    return documents


def report_json(documents: list[dict[str, Any]]) -> None:
    for document in documents:
        print(
            "process={process} pid={pid} exception={exception} termination={termination}".format(
                process=document.get("procName", document.get("app_name", "unknown")),
                pid=document.get("pid", "unknown"),
                exception=document.get("exception", "unknown"),
                termination=document.get("termination", "unknown"),
            )
        )
        faulting_thread = document.get("faultingThread")
        for index, thread in enumerate(document.get("threads", [])):
            if not isinstance(thread, dict):
                continue
            if not thread.get("triggered") and thread.get("id") != faulting_thread:
                continue
            print(f"crashed_thread={index} name={thread.get('name', 'unknown')} id={thread.get('id', 'unknown')}")
            for frame in thread.get("frames", [])[:80]:
                if not isinstance(frame, dict):
                    continue
                image = frame.get("imageName", frame.get("image", "unknown"))
                symbol = frame.get("symbol", frame.get("symbolName", "unknown"))
                offset = frame.get("imageOffset", frame.get("symbolLocation", "unknown"))
                print(f"  {image} {symbol} + {offset}")


def report_process_names(documents: list[dict[str, Any]]) -> str:
    names = []
    for document in documents:
        for key in ("procName", "app_name", "process", "procPath"):
            value = document.get(key)
            if isinstance(value, str) and value not in names:
                names.append(value)
    return ", ".join(names)


def main() -> int:
    report_directories = (
        [Path(sys.argv[1])]
        if len(sys.argv) > 1
        else [
            Path.home() / "Library/Logs/DiagnosticReports",
            Path("/Library/Logs/DiagnosticReports"),
        ]
    )
    cutoff = time.time() - 30 * 60
    recent_reports: list[tuple[Path, str, list[dict[str, Any]]]] = []
    for report_directory in report_directories:
        try:
            for path in report_directory.iterdir():
                if path.suffix not in REPORT_SUFFIXES or path.stat().st_mtime < cutoff:
                    continue
                contents = path.read_text(errors="replace")
                documents = parse_json_documents(contents) if path.suffix == ".ips" else []
                recent_reports.append((path, contents, documents))
        except OSError:
            continue

    reports = [
        (path, contents, documents)
        for path, contents, documents in recent_reports
        if any(marker in " ".join((path.name.lower(), contents.lower())) for marker in PROCESS_MARKERS)
    ]

    if not reports:
        searched = ", ".join(str(directory) for directory in report_directories)
        process_names = sorted({
            name
            for _, _, documents in recent_reports
            for name in report_process_names(documents).split(", ")
            if name
        })
        observed = f"; recent process names: {', '.join(process_names)}" if process_names else ""
        print(
            "No recent XCTest or SwiftPM helper crash reports found "
            f"(recent diagnostic reports: {len(recent_reports)}{observed}; searched: {searched})."
        )
        return 0

    for path, contents, documents in sorted(reports, key=lambda report: report[0].stat().st_mtime):
        print(f"Crash report: {path}")
        if documents:
            report_json(documents)
        else:
            print("\n".join(contents.splitlines()[:240]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
