# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`tsutsman-pihole-whitelist` is a curated whitelist of domains for Pi-hole (v5/v6) DNS ad-blocker. The repository bundles domain lists for Apple/Microsoft/Google services, Ukrainian services and banks, messengers, cloud storage, smart-home devices, NTP servers, gaming platforms, and more. The combined `whitelist.txt` is published via raw GitHub URL and may be consumed through Pi-hole's "Adlists" feature.

**Primary user-facing artifacts:** `whitelist.txt` (auto-generated, do not edit by hand) plus per-topic files in `categories/`.

The project uses two languages for user-facing strings: **Ukrainian** (primary — `README.md`, scripts) and **English** (`README.en.md`, several scripts contain bilingual comments). New user-facing messages should follow the same bilingual comment style used in `generate_whitelist.sh`.

## Architecture & Data Flow

```
categories/*.txt  ──┐
                    ├──► generate_whitelist.sh  ──►  whitelist.txt
sources/generated/ ─┘                                  │
   ▲                                                   ▼
fetch_sources.sh                              apply_whitelist.sh  ──►  pihole / pihole-FTL
   ▲                                                   ▲
sources/default_sources.txt                          update_and_apply.sh
                                                    (downloads raw + applies)
```

### Top-level scripts (run as `./script.sh`)

| Script | Purpose |
| --- | --- |
| `generate_whitelist.sh` | Strips comments/blanks, deduplicates, and produces `whitelist.txt` from `categories/*.txt` (and `sources/generated/all_sources.txt` if present). Filters out `comment_allowlist.txt`. |
| `fetch_sources.sh` | Downloads external whitelist URLs listed in `sources/default_sources.txt` (format `name|URL|comment`), normalizes them to plain domains, caches responses, and writes `sources/generated/<name>.txt` plus a combined `all_sources.txt`. |
| `apply_whitelist.sh` | Adds domains from a file to a running Pi-hole (`pihole -w` for v5, `pihole-FTL whitelist add` for v6). Sends Telegram notifications if `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID` are set (uses `telegram_logger.sh`). |
| `update_and_apply.sh` | Downloads the latest `whitelist.txt` from `main` and applies it. Use as a cron job. |
| `auto_update_domains.sh` | Orchestrator: fetch external sources → generate whitelist → optionally run `analyze_domains.py` → optionally apply. Supports flags `--skip-fetch`, `--include-external 0|1`, `--update-analysis 0|1`, `--apply-directly 0|1`, `--log-file`. |
| `check_duplicates.sh` | Detects duplicates within each file and (optionally) checks DNS resolvability with `host`/`nslookup`. Set `SKIP_DNS_CHECK=1` to skip DNS in offline environments. |
| `cleanup_whitelist.sh` | Periodically re-checks domains; moves domains that fail DNS for `THRESHOLD` (default 3) consecutive runs to `categories/deprecated.txt`. |
| `check_category_comments.sh` | Enforces that every domain in `categories/*.txt` (excluding `deprecated.txt` and `comment_allowlist.txt`) is either commented inline OR listed in `categories/comment_allowlist.txt`. |
| `validate_category_metadata.sh` | Verifies that every category file declares `@description`, `@author`, and `@last_review` (in `YYYY-MM-DD` form) in its leading comment block. |
| `sort_categories.sh` | Sorts domains alphabetically inside each category file (preserves header comment block). |
| `export_whitelist.sh` | Converts `whitelist.txt` to AdGuard Home (`@@||domain^`) or pfBlockerNG formats. |
| `build_whitelist.sh` | Programmatic builder: takes `--categories a.txt,b.txt` and `--extra-path` args, calls `generate_whitelist.sh` in a tempdir, optionally applies. Used by the REST API. |
| `generate_stats_report.sh` | Produces `docs/data_stats.md`, `docs/data_stats.en.md`, `docs/dashboard.html`, and appends to `docs/data_history.json`. Used by the CI `keep` timestamp check. |

### Python utilities

| File | Purpose |
| --- | --- |
| `analyze_domains.py` | Reads `categories/` and optional `whitelist.txt`, writes Markdown + JSON analytics to `docs/domain_analysis.{md,json}`. CLI flags/env vars: `--categories`, `--whitelist`, `--output`, `--json`, `--category-sort {name,total,unique,duplicates,unique_ratio}`, `--category-sort-order {auto,asc,desc}`, `--stdout`. |
| `regenerate_whitelist.py` | Pure-Python alternative to `generate_whitelist.sh` (same inputs/outputs, honors `INCLUDE_EXTERNAL_SOURCES`/`SOURCES_COMBINED` env vars). |
| `whitelist_builder_api.py` | `http.server` REST API on a configurable port, authenticates with `Authorization: Bearer <token>` (or `X-API-Token`). Endpoints: `GET /health`, `GET /api/categories`, `POST /api/build` (requires `categories` list, optional `extra_paths`, `include_external`, `apply_directly`, `sources_combined`), `GET /downloads/<file>`. Reuses `build_whitelist.sh`; pass `--allow-external-categories` and `--allow-extra-path` to broaden path access; `--allow-apply-directly` gates the apply flag. |

### Web

