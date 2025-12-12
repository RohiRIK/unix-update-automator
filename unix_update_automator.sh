#!/bin/bash
#
# Unix Update Automation Script
# Purpose: Automate system updates across different Unix-like distributions and package managers
# Version: 4.0
#

# Set script to exit on error
set -e

# Configuration variables
LOG_DIR="/var/log/system-updates"
LOG_FILE="$LOG_DIR/update_$(date +%Y%m%d_%H%M%S).log"
MAX_LOG_FILES=10
CHECK_ONLY=false
FORCE_UPDATE=false
REBOOT_IF_NEEDED=false
EMAIL_NOTIFICATION=""
PACKAGE_HOLD=""  # Comma-separated list of packages to hold/exclude
UPDATE_NPM=false
UPDATE_PIP=false
SECURITY_ONLY=false
LOCK_FILE="/var/run/unix_update_automator.lock" # Lock file to prevent concurrent runs

# Source module files
for module in modules/*.sh; do
    source "$module"
done

# Ensure script runs as root
if [ "$(uname)" != "Darwin" ] && [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

# Function to log messages
log() {
  local level=""
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to rotate logs
rotate_logs() {
  log "INFO" "Rotating logs, keeping last $MAX_LOG_FILES files"
  ls -t "$LOG_DIR"/update_*.log | tail -n +$((MAX_LOG_FILES+1)) | xargs -r rm
}

# Function to check and install dependencies
check_dependencies() {
  log "INFO" "Checking for required dependencies"
  
  # Check for mail command if email notifications are enabled
  if [ -n "$EMAIL_NOTIFICATION" ] && ! command -v mail &>/dev/null && ! command -v sendmail &>/dev/null; then
    log "WARNING" "Mail command not found. Attempting to install mail utilities."
    
    if command -v apt-get &>/dev/null; then
      log "INFO" "Installing mailutils package for Debian/Ubuntu"
      apt-get update -qq && apt-get install -y mailutils
    elif command -v dnf &>/dev/null; then
      log "INFO" "Installing mailx package for RHEL/CentOS/Fedora"
      dnf install -y mailx
    elif command -v yum &>/dev/null; then
      log "INFO" "Installing mailx package for older RHEL/CentOS"
      yum install -y mailx
    elif command -v zypper &>/dev/null; then
      log "INFO" "Installing mailx package for SUSE"
      zypper install -y mailx
    elif command -v pacman &>/dev/null; then
      log "INFO" "Installing s-nail package for Arch Linux"
      pacman -S --noconfirm s-nail
    elif command -v brew &>/dev/null; then
        log "INFO" "macOS does not have a default mail client. Please install one if you want email notifications."
    else
      log "ERROR" "Could not install mail utilities. Email notifications will not work."
      log "INFO" "Please manually install a mail client that provides the 'mail' command."
    fi
  fi
}

# Parse command line arguments
while [ $# -gt 0 ]; do
  case "" in
    --check-only)
      CHECK_ONLY=true
      ;;
    --force)
      FORCE_UPDATE=true
      ;;
    --reboot)
      REBOOT_IF_NEEDED=true
      ;;
    --email=*)
      EMAIL_NOTIFICATION="${1#*=}"
      ;;
    --hold=*)
      PACKAGE_HOLD="${1#*=}"
      ;;
    --with-npm)
      UPDATE_NPM=true
      ;;
    --with-pip)
      UPDATE_PIP=true
      ;;
    --security)
      SECURITY_ONLY=true
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --check-only     Check for updates but don't install"
      echo "  --force          Force check for updates"
      echo "  --reboot         Automatically reboot if needed"
      echo "  --email=EMAIL    Send notification to EMAIL"
      echo "  --hold=PACKAGES  Comma-separated list of packages to exclude"
      echo "  --with-npm       Update global npm packages"
      echo "  --with-pip       Update global pip packages"
      echo "  --security       Install security updates only"
      echo "  --help           Display this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: "
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
  shift
done

# Create log directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    if [ "$(uname)" == "Darwin" ]; then
        # On macOS, we might not have permissions to create /var/log directories
        # Let's use a user-level log directory instead
        LOG_DIR="$HOME/Library/Logs/unix-update-automator"
        LOG_FILE="$LOG_DIR/update_$(date +%Y%m%d_%H%M%S).log"
        LOCK_FILE="$HOME/Library/Application Support/unix-update-automator.lock"
    fi
    mkdir -p "$LOG_DIR"
fi


# Start log rotation
rotate_logs

# Log script invocation
log "INFO" "Starting Unix update automation script"
log "INFO" "Script version: 4.0"
log "INFO" "Check-only mode: $CHECK_ONLY"
log "INFO" "Force update: $FORCE_UPDATE"
log "INFO" "Reboot if needed: $REBOOT_IF_NEEDED"
log "INFO" "Update npm: $UPDATE_NPM"
log "INFO" "Update pip: $UPDATE_PIP"
log "INFO" "Security updates only: $SECURITY_ONLY"
if [ -n "$EMAIL_NOTIFICATION" ]; then
  log "INFO" "Email notifications enabled: $EMAIL_NOTIFICATION"
  # Check for mail dependencies early in the script execution
  check_dependencies
fi

# Function to send email notification
send_notification() {
  local subject=""
  local message="$2"
  
  if [ -n "$EMAIL_NOTIFICATION" ]; then
    log "INFO" "Sending email notification to $EMAIL_NOTIFICATION"
    
    # Create a formatted email with header and footer
    local email_content="
=========================================================
UNIX SYSTEM UPDATE NOTIFICATION
From: Personal Unix Updates Team
Server: $(hostname)
Date: $(date)
=========================================================

$message

=========================================================
This is an automated message from the Unix update system.
For support, please contact the system administrator.
=========================================================
"
    
    # Check if mail command is available
    if command -v mail &>/dev/null; then
      # Send the email with the custom formatting
      echo "$email_content" | mail -s "$subject - Unix Updates Team" "$EMAIL_NOTIFICATION"
    elif command -v sendmail &>/dev/null; then
      # Try using sendmail as an alternative
      echo -e "Subject: $subject - Unix Updates Team\n\n$email_content" | sendmail -t "$EMAIL_NOTIFICATION"
    else
      log "WARNING" "Neither 'mail' nor 'sendmail' commands are available. Email notification not sent."
      log "INFO" "Install mailutils (Debian/Ubuntu) or mailx (RHEL/CentOS) to enable email notifications."
      
      # Save the email content to a file as a fallback
      local email_file="$LOG_DIR/notification_$(date +%Y%m%d_%H%M%S).txt"
      echo "$email_content" > "$email_file"
      log "INFO" "Email content saved to $email_file"
    fi
  fi
}

# Function to determine Unix distribution
detect_distro() {
  if [ "$(uname)" == "Darwin" ]; then
    DISTRO="darwin"
    VERSION=$(sw_vers -productVersion)
    log "INFO" "Detected distribution: macOS $VERSION"
    return 0
  elif [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
    log "INFO" "Detected distribution: $DISTRO $VERSION"
    return 0
  else
    log "ERROR" "Could not determine Unix distribution"
    return 1
  fi
}

# Main function
main() {
  # Acquire lock
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    log "ERROR" "Another instance of the script is already running. Exiting."
    send_notification "System update failed - Concurrent run" "Another instance of the update script attempted to run concurrently and was blocked."
    exit 1
  fi

  # Start logging
  log "INFO" "Starting system update check"
  log "INFO" "Script version: 4.0"
  
  # Rotate logs
  rotate_logs
  
  # Detect distribution
  detect_distro || { 
    log "ERROR" "Failed to detect Unix distribution"
    send_notification "System update failed" "$(cat "$LOG_FILE")"
    exit 1
  }
  
  # Run appropriate update function based on distribution
  case $DISTRO in
    darwin)
      update_macos || {
        log "ERROR" "Update process failed"
        send_notification "System update failed" "$(cat "$LOG_FILE")"
        exit 1
      }
      ;;
    ubuntu|debian|linuxmint|pop|elementary)
      update_debian || {
        log "ERROR" "Update process failed"
        send_notification "System update failed" "$(cat "$LOG_FILE")"
        exit 1
      }
      ;;
    rhel|centos|fedora|rocky|almalinux|ol)
      update_redhat || {
        log "ERROR" "Update process failed"
        send_notification "System update failed" "$(cat "$LOG_FILE")"
        exit 1
      }
      ;;
    sles|opensuse-leap|opensuse-tumbleweed)
      update_suse || {
        log "ERROR" "Update process failed"
        send_notification "System update failed" "$(cat "$LOG_FILE")"
        exit 1
      }
      ;;
    arch|manjaro)
      update_arch || {
        log "ERROR" "Update process failed"
        send_notification "System update failed" "$(cat "$LOG_FILE")"
        exit 1
      }
      ;;
    *)
      log "ERROR" "Unsupported distribution: $DISTRO"
      send_notification "System update failed" "$(cat "$LOG_FILE")"
      exit 1
      ;;
  esac

  # Update additional package managers if requested
  if [ "$UPDATE_NPM" = true ]; then
      update_npm || log "WARNING" "npm update process failed"
  fi

  if [ "$UPDATE_PIP" = true ]; then
      update_pip || log "WARNING" "pip update process failed"
  fi
  
  # Send success notification
  if [ "$CHECK_ONLY" = true ]; then
    send_notification "System update check completed" "$(cat "$LOG_FILE")"
  else
    send_notification "System update completed successfully" "$(cat "$LOG_FILE")"
  fi
  
  log "INFO" "Update process completed"
  exit 0
}

# Execute main function
main

