# Linux Update Automation

This script automates the process of updating Linux systems across different distributions. It handles package management, updates, logging, and optional notifications.

## Features

- **Cross-Distribution Support**: Works with Ubuntu/Debian, RHEL/CentOS/Fedora, SUSE, and Arch Linux
- **Comprehensive Logging**: Detailed logs with timestamps and severity levels
- **Flexible Execution Modes**:
  - Check-only mode to see available updates without installing
  - Force update checks
  - Optional automatic reboots when required
- **Package Management**:
  - Hold/exclude specific packages from updates
  - Distribution-specific update methods
- **Email Notifications**: Optional email reports on completion or failure
- **Security-Focused**: Uses non-interactive mode with safe defaults for configuration files

## Requirements

- Bash shell
- Root privileges (sudo)
- Mail command (optional, for notifications)

## Installation

1. Download the script:
   ```bash
   wget -O linux_update_automation.sh https://your-server/path/linux_update_automation.sh
   ```

2. Make it executable:
   ```bash
   chmod +x linux_update_automation.sh
   ```

3. Test the script in check-only mode:
   ```bash
   sudo ./linux_update_automation.sh --check-only
   ```

## Usage

### Basic Usage

```bash
sudo ./linux_update_automation.sh
```

### Options

- `--check-only`: Only check for updates, don't install them
- `--force`: Force check for updates even if recently checked
- `--reboot`: Automatically reboot the system if required after updates
- `--email=user@example.com`: Send email notification with results
- `--hold=package1,package2`: Skip updates for specified packages
- `--help`: Display usage information

### Examples

Check for updates without installing:
```bash
sudo ./linux_update_automation.sh --check-only
```

Install updates and automatically reboot if needed:
```bash
sudo ./linux_update_automation.sh --reboot
```

Exclude specific packages from updates:
```bash
sudo ./linux_update_automation.sh --hold=kernel,mysql-server
```

Full automation with email notification:
```bash
sudo ./linux_update_automation.sh --force --reboot --email=admin@example.com
```

## Automatic Scheduling with Cron

To run updates automatically, add a cron job:

1. Edit the crontab:
   ```bash
   sudo crontab -e
   ```

2. Add a line to run updates weekly (e.g., Sunday at 2 AM):
   ```
   0 2 * * 0 /path/to/linux_update_automation.sh --reboot --email=admin@example.com >> /var/log/system-updates/cron.log 2>&1
   ```

## Log Files

Logs are stored in `/var/log/system-updates/` with the format `update_YYYYMMDD_HHMMSS.log`.

The script automatically rotates logs, keeping the 10 most recent files by default.

## Customization

You can modify the script variables at the top to change:
- Log directory location
- Maximum log files to keep
- Default behaviors for checking, installing, and rebooting

## Troubleshooting

If you encounter issues:

1. Check the log file in `/var/log/system-updates/`
2. Ensure the script has proper permissions
3. Verify internet connectivity
4. Check if the package manager is locked by another process

## Security Considerations

- This script requires root privileges
- It uses safe package management options to avoid breaking systems
- For Debian/Ubuntu, it uses `--force-confdef` and `--force-confold` to preserve existing configurations 