- `web/whitelist_builder.html` — single-page form that calls the API. Serve via `python3 -m http.server` and reverse-proxy `/api/*` to the API port.

### Categories file format

Each `categories/*.txt` file:

1. Starts with comment lines beginning with `#` (bilingual or single-language — follow the style of `categories/tailscale.txt` or `categories/base.txt`).
2. Declares metadata as `# @description: …`, `# @author: …`, `# @last_review: YYYY-MM-DD` — required by `validate_category_metadata.sh` (runs in CI).
3. Lists one domain per line, with an optional trailing `# YYYY-MM-DD reason` comment. Domain lines without an inline comment must appear in `categories/comment_allowlist.txt` (format `filename|domain`) or `check_category_comments.sh` will fail (also runs in CI).
4. `comment_allowlist.txt`, `deprecated.txt`, and any future internal files should be excluded from `whitelist.txt`; `generate_whitelist.sh` already excludes `comment_allowlist.txt`.

`categories/deprecated.txt` lines are written by `cleanup_whitelist.sh` as `domain # category:<source_category>` and are excluded from the build.

## Common Development Tasks

### Run the full test suite

```bash
chmod +x tests/*.sh
for script in tests/*_test.sh; do bash "$script"; done
```

CI does exactly this in `.github/workflows/ci.yml` after installing `dnsutils` for the `host` lookup. The same workflow then runs `generate_stats_report.sh` with all `*_TIMESTAMP_MODE=keep` and `git diff --exit-code` against the report files — so any edit to a category that changes counts must be paired with re-running this script.

### Lint shell scripts

`tests/shellcheck_test.sh` runs `shellcheck -S warning *.sh tests/*.sh` (auto-installs on Ubuntu). The same warning level is enforced in CI.

### Add a new domain to an existing category

1. Edit the file under `categories/` and append the domain with a `# YYYY-MM-DD reason` comment.
2. Run `./generate_whitelist.sh` to refresh `whitelist.txt`.
3. Run `bash tests/check_duplicates_test.sh` and the wider suite to confirm nothing regresses.
4. Open a PR. The duplicate-check workflow (`.github/workflows/duplicate_check.yml`) will verify `whitelist.txt` is up to date.

### Add a new category

Create `categories/<name>.txt` with the required `@description`/`@author`/`@last_review` header (otherwise `validate_category_metadata.sh` fails in CI) and an optional short bilingual intro. Then re-run `generate_whitelist.sh` and the test suite.

### Regenerate analytics & dashboard locally

```bash
./generate_stats_report.sh
```

If you need to verify "what the CI would diff against" without changing timestamps, run with the four `*_TIMESTAMP_MODE=keep` env vars and then `git diff --exit-code docs/`.

### Run the REST API locally

```bash
python3 whitelist_builder_api.py \
  --host 127.0.0.1 --port 5050 \
  --api-token "dev-token" \
  --data-dir /tmp/whitelist-data \
  --log-file /tmp/whitelist-api.log
```

Browse the static page with `python3 -m http.server` and open `http://localhost:8000/web/whitelist_builder.html` (configure the API base URL in the page or proxy `/api/*`).

### Apply the whitelist to a Pi-hole host

```bash
./apply_whitelist.sh                    # default whitelist.txt
./apply_whitelist.sh exports/custom.txt  # custom file
```

Override the source URL with `REPO_URL=` and the log path with `LOG_FILE=` for `update_and_apply.sh`.

## CI Workflows (`.github/workflows/`)

- `ci.yml` — runs on push to `main`/`master`/`codex/**` and on every PR. Executes all `tests/*_test.sh`, then verifies stats/dashboard are up to date.
- `duplicate_check.yml` — runs on PRs that touch `*.txt` or the script itself; runs `check_duplicates.sh` and verifies `whitelist.txt` matches the categories (re-generates and `git diff --quiet --exit-code`).
- `weekly_check.yml` — Sundays 03:00 UTC. Runs `check_duplicates.sh`; if unreachable domains are found, opens or updates a GitHub issue titled `Недоступні домени YYYY-MM-DD`.

## Conventions & Gotchas

- **Never edit `whitelist.txt` by hand.** It is regenerated from `categories/` and is enforced by the duplicate-check workflow.
- **Bilingual comments are encouraged** in new category files (Ukrainian first, English below — see `categories/tailscale.txt` or `categories/base.txt`).
- **`@last_review` dates must be updated** when substantially editing a category — the field is validated.
- **`cleanup_whitelist.sh` mutates files in place.** Don't run it on a dirty working tree without a backup.
- **`fetch_sources.sh` has a cache** at `sources/generated/cache/` (TTL via `CACHE_TTL`, default 86400s, set to `0` to disable caching).
- **`whitelist_builder_api.py` paths:** the `--allow-extra-path` flag is repeatable; absolute category paths require `--allow-external-categories`; `apply_directly` in the API is opt-in via `--allow-apply-directly`. Token is mandatory.
- **Bash everywhere:** scripts use `set -euo pipefail` and bash-only constructs (associative arrays, `[[ ... ]]`); do not rewrite them as POSIX sh.
- **Python ≥ 3.9 features** are used freely in the Python files (PEP 604 unions, `pathlib`).
- **License:** MIT (see `LICENSE`).
