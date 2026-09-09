# Proton Drive Backup — Localization Key Catalog

This document is the internal contract for all localization files
(`proton-drive-backup.<lang>`). Every contributor adding or changing
messages must keep this catalog and the locale files in sync — enforced
by `test.sh` wherever technically checkable.

## Conventions

1. **Only `tmpl_*` keys are printf format strings.** They contain
   `%s` placeholders whose positions must match across all languages.
   The script passes arguments positionally — a reordered placeholder
   is a mistranslation, not a style choice.
   Sole exception: `fail_config_syntax` (legacy name, kept for
   compatibility — see "Config validation").
2. **`PAD_*` values are numeric and language-specific.** Column width
   lives in `PAD_<SECTION>_WIDTH`, never as trailing spaces or filler
   characters inside `MSG[...]` strings.
3. **Alignment goes through `pad_to()` only.** Rationale:
   `printf` counts BYTES in `%-*s` field widths, `${#var}` counts
   CODEPOINTS, and the terminal displays COLUMNS. `pad_to()`
   (backed by `display_width()`) is the only measurement compatible
   with all three. Zero-width Thai combining marks (U+0E31,
   U+0E34–U+0E3A, U+0E47–U+0E4E) count as width 0.
4. **`MSG[help_text]` is a quoted heredoc** (`<<'EOF'`). It is exempt
   from rule 3 — it contains no column-aligned tables.
5. **A missing locale file aborts the run** (`load_locale` contract);
   a missing key aborts the smoketest (alignment check, bidirectional).

## PAD Variables

| Variable           | Consumer               | Values (.en / .de / .th)       |
|--------------------|------------------------|--------------------------------|
| PAD_CONFIG_WIDTH   | backup config block    | 24 / 33 / 18                   |
| PAD_VERSION_WIDTH  | `show_version()`       | 18 / 23 / 14                   |
| PAD_SUMMARY_WIDTH  | `print_summary()`      | 26 / 32 / 32                   |
| PAD_STATUS_WIDTH   | menu status section    | 18 / 22 / 18                   |
| PAD_OPTION_WIDTH   | menu options section   | 13 (fixed — option strings are identical ASCII across locales) |
| PAD_MENU_WIDTH     | menu paths section     | 14 / 21 / 14                   |

## Config validation

| Key | Type | Placeholders | Notes |
|---|---|---|---|
| tmpl_fail_invalid_value | Template | 3× %s | Generic wrapper: variable name, invalid value, reason |
| fail_val_delete | Constant | — | Reason: DELETE_MODE not trash/delete |
| fail_val_conflict | Constant | — | Reason: UPLOAD_CONFLICT_STRATEGY not replace/skip |
| fail_val_cron_positive | Constant | — | Reason: CRON_INTERVAL_MINUTES not a positive integer |
| fail_val_cron_divisible | Constant | — | Reason: values >60 must be multiples of 60 |
| fail_val_source_dirs | Constant | — | Reason: SOURCE_DIRS unset or empty |
| fail_val_keep_log_runs | Constant | — | Reason: KEEP_LOG_RUNS not a positive integer |
| fail_val_source_base | Constant | — | Reason: SOURCE_BASE empty or not absolute |
| fail_config_missing | Constant | — | Leading phrase; config path printed below by caller |
| fail_config_hint | Template | 1× %s | Runtime-derived .cfg.example path, printed with fail_config_missing |
| fail_config_syntax | Template | 1× %s | bash -n parser output header; legacy name kept — documented exception to rule 1 |

> **Constant keys** hold plain values without placeholders. They are
> consumed as printf arguments by tmpl_fail_invalid_value (reason slot)
> or echoed directly — locales must never contain literal % characters
> (enforced by smoke test). Template keys (`tmpl_*`, plus the two
> `fail_config_*` templates above) DO carry placeholders by design.

## Key Catalog

### Status labels
`status_preparing` — progress bar boot message

