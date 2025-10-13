# Plan for automating selective whitelist generation via web interface

> Ukrainian version: [docs/web_interface_plan.md](web_interface_plan.md)

## 1. User scenario and requirements

### Primary roles
- **Pi-hole administrator** — has access to the Pi-hole web interface and manages the whitelist.
- **List editor** — maintains domain categories in the Git repository and can export curated lists for administrators.

### Key scenario
1. A user opens the Pi-hole web interface and goes to the new “Whitelist Builder” section.
2. The interface loads the list of available categories from the repository or the local `categories/` directory.
3. The user selects the necessary categories (one or more) and additional processing options.
4. After clicking “Generate,” the backend creates a temporary whitelist file.
5. The user can:
   - download the generated file;
   - preview the resulting domains (with pagination and search);
   - immediately apply the whitelist to Pi-hole.
6. Results are logged and the user sees a success or error message (e.g., missing category files).

### Required options
- Category selection via checkboxes with brief descriptions.
- Ability to add a custom file/directory (path on the server) to the generation process.
- Toggle “Include external sources” (mirrors the `INCLUDE_EXTERNAL_SOURCES` environment variable).
- Field for an alternative combined source file (`SOURCES_COMBINED`).
- “Clear selection” button to reset the form quickly.
- Indicator showing the number of domains in each category (from a precomputed index or on-the-fly calculation).

### Non-functional requirements
- **Security:** only authenticated Pi-hole users can access the section.
- **Performance:** generate lists in under 5 seconds for up to 10,000 domains.
- **Audit:** log every operation to `/var/log/pihole-whitelist-builder.log` with user information and parameters.
- **Extensibility:** add new categories without code changes by auto-scanning directories.

## 2. API and backend script

### Architecture
- The web interface calls Pi-hole CGI or REST endpoints implemented in bash or Python.
- Core logic lives in the new `build_whitelist.sh` script, which reuses `generate_whitelist.sh`.

### Directory structure
```
/opt/pihole-whitelist-builder/
├── build_whitelist.sh
├── api/
│   ├── index.cgi       # thin CGI wrapper
│   └── whitelist_api.py
├── templates/
│   └── form.html
└── data/
    └── exports/
```

### API endpoints
- `GET /api/categories` — returns a JSON list of categories with descriptions, domain counts, and last updated timestamps.
- `POST /api/generate` — accepts JSON payload with selected categories, optional additional paths, and toggles for external sources; returns the name of the generated file.
- `POST /api/apply` — applies the generated whitelist immediately and returns the command output.

### Backend script responsibilities (`build_whitelist.sh`)
1. Parse input parameters, validate paths, and convert relative paths to absolute ones.
2. Build argument lists for `generate_whitelist.sh`, including external source inclusion/exclusion.
3. Create a temporary workspace, run `generate_whitelist.sh`, and store artifacts under `data/exports/`.
4. Optional: invoke `apply_whitelist.sh` when the API request asks to apply the list immediately.
5. Produce structured logs with timestamps, user identifiers, and selected categories.

## 3. Frontend requirements
- Implement as a lightweight HTML page with vanilla JS or Alpine.js.
- Provide responsive layout (desktop/tablet/mobile) with accessible components.
- Display a summary panel: number of selected categories, total domains (approximation), status of the last generation.
- Offer quick filters (e.g., search by category name, tags).
- Show detailed logs or errors in a collapsible panel.

## 4. Deployment and integration
- Place the project under `/opt/pihole-whitelist-builder` with symlinks to Pi-hole directories as needed.
- Integrate with Pi-hole authentication (reuse sessions or implement HTTP Basic on the CGI endpoints).
- Provide systemd service or timer to clean up old exports and refresh category metadata.
- Extend CI to run smoke tests for the API endpoints and lint the frontend assets.

## 5. Next steps
1. Finalize API data contracts and update tests under `tests/` to cover new endpoints.
2. Prepare a migration guide for existing users (steps to install, configure, and roll back).
3. Add monitoring for API errors and usage metrics to evaluate adoption.
