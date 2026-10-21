#!/usr/bin/env python3
"""Print recent XCTest and SwiftPM helper crash stacks from a macOS runner."""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path
from typing import Any


PROCESS_MARKERS = ("xctest", "swiftpm-testing-helper")
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


def main() -> int:
    report_directory = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "Library/Logs/DiagnosticReports"
    cutoff = time.time() - 30 * 60
    reports = [
        path
        for path in report_directory.glob("*")
        if path.suffix in REPORT_SUFFIXES
        and any(marker in path.name.lower() for marker in PROCESS_MARKERS)
        and path.stat().st_mtime >= cutoff
    ]

    if not reports:
        print(f"No recent XCTest or swiftpm-testing-helper crash reports in {report_directory}.")
        return 0

    for path in sorted(reports, key=lambda candidate: candidate.stat().st_mtime):
        print(f"Crash report: {path}")
        contents = path.read_text(errors="replace")
        documents = parse_json_documents(contents) if path.suffix == ".ips" else []
        if documents:
            report_json(documents)
        else:
            print("\n".join(contents.splitlines()[:240]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
