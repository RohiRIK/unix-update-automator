# Linux Update Automation

This script automates the process of updating Linux systems across different distributions. It handles package management, updates, logging, and optional notifications for system packages as well as `npm` and `pip` packages.

## Automatic Installation and Onboarding

For a quick and easy setup, you can use the `onboard.sh` script. This script will guide you through the installation process and automatically set up a cron job for you.

**To run the onboarding script:**

1.  **Download the project files**, including `onboard.sh`, `linux_update_automation.sh`, and the `modules` directory.
2.  **Run the `onboard.sh` script with `sudo`:**
    ```bash
    sudo ./onboard.sh
    ```
    The script will ask you for your preferred schedule, email for notifications, and other options. It will then install the script to `~/.auto-updates` and set up the cron job for the root user.

## Manual Installation and Usage

For advanced users who want more control over the installation and setup process, you can follow the manual steps below.

### Project Structure

The project is organized into a main script and a `modules` directory:

- **`linux_update_automation.sh`**: The main script that you run. It handles argument parsing, logging, and calls the appropriate update modules. It also implements a locking mechanism to prevent concurrent runs.
- **`modules/`**: This directory contains the specific logic for each package manager. This modular design makes it easy to extend the script with new package managers or to modify the behavior of existing ones.

### Features

- **Cross-Distribution Support**: Works with Ubuntu/Debian, RHEL/CentOS/Fedora, SUSE, and Arch Linux
- **Additional Package Managers**: Supports updating global packages for `npm` and `pip`.
- **Comprehensive Logging**: Detailed logs with timestamps and severity levels
- **Flexible Execution Modes**:
  - Check-only mode to see available updates without installing
  - Force update checks
  - Optional automatic reboots when required
  - Security updates only (for supported package managers)
- **Package Management**:
  - Hold/exclude specific packages from updates
  - Distribution-specific update methods
- **Email Notifications**: Optional email reports on completion or failure
- **Concurrency Control**: Uses `flock` to prevent multiple instances of the script from running simultaneously.
- **Security-Focused**: Uses non-interactive mode with safe defaults for configuration files

### Requirements

- Bash shell
- Root privileges (sudo)
- Mail command (optional, for notifications)
- `npm` (optional, for managing Node.js packages)
- `pip` (optional, for managing Python packages)
- `flock` utility (usually part of `util-linux` package, which is standard on most Linux systems)

### Manual Installation

1. Place the `linux_update_automation.sh` script and the `modules` directory in your desired location (e.g., `/usr/local/bin`).
2. Make the script executable:
   ```bash
   chmod +x /path/to/linux_update_automation.sh
   ```

3. Test the script in check-only mode:
   ```bash
   sudo /path/to/linux_update_automation.sh --check-only
   ```

### Manual Usage

```bash
sudo /path/to/linux_update_automation.sh [options]
```

**Options:**

- `--check-only`: Only check for updates, don't install them
- `--force`: Force check for updates even if recently checked
- `--reboot`: Automatically reboot the system if required after updates
- `--email=user@example.com`: Send email notification with results
- `--hold=package1,package2`: Skip updates for specified packages
- `--with-npm`: Also update global npm packages
- `--with-pip`: Also update global pip packages
- `--security`: Install security updates only (for `apt` and `dnf`/`yum`)
- `--help`: Display usage information

### Manual Cron Job Setup

1. Edit the root user's crontab:
   ```bash
   sudo crontab -e -u root
   ```

2. Add a line to run updates at your desired schedule (e.g., weekly at 2 AM on Sunday):
   ```
   0 2 * * 0 /usr/bin/flock -xn /var/run/linux_update_automation.lock -c "/path/to/linux_update_automation.sh --reboot --with-npm --with-pip --email=admin@example.com >> /var/log/system-updates/cron.log 2>&1"
   ```
   **Note**: The `/usr/bin/flock -xn /var/run/linux_update_automation.lock` part ensures that only one instance of the script runs at a time.

## Log Files

Logs are stored in `/var/log/system-updates/` with the format `update_YYYYMMDD_HHMMSS.log`.

The script automatically rotates logs, keeping the 10 most recent files by default.

## Customization

You can modify the script variables at the top to change:
- Log directory location
- Maximum log files to keep
- Default behaviors for checking, installing, and rebooting
- The `LOCK_FILE` path

## Troubleshooting

If you encounter issues:

1. Check the log file in `/var/log/system-updates/`
2. Ensure the script has proper permissions
3. Verify internet connectivity
4. Check if the package manager is locked by another process
5. Check if `flock` is available and correctly configured in your cron job.

## Security Considerations

- This script requires root privileges
- It uses safe package management options to avoid breaking systems
- For Debian/Ubuntu, it uses `--force-confdef` and `--force-confold` to preserve existing configurations