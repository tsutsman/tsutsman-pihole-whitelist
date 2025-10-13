# tsutsman-pihole-whitelist

> The Ukrainian version of this description is available in [README.md](README.md).

This repository contains a basic list of domains you can whitelist in pihole.
The main list is stored in `whitelist.txt`, including addresses necessary for Microsoft OneDrive to work correctly.
Recently we added popular Ukrainian services so local sites and banks function without issues.
There is also support for major Apple services like iCloud and the App Store.
The list includes domains for Google Drive and MEGA to avoid blocking these cloud storages.
Synology hosts and common NTP servers are present for proper time synchronization.
Messaging platforms, additional cloud storages and Ukrainian banks are also covered.
A separate section lists Ukrainian government portals.

Each domain is accompanied by a comment with the date and reason for whitelisting for full transparency.

## Lists by category

Besides the combined `whitelist.txt`, the `categories/` directory contains individual files by topic.
You can import only the sets you need.

Available files include:

- `base.txt` — most frequently used domains;
- `apple.txt` — Apple service addresses;
- `microsoft_onedrive.txt` — Microsoft and OneDrive domains;
- `ukrainian_services.txt` — popular Ukrainian services and banks;
- `cloud_storage.txt` — cloud platforms (Google Drive, MEGA, Synology etc.);
- `messengers.txt` — domains for Telegram, WhatsApp, Discord;
- `smart_home_devices.txt` — Hikvision, Dahua, Yi Home cameras and the Tuya platform;
- `ntp_servers.txt` — NTP time servers;
- `gaming.txt` — domains for Steam, Epic Games, Riot, Blizzard and Wargaming;
- `web_resources.txt` — CDNs and hosts for website scripts and styles;
- `office_collaboration.txt` — Zoom, Slack and Microsoft Teams;
- `ai_services.txt` — popular AI services.
- `social_networks.txt` — major social networks.
- `streaming_services.txt` — video and music streaming platforms.
- `ecommerce.txt` — global e-commerce sites.
- `educational_resources.txt` — useful learning portals.
- `news_media.txt` — popular news websites.
- `international_banks.txt` — international payment services.

### Selective import and generation

Each file in `categories/` can be applied separately.

- **Through the web interface:** open **Whitelist**, choose **Import**, and upload the desired file, e.g. `categories/apple.txt`.
- **From the Linux command line:**
  - Pi-hole v5:
    ```bash
    xargs -a categories/apple.txt -L1 sudo pihole -w
    ```
  - Pi-hole v6:
    ```bash
    sudo pihole-FTL whitelist add $(cat categories/apple.txt)
    ```

To create a custom `whitelist.txt` from selected files or directories, pass them to the script. Comments and duplicates are removed automatically:

```bash
./generate_whitelist.sh categories/base.txt categories/apple.txt
```

The generated file can be imported by any of the methods above. If you prefer not to use the command line, download the needed files or the generated `whitelist.txt` and add them via the web interface.

## Generating the full list

The `generate_whitelist.sh` script creates `whitelist.txt` from all files in `categories/` or from provided arguments. It removes comments and blank lines, then deduplicates entries.

```bash
./generate_whitelist.sh              # all categories
./generate_whitelist.sh categories/cloud_storage.txt extra_dir/  # specific files or folders
./generate_whitelist.sh -o exports/custom.txt                   # save to a custom file
OUTFILE=exports/custom.txt ./generate_whitelist.sh              # alternative via environment variable
```

The resulting file is ready for import into pihole. If you specify a path with nested folders, they will be created automatically.

## External domain sources

To avoid hunting for additional domains manually, use the
`fetch_sources.sh` script. It reads a list of sources from
`sources/default_sources.txt` (or another file passed as an
argument), downloads them, and converts the content into a format
compatible with Pi-hole.

```bash
./fetch_sources.sh                     # default sources
./fetch_sources.sh my_sources.txt      # custom list
```

Each line in the sources file has the format `name|URL|comment`.
The name becomes the filename inside `sources/generated/` where the
processed domains are stored. After a successful run, the script
also creates `sources/generated/all_sources.txt` with the combined
output.

`generate_whitelist.sh` automatically picks up this file when
building the whitelist. To disable external sources or point to a
custom path, use environment variables:

```bash
INCLUDE_EXTERNAL_SOURCES=0 ./generate_whitelist.sh
SOURCES_COMBINED=custom.txt ./generate_whitelist.sh
```

## Usage

1. Copy `whitelist.txt` to your pihole server.
2. In the web interface, open **Whitelist** and import the domains from this file.
3. Or use the `apply_whitelist.sh` script, which reads a file (default `whitelist.txt`) and adds its domains to the whitelist:
   ```bash
   ./apply_whitelist.sh
   ./apply_whitelist.sh custom.txt  # another file
   ```
