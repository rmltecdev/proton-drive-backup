# Proton Drive Backup — Read Me

```card
   ≡ Proton Drive Backup ≡
 
   ● All dependencies satisfied.
   ● Checking authentication session...
   ● Session is valid.
   ● Backup Configuration
     ├ Conflict strategy        replace
     ├ Delete mode              trash
     ├ Dry run                  true
     ╰ Reset checksum database  false
  ● Building lookup table from previous database...
  ● Building local checksum database:
    ▶ Scanning /home/martin/Documents...
    ▶ Scanning /home/martin/Music...
    ▶ Scanning /home/martin/Pictures...
    ▶ Scanning /home/martin/Projects...
    ▶ Scanning /home/martin/Templates...
    ▶ Scanning /home/martin/Videos...
  ● Database built: 11764 files, 309GiB total.
  ● Comparing local files against previous backup state...
 
  ▶ Processing 1460/11764 (32GiB) ▓▓░░░░░░░░░  12% ETA 2026-10-20 18:30
```

#### Table of Contents
* [Purpose](#purpose)  
* [Features](#features)  
* [Philosophy](#philosophy)
* [Requirements](#requirements)  
* [Installation](#installation)  
* [Configuration](#configuration)  
* [Quick Start](#quick_start)  
* [Usage](#usage)  
* [Logging](#logging)  
* [Localization](#localization)  
* [Known Limitations](#known-limitations)  
* [Security Notes](#security-notes)  
* [Troubleshooting](#troubleshooting)  
* [Contributing](#contributing)  
* [Help](#help)  
* [Appendix](#appendix)  

## Purpose

One-way backup tool that mirrors local directories to Proton Drive using the official Proton Drive CLI.  

> **Disclaimer** — This is an unofficial community tool.
> RML Tec Dev is not affiliated with, endorsed or supported by Proton AG.
> "Proton Drive" is a trademark of Proton AG. Proton AG is not responsible for this tool's functionality or maintenance.

## Philosophy

In traditional Japanese aesthetics, the *wabi-sabi* (侘び寂び) concept centers on the acceptance of transience and imperfection. Prevalent in many forms of Japanese art, it describes beauty as "imperfect, impermanent, and incomplete."

Our design philosophy embraces this principle: network instability, mount failures, and transient errors are not fought but accepted. To ensure resilience, we implemented **retry queues** for graceful handling of upload failures, **commit points** that prevent corrupted baselines, and **silent update checks** that fail without disrupting backup runs. The result is a tool that works reliably even when the world around it does not.

## Features

* One-way synchronization: local system is the single source of truth — this tool never deletes, moves, or modifies local files  
* MD5-based change detection against a persistent local JSON database  
  (no remote hash data required).  
* Upload conflict strategies: `replace` or `skip`.  
* Orphan handling: recoverable trash or permanent deletion.  
* Cron scheduling with configurable interval.  
* Run-scoped logging with automatic archiving and retention.  
* English, German and Thai localization.  
* Graceful terminal-resize degradation; no data loss on interrupted runs (instance locking via PID-validated lock file).  

## Requirements

* An authenticated Proton Drive account (login handled interactively on first run)  
* `proton-drive` CLI v0.4.6 or higher (https://proton.me/drive/cli)  
* `jq`, `md5sum`, `tar`, GNU `find`, `curl`  
* bash 4.2 or higher   

## Installation

`./install.sh`

The installer places the script on your PATH and copies the example configuration to `~/.config/proton-drive-backup/proton-drive-backup.cfg` on first installation. Existing configurations are never overwritten — updates never destroy user settings.  

## Configuration

All user decisions live in the config file above.  

**Key variables**  

| *Variable*                 | *Values*            | *Description*                       |
|----------------------------|---------------------|-------------------------------------|
| `SOURCE_BASE`              | path                | Base directory for relative entries |
| `SOURCE_DIRS`              | list of paths       | Directories to back up              |
| `REMOTE_BASE_PATH`         | `/my-files/...`     | Remote target folder                |
| `DELETE_MODE`              | `trash` \| `delete` | Orphan handling (default: `trash`)  |
| `UPLOAD_CONFLICT_STRATEGY` | `replace` \| `skip` | Remote name collisions              |
| `CRON_INTERVAL_MINUTES`    | positive integer    | Interval for `--schedule`           |
| `KEEP_LOG_RUNS`            | integer             | Archived runs retained              |

**Recommendation**  
Keep `DELETE_MODE=trash`. It is deliberately the default — a brake instead of a brakeless delete. Clear the Proton Drive trash periodically after verifying your backups.  

## Quick Start

1. First contact: see what would happen — nothing is executed  

```bash
   proton-drive-backup --dry-run
```

2. Then run for real  

```bash
   proton-drive-backup --verbose # to observe progress
   proton-drive-backup --quiet   # to automatize as cron job
```

3. Follow what the tool does  

```bash
   proton-drive-backup --log
```

## Usage

Invoked without options, the tool shows a status menu.  

| *Option*       | *Description*                                       |
|----------------|-----------------------------------------------------|
| `--checksum`   | Forces a full MD5 re-hash of all files, bypassing the `size`+`mtime` fast path. Use only when suspecting corruption or after manual DB edits. |
| `--dry-run`    | Display pending changes; no action taken            |
| `--help`       | Man-page style help; quits with Q                   |
| `--log`        | Open and follow the runtime log                     |
| `--quiet`      | Minimal output for cron jobs (errors + summary)     |
| `--reset-db`   | Discard and rebuild the checksum database           |
| `--schedule`   | Install cron job. Interval from config; default: daily 1440-minute intervall; 300-minute interval suitable for high-frequency setups; weekly 10080-minute intervall recommended for multi-TiB datasets. |
| `--unschedule` | Remove the cron job                                 |
| `--verbose`    | Progress indicators during processing               |
| `--version`    | Version and CLI information                         |

## Logging

Logs are run-scoped and live in `~/.local/state/proton-drive-backup/`. At the start of each run, the previous run's logs are archived as a timestamped `<UTC-stamp>.tar.gz`; the newest `KEEP_LOG_RUNS` archives are retained.  

Inspect an archive without extracting:  
`tar -xzOf <stamp>.tar.gz`

## Localization

Language files ship next to the script (`proton-drive-backup.en`, `proton-drive-backup.de`, `proton-drive-backup.th`). Language selection follows your `LANG` environment variable. Column alignment requires a generated UTF-8 locale (e.g. `de_DE.UTF-8`) — see [FAQ](FAQ.md).  

Contributing a translation: see [MESSAGES](MESSAGES.md).  

## Known Limitations

* Renamed files appear as *delete* and *upload*; in trash mode they accumulate in the Proton Drive trash until it is cleared manually.  
* Empty remote directories are not removed (CLI limitation).  
* MD5 comparison is content-based; it is not a cryptographic guarantee against deliberate collisions.  
* Thumbnail uploads are skipped (`--skip-thumbnails`).  

## Security Notes

* The tool only *reads* local files (hashing and uploading). Deletion happens exclusively on the remote side, for files you deleted locally yourself.  
* Credentials remain exclusively in the official Proton Drive CLI — this script never reads or stores them.  
* The lock file prevents concurrent runs from interleaving operations.  
* Review the locale and config files before use: they are sourced as Bash (documented in each file's header).  

## Troubleshooting

See [FAQ](FAQ.md) for common issues (misaligned columns, locale generation, terminal resize behavior, cron environments).  

## Contributing

PRs welcome — see [CONTRIBUTING](CONTRIBUTING.md) for code style, localization rules, and testing requirements (clean shellcheck, passing smoketest).  

## Help  

The script includes a built-in "Man Page" style help viewer.  

* Invoke via: `./proton-drive-backup --help`  
* It pipes localized documentation into the `less` pager, allowing for scrolling and searching within the help text.  

## Appendix

### Disclaimer

Use at your own risk. Test thoroughly; files deleted locally are removed from your Proton Drive backup during the next run.  
This script is provided "as is"; there is NO WARRANTY at all.  
This is free software: you are free to modify it to your needs and redistribute it under the MIT License.  

### Author

Copyright (c) 2026 RML Tec Dev  
Contributions and feedback are welcome via [rmltecdev@pm.me](mailto:rmltecdev@pm.me?subject=proton-drive-backup).  

### License

Licensed under the MIT License — see [LICENSE](LICENSE) for details.  

### Version

Version: v1.2.0  
Build Date: 2026-10-07  
