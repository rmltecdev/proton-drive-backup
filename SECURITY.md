# Proton Drive Backup — Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | ✅        |
| 1.1.x   | ✅        |
| 1.2.x   | ✅        |

## Reporting a Vulnerability

If you discover a security vulnerability in Proton Drive Backup, please report it responsibly:  

1. Email: rmltecdev@pm.me  
2. Subject: `[SECURITY] Proton Drive Backup — <brief description>`  
3. Include:  
   - Affected version (`proton-drive-backup --version`)  
   - Steps to reproduce  
   - Potential impact  

Please **do not** open a public GitHub issue for security vulnerabilities.  

## Response Time

* Acknowledgement: within 72 hours  
* Assessment: within 7 days  
* Fix or mitigation: depends on severity  

## Scope

Proton Drive Backup runs with user-level privileges and processes only data the invoking user can already access.

**In scope:**  
- The `proton-drive-backup` script, `install.sh`, the smoke test, and all shipped locale/config files.

**Out of scope:**  
- The Proton Drive CLI itself and Proton's infrastructure — report those to Proton: [https://proton.me/support](https://proton.me/support)  
- Network or account security of your Proton account

**Trust boundary:** locale and config files are sourced as Bash.
Executing unreviewed locale/config files is equivalent to executing
arbitrary code — only use files from trusted sources. This is why
every shipped file carries a review reminder in its header.

**Log privacy:** `runtime.log` and the transfer log contain the full
names and paths of your files. Users with sensitive file names should
consider restricting access to
`~/.local/state/proton-drive-backup/` accordingly.