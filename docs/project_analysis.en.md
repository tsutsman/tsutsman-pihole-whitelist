# Project status analytical report

> Ukrainian version: [docs/project_analysis.md](project_analysis.md)

## 1. Purpose and context
- The repository distributes ready-to-use domain whitelists for Pi-hole along with automation scripts that fetch, clean, and apply the data. The main `whitelist.txt` file acts as a combined list, while the `categories/` directory contains themed subsets for selective imports.
- Maintenance is performed in both Ukrainian and English. The main usage guide lives in `README.md` and covers Pi-hole v5/v6 examples, automation scripts, and external source integration, ensuring an accessible onboarding process for administrators.

## 2. Structure and key components
- **Static data:** `whitelist.txt` (904 domains) plus 26 themed files in `categories/*.txt`, including the largest collections `extended_services.txt`, `apple.txt`, `ukrainian_services.txt`, `microsoft_onedrive.txt`, and `gaming.txt`.
- **Primary scripts:**
  - `generate_whitelist.sh` — builds the combined whitelist, supports selective arguments, environment variables, and the `--output` option for custom destinations.
  - `apply_whitelist.sh` — applies the list to Pi-hole, auto-detects v5/v6 commands, skips comments/blank lines, and records errors.
  - `build_whitelist.sh` — wrapper for interactive flows; accepts category lists, extra paths, and can call `apply_whitelist.sh` immediately.
  - `fetch_sources.sh` — downloads external whitelists, normalizes formats (uBlock, hosts, dnsmasq), and aggregates them into `sources/generated/all_sources.txt`.
  - `cleanup_whitelist.sh` — checks domain availability, keeps failure counters, and moves problematic entries into `deprecated.txt` once they hit the threshold.
  - `check_duplicates.sh` — finds duplicates and optionally validates DNS entries, respecting the `SKIP_DNS_CHECK` flag.
  - `sort_categories.sh` — sorts category files while keeping header comments intact.
  - `update_and_apply.sh` — downloads the latest whitelist from GitHub, applies it locally, and logs the operation.
- **Documentation:** `docs/web_interface_plan.md` outlines the target web interface for selective whitelist generation and backend requirements.

## 3. Data and sources
- `whitelist.txt` currently stores 904 active records after deduplication and sorting. The generated file receives an automated header and excludes comments.
- The `categories/` directory covers 26 themed sets, enabling tailored whitelists for specific scenarios. The largest sets are `extended_services.txt` (212 domains), `apple.txt` (111), `ukrainian_services.txt` (61), `microsoft_onedrive.txt` (56), and `gaming.txt` (34).
- `sources/default_sources.txt` links external whitelists (e.g., AnudeepND). They are normalized into a unified format and can be toggled via environment variables in `generate_whitelist.sh`.

## 4. Automation, tests, and CI
- The `tests/` directory contains integration scenarios for the main scripts (generation, application, external downloads, sorting, updates). These tests emulate external dependencies (such as `pihole` commands and network calls) to cover essential logic branches.
- `.github/workflows/duplicate_check.yml` validates duplicates and whitelist freshness during pull requests, while `weekly_check.yml` performs scheduled diagnostics and opens issues for inaccessible domains.
- `ci.yml` executes every script under `tests/`, acting as a smoke test for REST API stubs, shell utilities, and static analysis before merging.
- Coverage metrics and performance benchmarks are absent. Tests focus on shell workflows; they do not cover the unimplemented web interface and lack trend statistics for domain status changes.

## 5. Strengths
- Detailed documentation with automation examples (`README.md`) and a forward-looking plan for a web interface.
- Comprehensive toolbox for list maintenance: generation, sorting, duplicate detection, cleanup, remote updates, and multi-format exports via `export_whitelist.sh` for AdGuard Home and pfBlockerNG.
- Active CI workflows monitoring whitelist quality plus scheduled availability checks.
- Integration tests protect the critical shell script scenarios, lowering regression risk.

## 6. Gaps and risks
- No centralized metrics for tracking active/removed domains, fetch failure frequency, or other operational KPIs, which complicates planning.
- The project relies on external sources without caching or mirrors, so third-party outages block updates.
- There is no automated validation of category metadata (descriptions, authorship, review dates) and no tool to semi-automate comment updates explaining why domains were whitelisted.
- The web interface plan remains unimplemented; backend and user testing are missing, slowing adoption.

## 7. Roadmap
### Phase 0–1 month
1. Add a category and external source statistics report (domain counts, unavailable share, last check date) exported into `docs/`.
2. Automate caching and retries for `fetch_sources.sh` to reduce transient failures.
3. Extend tests for `cleanup_whitelist.sh` and `check_duplicates.sh`, including flag usage and concurrent scenarios.

### Phase 1–2 months
1. Implement the CLI/API capabilities described in `docs/web_interface_plan.md`: complete `build_whitelist.sh`, add REST/CGI endpoints, and deliver a basic web form for selective whitelist building.
2. Integrate new features into CI (e.g., web endpoint smoke tests, REST API validation, dry-run execution of `apply_whitelist.sh`).
3. Prepare deployment guidelines for the web interface (update README, add a dedicated section in `docs/`).

### Phase 2–4 months
1. Introduce metadata fields for categories (description, owner, review date) and enforce their presence via automated checks.
2. Build a monitoring dashboard (GitHub Pages or HTML report) with domain count trends and a removal log.
3. Establish contribution workflows for suggesting/reviewing domains via pull request templates and automated comment validation.

### Phase 4+ months
1. Explore integrations with other DNS filtering solutions (AdGuard Home, pfBlockerNG) and add export formats.
2. Consider a lightweight database (SQLite) to store domain check history and analytics with CSV/JSON exports.
3. Conduct user research for the web interface, collect feedback, optimize UX (search, grouping, saved profiles), and design A/B experiments to validate usability improvements.
