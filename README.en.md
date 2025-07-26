# tsutsman-pihole-whitelist

This repository contains a basic list of domains you can whitelist in pihole.
The main list is stored in `whitelist.txt`, including addresses necessary for Microsoft OneDrive to work correctly.
Recently we added popular Ukrainian services so local sites and banks function without issues.
There is also support for major Apple services like iCloud and the App Store.
The list includes domains for Google Drive and MEGA to avoid blocking these cloud storages.
Synology hosts and common NTP servers are present for proper time synchronization.
Messaging platforms, additional cloud storages and Ukrainian banks are also covered.
A separate section lists Ukrainian government portals.

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

## Generating the full list

Run `generate_whitelist.sh` to create `whitelist.txt` from all files in `categories/`.
It removes comments and blank lines, then deduplicates entries.

```bash
./generate_whitelist.sh
```

The resulting file is ready for import into pihole.

## Usage

1. Copy `whitelist.txt` to your pihole server.
2. In the web interface, open **Whitelist** and import the domains from this file.
3. For automatic addition you can use pihole's API.
   Example request:
   ```bash
   curl -X POST "http://pi.hole/admin/scripts/pi-hole/php/whitelist.php" \
     -d "addfqdn=example.com" -d "token=YOUR_TOKEN"
   ```
4. Under **Adlists** you may add the raw file URL:
   https://raw.githubusercontent.com/tsutsman/tsutsman-pihole-whitelist/main/whitelist.txt
   so pihole can automatically fetch updates.

## Checking the list

Before submitting a Pull Request, run `check_duplicates.sh` on any list you changed:

```bash
./check_duplicates.sh categories/ukrainian_services.txt
./check_duplicates.sh whitelist.txt
```

The script reports any duplicate lines it finds.
GitHub Actions runs the same check on each Pull Request, so duplicates will cause a failure.
A weekly workflow also checks the lists and reports potential issues.

## Contributing

1. Fork the repository and create a dedicated branch.
2. Add domains to the appropriate file under `categories/` with a comment containing the date and reason.
3. Run `./check_duplicates.sh` with no parameters to ensure there are no duplicates or unreachable hosts.
4. Regenerate `whitelist.txt` via `./generate_whitelist.sh`.
5. Open a Pull Request summarizing your changes.

## License

All repository content is distributed under the MIT License. See `LICENSE` for details.
