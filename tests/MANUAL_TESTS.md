# MANUAL_TESTS.md — proton-drive-backup

Manual and visual tests for `proton-drive-backup`. These complement
the automated smoke test (`test/test.sh`): the smoke test proves
syntax, metadata consistency and localization contracts; the tests
below prove runtime behavior that no static check can reach.

- Language: EN_US throughout, per project convention.
- Run the full suite before every release (see RELEASE_CHECKLIST.md).
- Every test lists a **Proof criterion** — an observable output that
  constitutes the pass condition. "It didn't crash" is not a proof.
- Test environments:
  - `fra-0006` — development host, small test tree (~51 files).
  - Remote sandbox: `/my-files/backup_test_neu` (may be deleted and
    recreated freely).
  - `mel-0498` — production-sized dataset, 1.1 TiB, ~120.8k files.

| ID          | Scenario  | Last verified  |
|-         |- | |
| M-01 … M-14 | see below | release v1.2.0 |



## M-01 — Cold run against virgin remote target

**Goal:** The base remote directory is created before any child
directory (regression test for the v1.1.0 cold-run killer).

**Steps:**
1. Ensure the remote target does NOT exist
   (`proton-drive filesystem info <target>` fails).
2. Run a full backup against the virgin target with `--verbose`.

**Proof criterion:** No `Cannot create remote folder` errors in the
log; the run ends with `Checksum database committed after confirmed
phases.` The remote holds the expected directory tree afterwards.



## M-02 — Subsequent run: fast path

**Goal:** The second run reuses stored MD5s and uploads only deltas.

**Steps:** Run twice against the same target without modifying any
file in between.

**Proof criterion:** Second run reports
`Fast path reused stored MD5 for N of N files (~100%)` and the
upload phase shows all files as `Skip (unchanged)`. Runtime of the
scan phase drops from hours (cold) to minutes (warm).



## M-03 — Crash simulation: commit-point integrity

**Goal:** A killed run never poisons the authoritative database.

**Steps:**
1. Complete one successful run (baseline DB committed).
2. Start a second run, modify a few files, kill the process
   mid-upload (`kill -9`).
3. Inspect the checksum database, then run again.

**Proof criterion:** After the kill, the committed DB still reflects
the baseline state (no partial hashes from the interrupted run);
staging leftovers are cleaned by the trap. The follow-up run
uploads the modified files cleanly — the poisoned-baseline class of
the v1.1.0 crash is structurally impossible.



## M-04 — Retry queue under transient failure

**Goal:** Upload failures are queued and replayed, not dead-ended.

**Steps:**
1. Start a run and interrupt connectivity to the remote mid-upload
   (e.g., revoke session token temporarily or block network).
2. Restore connectivity.
3. Re-run the script (or wait for the in-run retry with backoff).

**Proof criterion:** Log shows `retry_queue_record_failure` activity
and, on replay, `Retry pre-pass: N eligible ...` with the failed
files confirmed (`Retried successfully: ...`). Exhausted entries
remain pending across runs, not silently dropped.



## M-05 — Delete phase: orphan handling and dry-run contrast

**Goal:** Local deletions propagate to the remote per DELETE_MODE;
`--dry-run` previews but never executes.

**Steps:**
1. Delete a backed-up local file.
2. Run with `--dry-run --verbose`, note the summary.
3. Run for real.
4. Repeat with DELETE_MODE=`trash` and `delete`.

**Proof criterion:** Dry-run prints `[DRY-RUN] Would <mode>: ...`
and the summary reports zero deleted files (counter reflects
executed operations only — see FAQ). The real run trashes or
permanently deletes the orphan (two-step trash→delete in `delete`
mode). Non-orphaned files are untouched.



## M-06 — Dry-run against fresh target (limitation check)

**Goal:** Establish what `--dry-run` does NOT verify.

**Steps:** Point the config at a target whose base directory does
not exist; run `--dry-run`.

**Proof criterion:** The run completes cleanly printing
`[DRY-RUN] Would create folder: ...` — the simulator never touches
the remote, so remote structure problems are INVISIBLE here. This
is the documented reason M-09 exists; this test pins the boundary,
not a bug.



