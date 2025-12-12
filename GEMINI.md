# Project Overview

This directory contains a shell script for automating Unix system updates across various distributions. The script, `unix_update_automator.sh`, is designed to be a comprehensive tool for system administrators to manage updates on servers running different Linux flavors and macOS.

The project has been enhanced to be more "production ready" by improving automation, testing, and documentation.

## Key Files

- **`unix_update_automator.sh`**: The main script that performs the update logic. It's written in Bash and supports command-line arguments for flexible execution.
- **`modules/`**: This directory contains the specific logic for each package manager (e.g., `apt.sh`, `brew.sh`).
- **`onboard.sh`**: A script to guide users through the installation and setup of the update automator.
- **`OPERATORS.md`**: A manual for operators on how to run, debug, and manage the service.
- **`.github/workflows/ci.yml`**: A GitHub Actions workflow that runs `shellcheck` and the `test.sh` script on every push and pull request.
- **`test.sh`**: A script for running basic tests on the main script's logic.

## Building and Running

The project is a shell script and does not require a build process.

**To run the script:**

1.  **Make the script executable:**
    ```bash
    chmod +x unix_update_automator.sh
    ```

2.  **Run with `sudo`:**
    ```bash
    sudo ./unix_update_automator.sh [options]
    ```

For more details on usage and options, refer to the `README.md` file.

## Development Conventions

- The script is written in Bash.
- It uses `set -e` to exit on error.
- Functions are used to modularize the code.
- The script is well-documented with comments and a separate `README.md` and `OPERATORS.md` file.
- It requires root privileges to run.
- `shellcheck` is used for linting, and the CI pipeline enforces this on all changes.
