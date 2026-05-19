#!/usr/bin/env python3
"""Regenerate whitelist.txt from categories/*.txt files, matching generate_whitelist.sh behavior."""

import os
import glob

script_dir = os.path.dirname(os.path.abspath(__file__))
categories_dir = os.path.join(script_dir, "categories")
whitelist_path = os.path.join(script_dir, "whitelist.txt")

include_external = os.environ.get("INCLUDE_EXTERNAL_SOURCES", "1") == "1"
sources_combined = os.environ.get("SOURCES_COMBINED", os.path.join(script_dir, "sources", "generated", "all_sources.txt"))

domains = set()

files = sorted(glob.glob(os.path.join(categories_dir, "*.txt")))
for filepath in files:
    if os.path.basename(filepath) == "comment_allowlist.txt":
        continue
    with open(filepath, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            domain = line.split("#")[0].strip()
            if domain:
                domains.add(domain)

if include_external and sources_combined and os.path.isfile(sources_combined):
    with open(sources_combined, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line:
                domains.add(line)

with open(whitelist_path, "w", encoding="utf-8") as f:
    f.write("# Автоматично згенеровано скриптом generate_whitelist.sh\n")
    for domain in sorted(domains, key=lambda x: x.lower()):
        f.write(domain + "\n")

print(f"Файл {whitelist_path} згенеровано з {len(domains)} доменів")