## M-07 — Database/remote-base mismatch protection

**Goal:** A previous DB bound to a different remote base must not
fabricate skip decisions.

**Steps:**
1. Complete a run against remote A (DB committed with `remote_base`
   = A).
2. Change `REMOTE_BASE_PATH` to a different target B, keep the DB.
3. Run with `--verbose`.

**Proof criterion:** The mismatch warning appears; the run treats
the DB as absent (`PREVIOUS_DB_PATH=/dev/null`) and performs a full
upload to B instead of skipping everything.



## M-08 — Clean rebinding via --reset-db

**Goal:** `--reset-db` binds the DB to the new remote deterministically.

**Steps:** Same as M-07, but run with `--reset-db`.

**Proof criterion:** Rebuild warning appears, upload runs cleanly,
the committed DB carries `remote_base` = B. No residual entries
from A.



## M-09 — Mini-run against the REAL remote before every cold run

**Goal:** Structural remote verification at minimal cost. This is
the core lesson of the lost 1.5-day cold run.

**Steps:**
1. Create a tiny source tree (2–3 text files), temporary config.
2. Point `REMOTE_BASE_PATH` at the target structure the cold run
   will use (fresh target, or a throwaway sibling like
   `backup_test_neu`).
3. Run WITHOUT `--dry-run` — a real transfer of the small tree.

**Proof criterion:** Base and child directories are created on the
real remote; uploads succeed; afterwards remove the test tree on
the remote and clean up local test state. Rationale: dry-run
verifies logic locally; only a real (small) transfer proves the
remote scaffold is reachable and creatable. Two separate gates for
two separate failure classes.



## M-10 — Remote-directory cache (subshell regression)

**Goal:** `CREATED_REMOTE_DIRS` persists across uploads; no
per-file directory walks.

**Steps:** Run a verbose multi-file upload spanning several nested
directories (depth ≥ 3).

**Proof criterion:** `grep -c "already exists" <runtime.log>` yields
roughly the number of DISTINCT directories (~5.5k on mel-0498), not
the file count (120k+). Each directory's walk appears exactly once
per run. (Regression: the command-substitution subshell discarded
the cache per file.)



## M-11 — Progress bar liveness in verbose mode

**Goal:** Verbose output reflects every processed item; no frozen
bars, no per-file sleeps.

**Steps:** Observe `--verbose` output during scan, upload, delete
and retry phases.

**Proof criterion:** The bar advances per file/item continuously
(scan rate reflects real hashing throughput: small text files ~15/s
locally, large video files seconds per file). Between the 1000th
and 1001st file there is NO multi-hour stall (the legacy staged
interval + `sleep 1` regression). Final bars render once per phase
with a 1-second hold.



## M-12 — Lock file: concurrent invocation refusal

**Goal:** Two simultaneous instances cannot interleave writes.

**Steps:** Start a run; while it is in the scan phase, launch a
second instance.

**Proof criterion:** The second instance refuses to start with the
lock-held message and exits non-zero. After the first run ends (or
is killed), the lock is released (cleanup trap is idempotent —
killing the run must not leave a stale lock that blocks the next
run).



## M-13 — Cron scheduling round-trip

**Goal:** schedule/list/unschedule manipulate exactly our line.

**Steps:** `--schedule-cron`, verify via `is_cron_scheduled`
(listing shows the marker line), then `--unschedule-cron`.

**Proof criterion:** After scheduling, the crontab contains exactly
one new line carrying the script-path marker; foreign entries are
untouched. After unscheduling, the line is gone and the crontab is
otherwise identical to the pre-test snapshot
(`crontab -l > before.txt` / `after.txt`, diff empty apart from our
line). CRON_INTERVAL_MINUTES values shipped in .cfg.example must
fit cron semantics (validated by smoke test Section 9).



## M-14 — Interrupt during upload: trap cleanup

**Goal:** Ctrl-C mid-upload leaves no dangling state.

