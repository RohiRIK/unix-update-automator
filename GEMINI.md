# Project Overview

This directory contains a shell script for automating Linux system updates across various distributions. The script, `linux_update_automation.sh`, is designed to be a comprehensive tool for system administrators to manage updates on servers running different Linux flavors.

## Key Files

- **`linux_update_automation.sh`**: The main script that performs the update logic. It's written in Bash and supports command-line arguments for flexible execution.
- **`linux_update_readme.md`**: Detailed documentation for the script, including features, installation, usage, and cron job setup.

## Building and Running

The project is a shell script and does not require a build process.

**To run the script:**

1.  **Make the script executable:**
    ```bash
    chmod +x linux_update_automation.sh
    ```

2.  **Run with `sudo`:**
    ```bash
    sudo ./linux_update_automation.sh [options]
    ```

**Common Options:**

-   `--check-only`: Check for updates without installing them.
-   `--force`: Force the update check.
-   `--reboot`: Automatically reboot if required.
-   `--email=user@example.com`: Send a notification email.
-   `--hold=package1,package2`: Exclude packages from the update.

For more details, refer to the `linux_update_readme.md` file.

## Development Conventions

- The script is written in Bash.
- It uses `set -e` to exit on error.
- Functions are used to modularize the code (e.g., `log`, `rotate_logs`, `detect_distro`, and distribution-specific update functions).
- The script is well-documented with comments and a separate `README.md` file.
- It requires root privileges to run.
