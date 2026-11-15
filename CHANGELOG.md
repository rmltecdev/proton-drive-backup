# Proton Drive Backup — Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.3.0] - 2026-11-15

### Fixed
- Upload skip logic never skipped unchanged files: a stray string
  fragment in the previous-MD5 lookup defeated every comparison;
  all files were re-uploaded on each run
- Six "temp file" log entries were written on the SUCCESS path
  (log companions sat outside the failure branches — now each
  companion lives in the same block as its terminating fail)
- Missing English log entry for the JSON conversion failure in
  the database build phase
- Staging files leaked to `/tmp` when the run aborted on a missing
  source directory; staging paths are now global and covered by
  the cleanup trap on every exit path
- Log summary printed "Trashd" instead of "Trashed"; the past-tense
  verb is now derived centrally via `delete_mode_past()`
- Locale crash: a runtime variable embedded in a localized message
  caused "unbound variable" under `set -u;` locale files carry
  `printf` placeholders exclusively now
- Localized messages duplicated themselves when a `printf` format
  contained fewer `%s` placeholders than supplied arguments
  (`fail_skip_missing_dir family`)
- Smoke test reported live functions as dead: call-site detection
  missed command substitutions and trap payloads (Section 8c)

### Changed
- Strict separation of localized console output (EN/DE/TH) and
  English-only `runtime log`; console helpers are console-only,
  forensic events carry explicit English log entries
- Buffered logging: entries written before log initialization
  (localization, configuration, lock) now land in the CURRENT
  run's log instead of being archived with the previous run
- Log escalation ladder: INFO / WARNING / ERROR / FAILURE —
  ERROR = per-item failure (run continues), FAILURE = run
  termination; redundant "Refusing to continue" prefixes removed
- Progress bar: intermediate phases show "Please wait..." at
  100%; "...completed." is reserved exclusively for the end of
  the delete phase, including the 0/0 no-orphans case
- Per-entry JSON parsing consolidated from three jq invocations
  per file to one
- Quiet mode suppresses progress and per-file output only;
  banner, configuration, and summary remain visible; retry
  counters are now part of the quiet-mode summary

### Added
- `init_logging()` with log buffering; archive and prune of previous
  run logs run inside log initialization
- MSG keys `bar_state_wait` / `bar_state_done`; `show_progress_bar`
  accepts a "final" argument
- Smoke test gates: console/log separation audit, corpse-function
  audit, self-verifying discovery patterns (empty discovery is a
  FAIL, never a silent pass)

### Security
- Missing-directory gate: a configured SOURCE_DIR that does not
  exist aborts the run BEFORE scanning — silent skipping would
  have fabricated deletions in the delete phase
- Empty-scan gate: a scan returning zero files aborts in both
  variants (previous database present / first run); there is
  deliberately no override flag — intentional emptying is a
  configuration edit, never a flag

## [v1.2.1] - 2026-10-20

### Fixed
- Removed hostile-filename entries from the retry queue reliably:
  `retry_queue_remove()` now rebuilds the array instead of calling
  `unset`, which fails silently for keys containing `]` on bash < 5.2
  (e.g. Ubuntu 22.04) and for quoting characters (' " \) on every bash
  version — affected entries stayed in the queue forever, re-uploading
  on each run and inflating the pending counter
- Hardened the retry queue loader: corrupted `attempts` fields (legacy
  of pre-1.2.1 record parsing) now default to 1 instead of crashing the
  increment arithmetic

### Added
- `test/deploy.sh`: transport with git-describe build identity, dirty-tree
  refusal, atomic installation and a SHA-512 deployment manifest —
  the answer to the invisible stale-deployment incident (M-19)
- `BUILD_ID` slot in the script header, stamped at deploy time and
  rendered in version output and log prefix
- `test/chartest.sh`: unset behavior matrix as measurement tool; results
  for bash 5.1.16 and 5.2.21 documented in the header
- Smoke test Section 13: static discipline check — no direct `unset` on
  the retry queue array
- Manual tests M-19 through M-21 (deployment verification, ETA under fast
  item sequences, retry queue removal under hostile filenames)  
- Publication of SHA-512 checksum for delivered artifacts in release
  notes; enables tamper detection and customer-side verification of
  binary integrity (M-22)  

## [v1.2.0] - 2026-10-07

### Fixed

- Removed a misplaced `sleep 1` inside the scan loop that fired once per
  file; cold-run scan time now scales with actual disk I/O instead of
  file count, cutting the scan phase by roughly 90 % on large datasets
  (the penalty grew linearly with every additional file, independent of
  file size)
- Moved progress-bar updates out of staged intervals in upload, delete
  and retry phases; the bar now reflects every processed item, which
  previously froze for thousands of iterations on I/O-bound operations
- Invoked `upload_single_file` directly in the parent shell instead of
  command substitution; the remote-directory cache is now preserved
  across uploads, eliminating repeated directory-walk API roundtrips
  and duplicate log entries per file
- Corrected a variable leak in `retry_queue_process` where a directory-
  creation failure updated the wrong queue entry
- Added a distinct first-run message ("no previous backup state found")
  when no previous database exists, replacing the misleading
  "comparing against previous backup state" notice  
- Fixed retry queue arithmetics: `retry_queue_record_failure()` now parses the stored record with three fields instead of four, preserving the attempts
  counter across multiple failures. Previously, attempts accumulated as a
  timestamp string, causing bash arithmetic errors on the second retry attempt.  

### Changed
- CLI help now validates against parse_args options via new smoke test Section  
- FD 3 lifecycle moved to main() before retry pre-pass runs  
- Retry queue record parser now correctly increments attempts counter  
- Manual tests expanded to M-18 (retry eligibility ceiling enforcement)  

### Security

- Commit-Point: checksum database staged until all phases confirm

### Known Limitations
- Initial deployment of the retry architecture; active monitoring
  recommended for the first production run
- ETA estimation remains heuristic and fluctuates with file-size
  distribution

## [v1.1.0] - 2026-09-20

### Added

- Fast-path metadata check: size+mtime match reuses stored MD5 (no re-hash)
- New option: --checksum forces full hash (bypasses fast path)
- Progress display: per-phase ETA, stable right edge (normalized 20-column tail)

### Changed

- Database build collects entries as TSV and finalizes in a single jq
  call (eliminates one process spawn per file)
- Schema: entries now carry numeric mtime_epoch alongside ISO mtime
- Consolidated upload phase summary (one line, human-readable size)

### Fixed

- Timezone offset in stored mtimes invalidated the fast path (date
  conversion without -u); mtime is now generated UTC-side by jq

## [v1.0.0] - 2026-09-09

### Added

- One-way backup of local directories to Proton Drive (unofficial community tool)
- MD5-based change detection with persistent local JSON database
- Upload conflict strategies: replace, skip
- Orphan handling with recoverable (trash) and permanent (delete) modes
- Cron scheduling with configurable interval (--schedule / --unschedule)
- Run-scoped logging with automatic archiving (tar.gz) and retention
- English, German and Thai localization (external locale files)
- Graceful terminal-resize degradation; progress bar with scroll region
- Instance locking via PID-validated lock file

[1.0.0]: https://github.com/rmltecdev/proton-drive-backup/releases/tag/v1.0.0
[1.1.0]: https://github.com/rmltecdev/proton-drive-backup/releases/tag/v1.1.0
[1.2.0]: https://github.com/rmltecdev/proton-drive-backup/releases/tag/v1.2.0