4. For automatic addition you can use pihole's API.
   Example request:
   ```bash
   curl -X POST "http://pi.hole/admin/scripts/pi-hole/php/whitelist.php" \
     -d "addfqdn=example.com" -d "token=YOUR_TOKEN"
   ```
5. Under **Adlists** you may add the raw file URL:
   https://raw.githubusercontent.com/tsutsman/tsutsman-pihole-whitelist/main/whitelist.txt
   so pihole can automatically fetch updates.

### Running alongside Dockerized Pi-hole

If Pi-hole runs inside Docker, you can reuse the same scripts without leaving the host system.

1. Clone the repository on the host that controls the container:
   ```bash
   git clone https://github.com/tsutsman/tsutsman-pihole-whitelist.git /srv/pihole-whitelist
   ```
2. Mount the repository inside the container. With `docker compose` it may look like this:
   ```yaml
   services:
     pihole:
       image: pihole/pihole:latest
       container_name: pihole
       volumes:
         - ./etc-pihole:/etc/pihole
         - ./etc-dnsmasq.d:/etc/dnsmasq.d
         - /srv/pihole-whitelist:/whitelist:ro
   ```
   The `/srv/pihole-whitelist` directory becomes `/whitelist` inside the container.
3. Generate the desired whitelist on the host (you may limit it to specific categories):
   ```bash
   cd /srv/pihole-whitelist
   ./generate_whitelist.sh --output exports/docker-whitelist.txt categories/base.txt categories/ukrainian_services.txt
   ```
4. Apply the whitelist from within the container:
   ```bash
   docker exec -u root pihole bash -lc '/whitelist/apply_whitelist.sh /whitelist/exports/docker-whitelist.txt'
   ```
5. Automate the flow with cron on the host:
   ```bash
   0 4 * * * cd /srv/pihole-whitelist && git pull --rebase && ./update_and_apply.sh && \
     docker exec -u root pihole bash -lc '/whitelist/apply_whitelist.sh /whitelist/whitelist.txt'
   ```

> **Tip.** Remove the `:ro` suffix if the container needs write access to `/whitelist` (for logs or temporary files) and ensure proper permissions.

## Automatic whitelist updates

The list can stay up to date in two ways.

1. **Add the URL to Adlists**
   Add the raw `whitelist.txt` URL in the **Adlists** section of the web interface or run:
   ```bash
   sudo pihole -a adlist add https://raw.githubusercontent.com/tsutsman/tsutsman-pihole-whitelist/main/whitelist.txt "tsutsman whitelist"
   sudo pihole updateGravity
   ```
   Each `pihole updateGravity` run (usually via cron) will fetch the latest list.

2. **Custom cron job**
   If needed, schedule `update_and_apply.sh` to run periodically:
   ```bash
   # daily at 03:00
   0 3 * * * /srv/pihole-whitelist/update_and_apply.sh >> /var/log/pihole-whitelist.log 2>&1
   ```
   The script downloads the latest `whitelist.txt`, applies it to Pi-hole, and logs the event. Adjust the source URL with `REPO_URL` and the log path with `LOG_FILE`.

## Checking the list

Before submitting a Pull Request, run `check_duplicates.sh`.
It checks for duplicates and verifies domain availability using `host` or `nslookup`.
You may pass specific files or directories, or nothing to process all lists.

```bash
./check_duplicates.sh categories/ukrainian_services.txt
./check_duplicates.sh whitelist.txt
./check_duplicates.sh                   # check everything
```

The script reports duplicates and unreachable domains. If you need to skip DNS checks (for example, in an offline environment), set `SKIP_DNS_CHECK=1`.
GitHub Actions performs the same check on each Pull Request, so failures will block the merge.
A weekly workflow also scans the lists and reports potential issues.

## Cleaning unreachable domains

The `cleanup_whitelist.sh` script periodically checks domains in the `categories` directory.
If a domain remains unreachable for several runs, it is moved to `categories/deprecated.txt` for review.
Behavior can be adjusted with environment variables:

- `CATEGORIES_DIR` — directory with lists (default `categories`);
- `STATE_FILE` — file storing the count of failed checks (default `cleanup_state.txt`);
- `THRESHOLD` — how many consecutive failures trigger removal to `deprecated.txt` (default `3`);
- `DEPRECATED_FILE` — file that collects removed domains (default `categories/deprecated.txt`).

```bash
THRESHOLD=2 ./cleanup_whitelist.sh
```

## Contributing

1. Fork the repository and create a dedicated branch.
2. Add domains to the appropriate file under `categories/` with a comment containing the date and reason.
3. Run `./check_duplicates.sh` with no parameters to ensure there are no duplicates or unreachable hosts.
4. Regenerate `whitelist.txt` via `./generate_whitelist.sh`.
5. Open a Pull Request summarizing your changes.

## License

All repository content is distributed under the MIT License. See `LICENSE` for details.
