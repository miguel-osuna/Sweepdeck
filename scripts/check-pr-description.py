#!/usr/bin/env python3
"""Reject pull request descriptions that contain only template scaffolding."""

import os
import re
import sys

body = re.sub(r"<!--.*?-->", "", os.environ.get("PR_BODY", ""), flags=re.DOTALL)
content = []
for line in body.splitlines():
    text = line.strip()
    if not text or re.match(r"^#{1,6}\s", text):
        continue
    if re.match(r"^[-*+]\s+\[[ xX]\]\s*", text) or re.fullmatch(r"-{3,}", text):
        continue
    content.append(text)

if not content:
    print("Add a description under the template headings before requesting review.", file=sys.stderr)
    sys.exit(1)

print("PR description contains author-provided text.")
