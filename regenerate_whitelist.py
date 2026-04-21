#!/usr/bin/env python3
"""Regenerate whitelist.txt from categories/*.txt files."""

import os
import glob

script_dir = os.path.dirname(os.path.abspath(__file__))
categories_dir = os.path.join(script_dir, "categories")
whitelist_path = os.path.join(script_dir, "whitelist.txt")

domains = set()

files = sorted(glob.glob(os.path.join(categories_dir, "*.txt")))
for filepath in files:
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            # Remove inline comments
            domain = line.split("#")[0].strip()
            if domain:
                domains.add(domain)

with open(whitelist_path, "w", encoding="utf-8") as f:
    f.write("# Автоматично згенеровано\n")
    for domain in sorted(domains, key=lambda x: x.lower()):
        f.write(domain + "\n")

print(f"Файл {whitelist_path} згенеровано з {len(domains)} доменів")
