# Proton Drive Backup — Frequently Asked Questions (FAQ)

#### Table of Contents

[General](#general)  
[Philosophy and Design](#philosophy-and-design)  
[Sizing and Fair Use](#sizing-and-fair-use)  
[Localization and Display](#localization-and-display)  
[Cron Jobs](#cron-jobs)  
[Logs](#logs)  
[Progress Display](#progress-display)  
[Should I use --verbose or --quiet?](#should-i-use)  
[Who is liable for data loss?](#who-is-liable)  
[Can I modify the script?](#an-I-modify-the-script)  
[Legal and Modification](Legal and Modification)

## General

### Is this an official Proton tool?

No. This is an unofficial community tool by RML Tec Dev. It is not affiliated with, endorsed by, or supported by Proton AG. "Proton Drive" is a trademark of Proton AG. Proton AG is not responsible for this tool's functionality or maintenance.  

### Can this tool delete my local files?

No — never. The tool only *reads* local files (hashing, comparison, upload). All deletions happen exclusively on the remote Proton Drive side, and only for files you have deleted locally yourself. Start with `--dry-run` to preview every pending action.  

## Philosophy and Design

### Why does the tool put orphaned files in the trash instead of deleting them?

Because a brake beats no brake. `DELETE_MODE=trash` (the default) keeps every removal recoverable. Deleted-then-restored mistakes are cheap; permanently lost backups are not. Clear the Proton Drive trash periodically after verifying your backups, then switch explicitly to `DELETE_MODE=delete` if you prefer permanent removal.  

### Renaming a file fills my trash — why?

Renaming is not atomic in the CLI world: it registers as delete plus upload. In trash mode the old copy lands in the trash on the next run. This is expected behavior, not a bug — empty the trash as part of your periodic hygiene.  

### Why are empty remote folders not cleaned up?

The official Proton Drive CLI does not offer recursive folder deletion of empty directories. This is a documented CLI limitation.  

### Why does --help/--version fail with a configuration error?

The script validates its entire configuration contract before any mode runs — a partially working script that fails mid-operation is worse than one that refuses to start. Fix the reported config value (see the example config), then all modes become available at once.

## Sizing and Fair Use

### Can I back up my full 2 TB storage?

Be honest with yourself about what this tool is: a curator's backup for selected data, not a terabyte vault. Every run re-hashes every configured file locally (MD5) to determine deltas. A very large data set therefore means a long scan on every run, and Proton's fair use policy applies on the remote side as well.  

Proton's official guidance for the Drive CLI: "To stay within limits, only upload or download what has actually changed — don't reupload the same files repeatedly or rewrite entire folders." This tool implements exactly that by design: only new or changed files are uploaded; unchanged files are skipped entirely.  

If your data set grows into terabytes, consider splitting: curated documents via this tool, bulk media archives via dedicated bulk storage.  

### My first run is slow — is that normal?

Yes. The first run builds the checksum database, which reads and hashes every configured file once. Subsequent runs are typically much faster, but still scale with the total number of files (a full hash pass per run — see previous question).  

## Localization and Display

### My table columns are misaligned under non-English messages
Any language whose text contains multibyte UTF-8 glyphs…  

* umlauts (e.g. Finnish, German, Turkish, Hungarian),  
*  ligatures (e.g. Danish, German, Norwegian, Swedish),  
* diacritics (e.g. Czech, French, Icelandic, Portuguese, Romanian, Spanish),  
* combining marks (e.g. Khmer, Lao, Thai)  

…can shift column alignment when the system locale is missing or misspelled. First check that your locale actually exists and is generated:  

`locale -a | grep -i "<lang>"`

If `de_DE.utf8` is missing, enable it in `/etc/locale.gen` (remove the `#` in front of `de_DE.UTF-8 UTF-8`) and run `sudo locale-gen`.  

### I set LANG=de-DE.UTF-8 and nothing changed — why?

Underscore, not hyphen: the locale name is `de_DE.UTF-8`. An invalid locale name fails silently — the script still runs, but character counting falls back to byte counting, which breaks column alignment. This failure mode produces no error message; that is shell behavior, not a bug in the script.  

### Why do umlauts break printf alignment at all?

Because three different units are involved: `printf` measures BYTES in field widths, `${#var}` counts CHARACTERS, and the terminal renders COLUMNS. A single UTF-8 umlaut is 2 bytes, 1 character, 1 column. The tool therefore routes all alignment through its own `pad_to()` helper, which counts columns-aware. Third-party patches should do the same — see MESSAGES.md.  

## Cron Jobs

### The cron job starts but fails with an authentication error

Cron runs without your desktop session environment. The script already exports the D-Bus session address for credential access, but if you logged in per-user: verify the cron user matches the user who authenticated the Proton Drive CLI. Run the script once manually (no `--quiet`) to trigger interactive login.  

## Logs

### Where are my old logs?

At the start of each run, the previous run's logs are archived as `<UTC-stamp>.tar.gz` in `~/.local/state/proton-drive-backup/`. Read an archive without extracting:  

`tar -xzOf <stamp>.tar.gz`

Retention is controlled via `KEEP_LOG_RUNS` in the config file.  

## Progress Display

### The progress bar disappeared after I resized the terminal

Expected behavior by design. A resize invalidates the cached terminal geometry the progress bar depends on. Instead of guessing, the tool disables the display, prints a warning, and continues in quiet mode. Progress remains observable in the logs; follow them live with `proton-drive-backup --log` or `tail -f` on the transfer log.  


## Should I use --verbose or --quiet?

- Use `--verbose` for **manual runs** — and visual progress feedback.  
- Use `--quiet` for **cronjobs** — minimizes I/O and keeps logs clean.  

For initial backups or after a `--reset-db`, always use `--verbose` to verify the upload is proceeding correctly.  

## Legal and Modification

### Who is liable for data loss?

You are. This tool is provided "as is" under the MIT License, with NO WARRANTY of any kind — neither RML Tec Dev nor Proton AG is liable for lost data, lost profits, or any damages arising from the use of this software. That is the deal of free software: you gain full control, and with it full responsibility. Mitigate sensibly:  
Preview every change with `--dry-run`, keep `DELETE_MODE=trash` until you trust your setup, verify backups after the first runs, and clear the remote trash only after checking.  

### Can I modify the script?

Yes — that is the point of the MIT License: study it, change it, redistribute it, in private or commercially. Two asks come with it:  

(a) review the locale and config files before you source them (these files are executable Bash), and  

(b) if your modification fixes a bug others share, consider contributing it back — the project stays alive through returned improvements. See [CONTRIBUTING](CONTRIBUTING.md) for the workflow.  

---

*Last updated: 2026-09-09*
*Author: RML Tec Dev*

