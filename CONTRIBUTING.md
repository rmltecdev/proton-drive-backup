# Proton Drive Backup — Contributing

Thank you for your interest in improving Proton Drive Backup. This document outlines the process for submitting changes.  

## Prerequisites

* An authenticated Proton Drive account (login handled interactively on first run)  
* `proton-drive` CLI v0.4.6 or higher [https://proton.me/drive/cli](https://proton.me/drive/cli)  
* `jq`, `md5sum`, `tar`, GNU `find`  
* bash 4.2 or higher  

## Development Setup

1. Clone the repository  
2. Make the script executable: `chmod +x proton-drive-backup`  
3. Run the smoke tests: `./tests/test.sh`  
4. All tests must pass before submitting changes  

## Guidelines

### Code Style

* Use 4-space indentation inside functions  
* Comment in English above the code block being described  
* Keep functions focused — one responsibility per function  
* Use `local` variables inside functions  
* set -uo pipefail, manual error handling — -e deliberately omitted

### Localization

* English (`.en`) is the fallback language and source of truth  
* All message keys in `.en` must exist in `.de` and `.th` and additional localizations you might contribute.  
* Run `./tests/test.sh` to verify localization key parity  

### Commits

* Use conventional commit messages:  
  * `Added` new feature  
  * `Fixed` bug fix  
  * `Removed` removed feature
  * `Updated` updated feature
  * `Documented` documentation only  
  * `Refactored` code restructuring  
  * `Tested` test additions or changes  
* Reference issues where applicable: `Fixed toggle race condition (#12)`  

### Testing

* Run `./tests/test.sh` before every commit  
* Document any new manual test cases in your PR description  

### Pull Requests

1. Fork the repository  
2. Create a feature branch: `git checkout -b feat/your-feature`  
3. Commit your changes  
4. Ensure smoke tests pass  
5. Open a pull request with a clear description of changes and test results  

## Reporting Issues

* Use GitHub Issues  
* Include your distribution and Bash version  