**Steps:** Start a verbose run, wait until the upload phase, send
SIGINT (Ctrl-C or `kill -2`).

**Proof criterion:** FD 3 is closed (transfer log consistent), temp
files removed, lock released, the message digest DB is untouched
(staging only). A directly following run starts without
obstructions.

## M-15 — Retry pre-pass with verbose mode and open FD 3

**Goal:** The retry pre-pass can write to FD 3 before the upload phase opens it.

**Steps:**
1. Manually populate the retry queue with one entry (see below).
2. Run with `--verbose`.

**Proof criterion:** No "Bad file descriptor" error on line 1395; the log shows
`Retry failed: ...` with a concrete error message, not "(unknown error)". The
error originates from `capture_cli_error()`, not from a broken redirect.



## M-16 — Queue entry with spaces removed correctly

**Goal:** Removing a queue entry with spaces in the path works via `unset`.

**Steps:**
1. Create a queue entry referencing a file that no longer exists locally.
2. Run the backup (non-verbose).
3. Check the queue persistence file and summary counter.

**Proof criterion:** The entry disappears from the retry queue file; the
`Pending in retry queue` counter decrements correctly. With the fix applied,
`unset "RETRY_QUEUE[$rel_path]"` handles the full path as a single key,
including embedded spaces.



## M-17 — Retry queue with complete records (multiple failures)

**Goal:** The queue correctly increments the attempts counter and preserves
the original timestamp across multiple retry cycles.

**Steps:**
1. Create a queue entry with all fields populated:  

   ```bash
   printf '%s\t%s\t%s\t%s\n' \
       'Documents/retry_test.pdf' \
       '1' \
       '2026-10-07T10:00:00Z' \
       'network timeout' \
       >> ~/.config/proton-drive-backup/proton-drive-backup.retry
   ```

2. Trigger two consecutive failures (disconnect network, invalidate session).  

3. Inspect the queue file after each failure.  

**Proof criterion:** After the second failure: `attempts=2`, `first_seen` still shows the original timestamp `2026-10-07T10:00:00Z`, `last_error` reflects the newest error message. No bash arithmetic errors (`syntax error in expression`) appear in stderr. Without the fix, the attempts counter becomes corrupted (timestamp string), causing a bash failure on the increment.

## M-18 — Retry eligibility ceiling enforcement

**Goal:** Entries exceeding `RETRY_MAX_ATTEMPTS` are exhausted and marked pending.

**Steps:**

1. Create a queue entry with `attempts=RETRY_MAX_ATTEMPTS` (default: 3).  

2. Run the backup.  

**Proof criterion:** The entry does not trigger a retry; the summary reports it under "still pending" or "exhausted" (depending on your logging), and the file remains in the queue with `attempts` unchanged. The eligibility gate prevents the retry attempt despite the queue entry existing.

---

## Queue entry format (reference)

Each line in `proton-drive-backup.retry` consists of **four tab-separated fields**: `path`, `attempts`, `first_seen`, `last_error`. Example:

`Documents/global/ADAC - Alles zu Tagfahrleuchten und Taglichtpflicht.pdf 2 2026-10-07T10:27:31Z network timeout`

Manual editing is **supported for diagnostics only** — the format is a contract, but the loader tolerates truncated lines via defaults. Do not rely on manual queue manipulation as a routine workflow; use `--reset-db` or the retry mechanism's natural operation for production scenarios.


---

## Verification helpers

```bash
# Directory cache proof (M-10)
grep -c "already exists" runtime.log

# Residual staged-interval regression sweep (M-11)
grep -n "progress_interval" proton-drive-backup        # expect: no matches

# Subshell regression sweep (M-10/M-04)
grep -n '"$(upload_single_file' proton-drive-backup    # expect: no matches

# Commit proof (M-01/M-02/M-03)
grep "committed after confirmed phases" runtime.log
```

## Sign-off

| Release | Date       | Tester | Notes        |
|-----    |-----       |----    |----          |
| v1.2.0  | 2026-10-07 | rml    | M-04 pending |