### Initialization and configuration
`info_config_header`, `info_conflict_strategy`, `info_delete_mode`,
`info_dry_run`, `info_reset_db`, `quiet_notice`

### Dependencies and session
`fail_dep_missing`, `info_deps_ok`, `info_session_check`,
`info_session_valid`, `info_auth_required`, `warn_dry_run_auth`,
`info_login_instruction`, `info_login_success`, `fail_login_failed`

### Remote directory handling
`info_dry_create_folder`, `fail_remote_create`

### Database build and load
`info_building_db`, `warn_skip_missing_dir`, `warn_file_unreadable`,
`warn_db_empty`, `info_no_db_found`, `info_lookup_build`,
`warn_rebuild_db`, `label_scan`, `label_load`, `label_process`,
`label_delete`
   Progress-bar verbs, translated in progressive form
   (en: -ing, de: unflected verb, th: กำลัง-construction). A new
   phase REQUIRES a new `label_*` member in every locale file.

### Upload phase
`info_compare_upload`, `info_no_local_files`, `info_uploaded`

### Delete phase
`info_compare_delete`, `info_no_orphans`,
`mode_verb_trash`, `mode_verb_delete`
   Dynamic family: `mode_verb_${DELETE_MODE}` — a new DELETE_MODE
   value REQUIRES a new family member in every locale file.

### Lock file management
`warn_lock_stale`

### Terminal resize
`warn_resize_disabled`, `warn_resize_continuing`

### Logging
`info_no_log_found`, `info_log_first_run`, `info_log_opening`,
`info_log_archive_opening`, `info_log_follow_hint`,
`warn_archive_failed`

### Cron management
`cron_manager`, `cron_scheduled`, `cron_already`, `cron_removed`,
`cron_none_found`, `cron_existing`, `cron_logs_written`

### Unknown options
`warn_unknown_option`

### Version display
`info_version`, `info_build_date`, `info_path`, `info_cli_version`,
`info_cli_not_installed`

### Print summary
`sum_uploaded`, `sum_skipped`, `sum_errors`, `sum_warnings`,
`sum_completed_ok`, `sum_completed_errors`

### Man-page style help
`help_text` (heredoc, 5 positional `%s`: SCRIPT_NAME,
CRON_INTERVAL_MINUTES, RUNTIME_LOG, KEEP_LOG_RUNS, DELETE_MODE),
`help_close`, `help_open`

### Composite templates (printf, %s placeholders)
`tmpl_db_built` (2), `tmpl_prev_db_loaded` (1),
`tmpl_upload_phase` (2), `tmpl_delete_phase` (2),
`tmpl_lock_running` (1), `tmpl_cron_interval` (1),
`tmpl_usage_hint` (1), `tmpl_menu_invoke` (1),
`tmpl_fail_invalid_value` (3)
   Number in parentheses = argument count; placeholder positions
   must be identical across languages.

### Interactive menu
`menu_status`, `menu_cron_label`, `menu_db_label`,
`menu_files_tracked`, `menu_logsize_label`, `menu_paths`,
`menu_script`, `menu_database`, `menu_logdir`,
`opt_dry_run`, `opt_help`, `opt_log`, `opt_quiet`,
`opt_reset_db`, `opt_schedule`, `opt_unschedule`,
`opt_verbose`, `opt_version`

## Removals
- `info_initialized` (removed v1.0.0 pre-release; consumer was dropped
  from the script — locale files must not carry it)
- `fail_no_source_dirs` (superseded v1.0.0 pre-release by the
  `tmpl_fail_invalid_value` family + `fail_val_source_dirs`)

## Adding a new language
1. Copy `proton-drive-backup.en` → `proton-drive-backup.<lang>`
2. Translate all keys; measure column widths and set `PAD_*` values
3. Preserve `tmpl_*` placeholder positions and counts exactly
4. Verify with `LANG=<lang>_XX.UTF-8` — a generated locale is required
   for correct glyph measurement (see FAQ)
5. `test.sh` discovers and validates the file automatically