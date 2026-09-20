# Proton Drive Backup — Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
