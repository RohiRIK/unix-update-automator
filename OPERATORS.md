# Operator's Manual

This document provides instructions for operators on how to run, debug, and manage the Unix-like Update Automator service.

## Running the Service

The service is designed to be run as a scheduled job (e.g., via cron or launchd). The `onboard.sh` script is the recommended way to set up the scheduled job.

### Manual Execution

To run the script manually, use the following command:

```bash
sudo /path/to/unix_update_automator.sh [options]
```

For a list of all options, see the `README.md` file or run the script with the `--help` flag.

## Debugging

### Log Files

The primary source of information for debugging is the log files.

-   **Linux**: Logs are stored in `/var/log/system-updates/`
-   **macOS**: Logs are stored in `~/Library/Logs/unix-update-automator/`

The script automatically rotates logs, keeping the 10 most recent files by default.

### Common Issues

-   **Package manager locked**: If the script fails, it may be because another process is using the system's package manager. Ensure that no other package management tools are running and try again.
-   **Permissions**: The script requires root/admin privileges to run. Ensure you are running it with `sudo`.
-   **Connectivity**: The script requires an internet connection to reach package repositories.

## Rollback

A rollback in this context means reverting to a previous version of the script.

1.  **Check out the desired version:**
    ```bash
    git checkout <commit_hash>
    ```
2.  **Re-run the onboarding script or manually update the installed script:**
    ```bash
    sudo ./onboard.sh
    ```
    or
    ```bash
    sudo cp unix_update_automator.sh /usr/local/bin/
    sudo cp -r modules /usr/local/bin/
    ```

## Future Improvements

-   **Comprehensive Testing**: The current `test.sh` script provides basic checks. A more comprehensive test suite using a framework like `bats-core` would improve confidence in the script's correctness.
-   **Metrics and Monitoring**: The script could be extended to expose metrics (e.g., update duration, success/failure rates) for monitoring in a time-series database like Prometheus.
