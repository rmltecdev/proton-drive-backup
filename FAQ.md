# Proton Drive Backup — Frequently Asked Questions (FAQ)

#### Table of Contents

[General](#general)  
[Philosophy and Design](#philosophy-and-design)  
[Network and Connectivity](#network-and-connectivity)
[Sizing and Fair Use](#sizing-and-fair-use)  
[Localization and Display](#localization-and-display)  
[Cron Jobs](#cron-jobs)  
[Logs](#logs)  
[Console Output](#console-output)  
[Should I use --verbose or --quiet?](#should-i-use)  
[Headless Server Authentication](#headless-server-authentication)  
[Using `--checksum` Flag](#using-checksum-flag)  
[Understanding `--reset-db` Behavior](#understanding-reset-db-behavior)  
[Dry-Run Mode Limitations](#dry-run-mode-limitations)  
[Technical Decisions](#technical-decisions)
[Who is liable for data loss?](#who-is-liable-for-data-loss)  
[Can I modify the script?](#can-I-modify-the-script)  
[Legal and Modification](#legal-and-modification)  

## General

### Is this an official Proton tool?

No. This is an unofficial community tool by RML Tec Dev. It is not affiliated with, endorsed by, or supported by Proton AG. "Proton Drive" is a trademark of Proton AG. Proton AG is not responsible for this tool's functionality or maintenance.  

### Can this tool delete my local files?

No — never. The tool only *reads* local files (hashing, comparison, upload). All deletions happen exclusively on the remote Proton Drive side, and only for files you have deleted locally yourself. Start with `--dry-run` to preview every pending action.  

## Philosophy and Design

### Why does my backup "skip" files that are missing on the remote?

The delete phase probes every orphan candidate before acting. If the file is already gone on the remote (removed by hand, by another client, or a previous interrupted run), there is nothing to trash or delete — the run records this as a benign skip, not an error. No local data is affected; the remote and the local database simply agree again after this run.  

### Why does the script refuse to run when the scan finds no files?

A zero-file scan almost always means something is broken: a forgotten mount, a typo'd path, a renamed directory. Continuing would classify EVERY previous entry as an orphan and trash or delete the ENTIRE remote backup. Both cases fail closed:  

- previous database present → abort (data protection)  
- first run or --reset-db → abort (refuses to create a meaningless empty baseline)  

There is deliberately no override flag. Intentional emptying is a configuration edit followed by manual cleanup — never a flag that a Friday-evening cron job could trip over.  

### Why does a missing configured directory abort the whole run?

Same reasoning as the empty-scan gate, one level earlier: if a `SOURCE_DIR` is missing, the scan sees fewer files and the delete phase would "correct" the remote accordingly. Warning and continuing would silently produce partial backups. The run names the missing directory and the configuration file, and exits.  

### Why is deleting slower than uploading?

Permanent deletion (`DELETE_MODE=delete`) is Proton Drive CLI's mandatory two-step: trash first, then purge the trashed node. Each orphan costs multiple API roundtrips. Trash mode is a single step. Expect delete phases with many orphans to take visibly longer than uploads of the same count. This is a documented CLI limitation.  

### The delete progress bar shows "(0B)" — is something wrong?

No. The delete phase moves references, not bytes — nothing is transferred. The byte counter is structurally part of the bar layout and legitimately reads zero here.  

### Why does the tool put orphaned files in the trash instead of deleting them?

The default `DELETE_MODE=trash` keeps every removal recoverable. Deleted-then-restored mistakes are cheap; permanently lost backups are not. Clear the Proton Drive trash periodically after verifying your backups.  
Switch explicitly to `DELETE_MODE=delete` if you prefer automatized, permanent removal.  

### Renaming a file fills my trash — why?

Renaming is not atomic in the CLI world: it registers as delete plus upload. In trash mode the old copy lands in the trash on the next run. This is expected behavior, not a bug — empty the trash as part of your periodic hygiene. This is a documented CLI limitation.  

### Why are empty remote folders not cleaned up?

The official Proton Drive CLI does not offer recursive folder deletion of empty directories. This is a documented CLI limitation.  

### Why are some error messages not translated?

Deliberately. USER-correctable problems (configuration values, setup mistakes) are localized because the reader acts on them in their own language. SYSTEM-level failures (mktemp, move, commit) speak English in console AND log alike — they are developer-facing, rare, and keeping both surfaces identical makes grep-based diagnosis trivial.  

### Why does `--help` or `--version` fail with a configuration error?

The script validates its entire configuration contract before any mode runs — a partially working script that fails mid-operation is worse than one that refuses to start. Fix the reported config value (see the example config), then all modes become available at once.  

## Network and Connectivity

### Why does the update check sometimes fail silently?

The GitHub Releases API is unreachable approximately 3% of the time in my environment (31 failures over a multi-day run). No warning appears on the console; the log contains `Update check: no release metadata received.` This is intentional design: the script treats network unreliability as a transient condition, not a fatal error. The backup continues unaffected; the version check simply yields no result for that run. Future runs may succeed where earlier ones failed.  

**Should I report this as a bug?** Only if failures persist beyond several days despite stable internet connectivity. Occasional timeouts are expected behavior for external APIs.  

## Sizing and Fair Use

### Can I back up my full 2 TB storage?

Basically, yes. Though, this tool is a curator's backup for selected data, not a terabyte vault. Each run compares file size and `mtime` against the local database first; only new or changed files are hashed (MD5). Unchanged files are recognized by metadata alone, keeping scans proportional to disk reads, not content volume. A very large data set therefore means a long scan on every run, and Proton's fair use policy applies on the remote side as well.  
Proton's official guidance for the Drive CLI: "To stay within limits, only upload or download what has actually changed — don't reupload the same files repeatedly or rewrite entire folders." This tool implements exactly that by design: only new or changed files are uploaded; unchanged files are skipped entirely.    
If your data set grows into terabytes, consider splitting: curated documents via this tool, bulk media archives via dedicated bulk storage.  

### My first run is slow — is that normal?

Yes. The first run builds the checksum database, which reads and hashes every configured file once. Subsequent runs perform a metadata-only pass (one stat per file) plus hashing of changed files only.  

## Localization and Display

### My table columns are misaligned under non-English messages

Any language whose text contains multibyte UTF-8 glyphs…  

* umlauts (e.g. Finnish, German, Hungarian, Turkish),  
* ligatures (e.g. Danish, German, Norwegian, Swedish),  
* diacritics (e.g. Czech, French, Icelandic, Portuguese, Romanian, Spanish),  
* combining marks (e.g. Khmer, Lao, Thai)  

…can shift column alignment when the system locale is missing or misspelled. First check that your locale actually exists and is generated:  

`locale -a | grep -i "<lang>"`

If `de_DE.utf8` is missing, enable it in `/etc/locale.gen` (remove the `#` in front of `de_DE.UTF-8 UTF-8`) and run `sudo locale-gen`.  

### I set `LANG=de-DE.UTF-8` and nothing changed — why?

Underscore, not hyphen: the locale name is `de_DE.UTF-8`. An invalid locale name fails silently — the script still runs, but character counting falls back to byte counting, which breaks column alignment. This failure mode produces no error message; that is shell behavior, not a bug in the script.  

### Why do umlauts break `printf` alignment at all?

Because three different units are involved: `printf` measures BYTES in field widths, `${#var}` counts CHARACTERS, and the terminal renders COLUMNS. A single UTF-8 umlaut is 2 bytes, 1 character, 1 column. The tool therefore routes all alignment through its own `pad_to()` helper, which counts columns-aware. Third-party patches should do the same — see MESSAGES.md.  

## Cron Jobs

### The cron job starts but fails with an authentication error

Cron runs without your desktop session environment. The script already exports the D-Bus session address for credential access, but if you logged in per-user: verify the cron user matches the user who authenticated the Proton Drive CLI. Run the script once manually (no `--quiet`, use `--verbose` instead) to trigger interactive login.  

## Logging

### Where are my old logs?

At the start of each run, the previous run's logs are archived as `<UTC-stamp>.tar.gz` in `~/.local/state/proton-drive-backup/`. Read an archive without extracting:  

`tar -xzOf <stamp>.tar.gz`

Retention is controlled via `KEEP_LOG_RUNS` in the config file.  

### Does `--quiet` affect the log file?

No. Quiet mode changes TERMINAL OUTPUT ONLY — progress and
per-file lines are suppressed; banner, configuration and the final summary remain visible. The runtime log always receives the complete English record, independent of console verbosity. For cron, prefer `--quiet`: terminal rendering dominates runtime on small runs, not the log.  

### My old log shows double slashes in remote paths (e.g.
`/my-files/backup//file.jpg`). Do I have a path bug?

Most likely a healed data echo, not a construction bug: file names containing control characters (a stray newline in a directory name — ext4 permits this) split into fragments during line-oriented reading and produced malformed path joins once. Rename the directory, run once — the fragments age out with the next database generation. Renaming to plain ASCII names is strongly recommended for anything a backup tool processes.  

## Console Output

### Backup Summary

### Why does the backup summary show "Pending in retry queue" — is my backup incomplete?

A pending entry means a file hit a transient error during upload (network drop, server-side 500 responses) and was queued for a retry in the next run. The affected run may report "Backup completed with errors" — but nothing is lost: the checksum database committed only files whose upload was actually confirmed.  
The number is a promise, not noise: as long as `Pending in retry queue` is greater than zero, the backup set is not yet complete on the remote. The next run drains the queue in its retry pre-pass (visible in the log as "Retried successfully"). Typical lifetime of an entry is exactly one run — a Monday network hiccup is uploaded by the following scheduled run.  
An entry that stays pending across multiple runs signals that its underlying error is not transient. Inspect the record in `~/.config/proton-drive-backup/proton-drive-backup.retry` (four tab-separated fields: path, attempts, first_seen, last_error) and the corresponding `[ERROR]` lines in the runtime log. Manual editing of the file is possible (plain TSV), but is a diagnostic path — not a supported workflow for regular operation.  

### Progress Display

#### The delete progress shows `(0B)` — is nothing being freed on Proton Drive?

Expected behavior, not a defect. The size segment tracks bytes *transferred*, and deletions transfer nothing. Orphaned files exist only on the remote, so at deletion time the tool knows their paths but not their sizes. Displaying them would require looking up and accumulating sizes from the previous state database inside the delete loop — complexity we deliberately rejected for a cosmetic figure.  
Operationally: removed files are moved to the Proton Drive trash (or permanently deleted, depending on configuration). Trashed files still count toward the Proton Drive quota until the trash is emptied; the Proton Drive web UI shows the authoritative figures (see above).  

#### The progress bar disappeared after I resized the terminal

Expected behavior by design. A resize invalidates the cached terminal geometry the progress bar depends on. Instead of guessing, the tool disables the display, prints a warning, and continues in quiet mode. Progress remains observable in the logs; follow them live with `proton-drive-backup --log` or `tail -f` on the transfer log.  

## Should I use `--verbose` or `--quiet`?

- Use `--verbose` for **manual runs** — visualizes transparent progress feedback.  
- Use `--quiet` for **cronjobs** — minimizes I/O and keeps terminal clean.  

For initial backups or after a `--reset-db`, always use `--verbose` to verify the upload is proceeding correctly.  

## Headless Server Authentication

### My `proton-drive auth login` fails with `ERR_SECRETS_PLATFORM_ERROR` or "locked collection"

On systems without a graphical login session (headless servers), the GNOME Keyring/Secret Service may not be initialized. This is common on SSH-only environments.  

#### Symptoms

* `secret-tool store` fails with "Object does not exist" or "locked collection"  
* `proton-drive auth login` fails with `ERR_SECRETS_PLATFORM_ERROR` (timeout) or "Cannot create an item in a locked collection"  

#### Root Cause

No active D-Bus user session and/or no initialized `login` keyring collection. Credentials are machine-local; login on one system does not propagate to others.  

#### Solution

1. Enable persistent user sessions (for cron compatibility):  

```bash
    sudo loginctl enable-linger <username>
```

2. Initialize the keyring with an empty passphrase (recommended for headless/CI):  

   * Stop all existing daemon instances:  

```bash
    systemctl --user stop gnome-keyring-daemon.service
    pkill -u <username> -f gnome-keyring-daemon
```

   * Create isolated session and initialize:  

```bash
   dbus-run-session -- bash -c '
       echo -n "" | gnome-keyring-daemon --unlock --components=secrets
       secret-tool store --label="test" test test
       secret-tool lookup test test && echo VERIFIED
   '
```

   The empty passphrase means the keyring unlocks automatically on every daemon restart — acceptable for LAN home servers, evaluate security trade-offs for exposed systems.  

3. Start the daemon via systemd user service:  

```bash
   systemctl --user enable gnome-keyring-daemon.service
   systemctl --user start gnome-keyring-daemon.service
```

4. Verify and login:  

```bash
   secret-tool lookup test test    # Should return "test"
   proton-drive auth login    # Copy URL to a browser with JavaScript support
   proton-drive filesystem list /my-files --json
```

**OAuth Browser Limitation**

Proton Drive CLI may attempt to launch an incompatible text browser (e.g., Links) on headless systems. Copy the authorization URL and paste it into a modern browser (Firefox, Chrome, Chromium) on any device with JavaScript enabled. Completion registers the credential on the server automatically.  

**Post-Reboot Behavior**

With an empty-passphrase keyring, the `login` collection unlocks automatically on daemon restart. If `systemd --user` is configured correctly (`enable-linger`), cron jobs continue without manual intervention. Verify with:  

   * Close all SSH sessions, reconnect, then immediately:  

```bash
   proton-drive filesystem list /my-files --json
```

## Using `--checksum` Flag

### When should I use `--checksum`?

Under normal operation, omit this flag. The `--checksum` option forces a full MD5 re-hash of all files, bypassing the `size`+`mtime` fast path.  

#### Use cases

* Suspected file corruption (fast path trusts unchanged metadata)  
* Modified mtime without content change (restored from archive, rsync without preserve flags)  
* Manual database edits requiring re-verification  
* Performance benchmarking (comparing full hash vs. fast path)  

#### Expected behavior

Fast path reused stored MD5 for 0 of N files.  

Even unchanged files will be hashed; upload phase skips duplicates via MD5 comparison.  


## Understanding `--reset-db` Behavior

### What happens with `--reset-db`?

The `--reset-db` flag discards the local checksum database and rebuilds it from scratch. All files are re-hashed, and if remote state differs from the newly computed database, a full re-upload occurs.  

> [!Warning]
> On large datasets with slow connections, `--reset-db` may trigger extensive uploads of unchanged files if the remote backend still holds previous versions.

**Recommended usage**  

```bash
   ./proton-drive-backup --reset-db --verbose
```

Combine with `--verbose` for progress display; without it, the run proceeds silently (errors logged, summary printed).  

**Use cases**  

* After manual database corruption  
* Switching source directories  
* Verifying integrity after suspected tampering  
* Clean slate for migration/testing  

## Dry-Run Mode Limitations

### Does `--dry-run` require authentication?

Yes. While `--dry-run` performs no network uploads, it still validates the Proton Drive session to ensure credentials exist for a potential production run.  

**Common confusion**  
Users expect dry-run to show a purely offline preview without login. This is by design — dry-run tests the complete workflow except for mutation, helping catch credential issues before real runs.  

**Note**  
Folder creation messages in dry-run are hypothetical (e.g., "[DRY-RUN] Would create folder"). Existence is not verified without network calls.  

## Technical Decisions

### Why `set -u` without `set -e`?

The script uses `set -uo pipefail` (explicit `set -u`, omitted `-e`). This deviation from the common `set -euo pipefail` is deliberate:  

* `-u`: catches undefined variable references — critical for config validation and safe defaults  

* No `-e`: allows fine-grained error handling (per-file recovery, counters, graceful degradation)  

Per project guidelines, an undocumented deviation is a defect, a documented one is a decision — this is the documented one.  

### Why is config validation performed before mode dispatch?

Configuration contract validation (checking `DELETE_MODE`, `UPLOAD_CONFLICT_STRATEGY`, `CRON_INTERVAL_MINUTES`, etc.) runs immediately after argument parsing, before any operational mode (backup, menu, help) executes.  

**Rationale**

* Invalid config aborts the entire program early with localized error messages  
* Prevents partial execution (e.g., menu displayed, then crash on invalid state)  
* Ensures deterministic failure for debugging  

This ordering is explicit in the `main()` function structure.  

## Legal and Modification

### Who is liable for data loss?

**You are.** This script is provided "as is" under the [MIT License](LICENSE) with **no warranty whatsoever**. As a user, you are solely responsible for your own data and, where applicable, for any customer or third-party data stored on the system this script manages.  
Neither RML Tec Dev nor Proton AG is liable for lost data, lost profits, or any damages arising from the use of this software. That is the deal of free software: you gain full control, and with it full responsibility.
If your system handles critical or regulated data, implement your own backup and redundancy strategy. See [LICENSE](LICENSE) and the `DISCLAIMER` section in [README.md](README.md) for the full legal text.  
Mitigate sensibly:  
Preview every change with `--dry-run`, keep `DELETE_MODE=trash` until you trust your setup, verify backups after the first runs, and clear the remote trash only after checking.  

### Can I modify the script?

Yes — that is the point of the MIT License: study it, change it, redistribute it, in private or commercially. Two asks come with it:  

(a) review the locale and config files before you source them (these files are executable Bash), and  

(b) if your modification fixes a bug others share, consider contributing it back — the project stays alive through returned improvements. See [CONTRIBUTING](CONTRIBUTING.md) for the workflow.  

---

*Last updated: 2026-11-27*
*Author: RML Tec Dev*

