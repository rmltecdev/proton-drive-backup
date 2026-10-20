# Proton Drive Backup — Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1] - 2026-10-20

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

## [1.2.0] - 2026-10-07

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

## [1.1.0] - 2026-09-20

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

## [1.0.0] - 2026-09-09

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