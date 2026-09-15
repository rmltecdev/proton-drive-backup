# Proton Drive Backup — Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-09-15
### Added
- Fast-path metadata check: reuse MD5 when file size and mtime unchanged
- New option: --checksum forces full hash (bypasses fast path)
- New config: CHECK_UPDATES gates optional network checks (privacy-first)

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
