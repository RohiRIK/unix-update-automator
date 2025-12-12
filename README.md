# Unix-like Update Automation

![Gemini_Generated_Image_10f90x10f90x10f9.png](assets/Gemini_Generated_Image_10f90x10f90x10f9.png)

A comprehensive and reliable script for automating system updates across a wide range of Unix-like operating systems, including Linux distributions and macOS.

## Motivation

Managing system updates across multiple servers and workstations, each with its own package manager and update schedule, can be a time-consuming and error-prone task for system administrators and developers. This project aims to solve that problem by providing a single, powerful, and flexible script that automates the entire update process.

## Features

- **Cross-Platform Support**: Works with various Linux distributions (Debian, Ubuntu, RHEL, CentOS, Fedora, SUSE, Arch) and macOS (via Homebrew).
- **Extensible Package Management**: In addition to system packages, the script can update global packages for `npm` and `pip`.
- **Comprehensive Logging**: Generates detailed logs with timestamps and severity levels, with automatic log rotation.
- **Flexible Execution Modes**:
    -   `--check-only`: Check for available updates without installing them.
    -   `--force`: Force an update check, ignoring the last-checked timestamp.
    -   `--reboot`: Automatically reboot the system if required after updates (Linux-only).
    -   `--security`: Install security-related updates only (for supported package managers).
- **Fine-Grained Package Control**:
    -   `--hold`: Exclude specific packages from being updated.
- **Notifications**:
    -   `--email`: Send a summary of the update process to a specified email address.
- **Robust and Safe**:
    -   **Concurrency Control**: Uses `flock` to prevent multiple instances of the script from running simultaneously.
    -   **Configuration-Safe**: Uses non-interactive modes to prevent unintended changes to configuration files during updates.

## System Overview

The Unix-like Update Automator is a modular Bash script designed for easy extension and customization. It consists of a core engine and a set of modules for different package managers.

| Component                  | Type     | Tech / Stack | Responsibility                                                                  | Key Entry Point                  |
| -------------------------- | -------- | ------------ | ------------------------------------------------------------------------------- | -------------------------------- |
| `unix_update_automator.sh` | Core     | Bash         | Handles argument parsing, logging, main update logic, and concurrency.        | `main()`                         |
| `modules/apt.sh`           | Module   | Bash         | Implements update logic for Debian/Ubuntu systems using `apt-get`.              | `run_apt_update()`               |
| `modules/yum_dnf.sh`       | Module   | Bash         | Implements update logic for RHEL/CentOS/Fedora systems using `yum` or `dnf`.    | `run_yum_dnf_update()`           |
| `modules/pacman.sh`        | Module   | Bash         | Implements update logic for Arch Linux systems using `pacman`.                  | `run_pacman_update()`            |
| `modules/zypper.sh`        | Module   | Bash         | Implements update logic for SUSE systems using `zypper`.                        | `run_zypper_update()`            |
| `modules/brew.sh`          | Module   | Bash         | Implements update logic for macOS systems using `brew`.                         | `run_brew_update()`              |
| `modules/npm.sh`           | Module   | Bash         | Implements update logic for global `npm` packages.                              | `run_npm_update()`               |
| `modules/pip.sh`           | Module   | Bash         | Implements update logic for global `pip` packages.                              | `run_pip_update()`               |
| `onboard.sh`               | Script   | Bash         | Provides a guided setup and installation experience.                            | N/A                              |

## Tech Stack

- **Language**: Bash
- **Core Utilities**: `flock`, `getopt`, `mail` (optional)
- **Package Managers**: `apt-get`, `yum`, `dnf`, `pacman`, `zypper`, `brew`, `npm`, `pip`

## Installation and Setup

### Automatic Onboarding (Recommended)

The `onboard.sh` script provides a simple, interactive way to install the update automator and schedule it to run automatically.

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/RohiRIK/unix-update-automator.git
    cd unix-update-automator
    ```
2.  **Run the onboarding script:**
    ```bash
    sudo ./onboard.sh
    ```
    The script will guide you through the process of setting up a cron job (Linux) or a `launchd` agent (macOS).

### Manual Installation

For advanced users who prefer manual setup:

1.  Place `unix_update_automator.sh` and the `modules/` directory in a suitable location (e.g., `/usr/local/bin`).
2.  Make the main script executable:
    ```bash
    chmod +x /usr/local/bin/unix_update_automator.sh
    ```
3.  Run a test to ensure it's working correctly:
    ```bash
    sudo /usr/local/bin/unix_update_automator.sh --check-only
    ```

## Usage

The script can be run manually with various command-line options for customized behavior.

```bash
sudo /path/to/unix_update_automator.sh [options]
```

### Common Workflows

- **Check for all available updates without installing:**
  ```bash
  sudo ./unix_update_automator.sh --check-only --with-npm --with-pip
  ```
- **Apply all updates and reboot if necessary:**
  ```bash
  sudo ./unix_update_automator.sh --reboot
  ```
- **Apply only security updates and send an email report:**
  ```bash
  sudo ./unix_update_automator.sh --security --email=your-email@example.com
  ```
- **Update everything except for a specific package:**
  ```bash
  sudo ./unix_update_automator.sh --hold=nginx
  ```

## Configuration

The script's behavior can be customized by editing the variables at the top of `unix_update_automator.sh`:

-   `LOG_DIR_LINUX`: The directory where logs are stored on Linux systems.
-   `LOG_DIR_MACOS`: The directory where logs are stored on macOS.
-   `MAX_LOG_FILES`: The maximum number of log files to keep.
-   `LOCK_FILE`: The path to the lock file used for concurrency control.

## Development

### Running Tests

The project includes a `test.sh` script that can be used to run basic tests on the script's functionality.

```bash
./test.sh
```

### Linting and Formatting

To maintain code quality, it is recommended to use `shellcheck` for linting and `shfmt` for formatting.

-   **Linting with `shellcheck`:**
    ```bash
    shellcheck *.sh modules/*.sh
    ```
-   **Formatting with `shfmt`:**
    ```bash
    shfmt -w *.sh modules/*.sh
    ```

## Contributing

Contributions are welcome! If you would like to contribute, please follow these steps:

1.  Fork the repository.
2.  Create a new branch for your feature or bug fix.
3.  Make your changes and ensure they follow the existing code style.
4.  Run the tests to ensure everything is working correctly.
5.  Submit a pull request with a clear description of your changes.

## License

This project is licensed under the MIT License. See the `LICENSE` file for more details.