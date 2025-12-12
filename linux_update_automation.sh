#!/bin/bash
#
# Linux Update Automation Script
# Purpose: Automate system updates across different Linux distributions
# Version: 1.0
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

# Ensure script runs as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

# Function to log messages
log() {
  local level="$1"
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
    else
      log "ERROR" "Could not install mail utilities. Email notifications will not work."
      log "INFO" "Please manually install a mail client that provides the 'mail' command."
    fi
  fi
}

# Parse command line arguments
while [ $# -gt 0 ]; do
  case "$1" in
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
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --check-only     Check for updates but don't install"
      echo "  --force          Force check for updates"
      echo "  --reboot         Automatically reboot if needed"
      echo "  --email=EMAIL    Send notification to EMAIL"
      echo "  --hold=PACKAGES  Comma-separated list of packages to exclude"
      echo "  --help           Display this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
  shift
done

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Start log rotation
rotate_logs

# Log script invocation
log "INFO" "Starting Linux update automation script"
log "INFO" "Check-only mode: $CHECK_ONLY"
log "INFO" "Force update: $FORCE_UPDATE"
log "INFO" "Reboot if needed: $REBOOT_IF_NEEDED"
if [ -n "$EMAIL_NOTIFICATION" ]; then
  log "INFO" "Email notifications enabled: $EMAIL_NOTIFICATION"
  # Check for mail dependencies early in the script execution
  check_dependencies
fi

# Function to send email notification
send_notification() {
  local subject="$1"
  local message="$2"
  
  if [ -n "$EMAIL_NOTIFICATION" ]; then
    log "INFO" "Sending email notification to $EMAIL_NOTIFICATION"
    
    # Create a formatted email with header and footer
    local email_content="
=========================================================
LINUX SYSTEM UPDATE NOTIFICATION
From: Personal Linux Updates Team
Server: $(hostname)
Date: $(date)
=========================================================

$message

=========================================================
This is an automated message from the Linux update system.
For support, please contact the system administrator.
=========================================================
"
    
    # Check if mail command is available
    if command -v mail &>/dev/null; then
      # Send the email with the custom formatting
      echo "$email_content" | mail -s "$subject - Linux Updates Team" "$EMAIL_NOTIFICATION"
    elif command -v sendmail &>/dev/null; then
      # Try using sendmail as an alternative
      echo -e "Subject: $subject - Linux Updates Team\n\n$email_content" | sendmail -t "$EMAIL_NOTIFICATION"
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

# Function to determine Linux distribution
detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
    log "INFO" "Detected distribution: $DISTRO $VERSION"
    return 0
  else
    log "ERROR" "Could not determine Linux distribution"
    return 1
  fi
}

# Function to handle updates for Debian/Ubuntu
update_debian() {
  log "INFO" "Running Debian/Ubuntu update procedure"

  # Update package lists
  log "INFO" "Updating package lists"
  apt-get update -qq || { log "ERROR" "Failed to update package lists"; return 1; }

  # Check for updates
  UPDATES=$(apt-get -s upgrade | grep "^Inst" | wc -l)
  SECURITY_UPDATES=$(apt-get -s upgrade | grep -i security | wc -l)
  
  log "INFO" "Available updates: $UPDATES (including $SECURITY_UPDATES security updates)"

  if [ "$UPDATES" -eq 0 ]; then
    log "INFO" "System is up to date"
  else
    # List available updates
    log "INFO" "Available package updates:"
    apt-get -s upgrade | grep "^Inst" | tee -a "$LOG_FILE"

    # Stop if check-only mode
    if [ "$CHECK_ONLY" = true ]; then
      log "INFO" "Check-only mode, not installing updates"
    else
      # Hold specified packages if any
      if [ -n "$PACKAGE_HOLD" ]; then
        IFS=',' read -ra HOLD_PACKAGES <<< "$PACKAGE_HOLD"
        for package in "${HOLD_PACKAGES[@]}"; do
          log "INFO" "Holding package: $package"
          apt-mark hold "$package" || log "WARNING" "Failed to hold package: $package"
        done
      fi

      # Perform the upgrade
      log "INFO" "Installing updates"
      DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade || { 
        log "ERROR" "Failed to install updates"
        return 1
      }

      # Remove unused packages
      log "INFO" "Removing unused packages"
      DEBIAN_FRONTEND=noninteractive apt-get -y autoremove || {
        log "WARNING" "Failed to remove unused packages"
      }

      # Unhold specified packages if any
      if [ -n "$PACKAGE_HOLD" ]; then
        IFS=',' read -ra HOLD_PACKAGES <<< "$PACKAGE_HOLD"
        for package in "${HOLD_PACKAGES[@]}"; do
          log "INFO" "Removing hold on package: $package"
          apt-mark unhold "$package" || log "WARNING" "Failed to unhold package: $package"
        done
      fi

      log "INFO" "Update completed successfully"
    fi
  fi

  # Check if reboot is needed
  if [ -f /var/run/reboot-required ]; then
    log "WARNING" "System requires a reboot to complete updates"
    if [ "$REBOOT_IF_NEEDED" = true ]; then
      log "INFO" "Automatic reboot enabled, rebooting in 1 minute"
      send_notification "System update completed - Rebooting" "$(cat "$LOG_FILE")"
      shutdown -r +1 "System rebooting to complete updates" &
    else
      log "WARNING" "Automatic reboot not enabled, manual reboot required"
    fi
  else
    log "INFO" "No reboot required"
  fi

  return 0
}

# Function to handle updates for RHEL/CentOS/Fedora
update_redhat() {
  log "INFO" "Running RHEL/CentOS/Fedora update procedure"
  
  # Determine package manager (dnf or yum)
  if command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
  else
    PKG_MGR="yum"
  fi
  
  # Check for updates
  log "INFO" "Checking for updates"
  $PKG_MGR check-update -q
  CHECK_EXIT=$?
  
  # Exit code 100 means updates are available
  if [ $CHECK_EXIT -eq 0 ]; then
    log "INFO" "System is up to date"
  elif [ $CHECK_EXIT -ne 100 ]; then
    log "ERROR" "Error checking for updates"
    return 1
  else
    # Count updates
    UPDATES=$($PKG_MGR check-update | grep -v "^$" | grep -v "^Loaded" | wc -l)
    log "INFO" "Available updates: $UPDATES"
    
    # List available updates
    log "INFO" "Available package updates:"
    $PKG_MGR check-update | grep -v "^$" | grep -v "^Loaded" | tee -a "$LOG_FILE"
    
    # Stop if check-only mode
    if [ "$CHECK_ONLY" = true ]; then
      log "INFO" "Check-only mode, not installing updates"
    else
      # Exclude specified packages if any
      EXCLUDE_OPTION=""
      if [ -n "$PACKAGE_HOLD" ]; then
        log "INFO" "Excluding packages: $PACKAGE_HOLD"
        EXCLUDE_OPTION="--exclude=$PACKAGE_HOLD"
      fi
      
      # Perform the upgrade
      log "INFO" "Installing updates"
      $PKG_MGR -y $EXCLUDE_OPTION update || {
        log "ERROR" "Failed to install updates"
        return 1
      }
      
      # Remove unused packages
      log "INFO" "Removing unused packages"
      if [ "$PKG_MGR" = "dnf" ]; then
        dnf -y autoremove || log "WARNING" "Failed to remove unused packages"
      else
        # For older yum versions that might not have autoremove
        if yum -q --help | grep -q autoremove; then
          yum -y autoremove || log "WARNING" "Failed to remove unused packages"
        else
          log "INFO" "yum autoremove not available, skipping package cleanup"
        fi
      fi
      
      log "INFO" "Update completed successfully"
    fi
  fi
  
  # Check if reboot is needed (kernel updated)
  if [ -f /var/run/reboot-required ] || $PKG_MGR -q needs-restarting -r &>/dev/null; then
    log "WARNING" "System requires a reboot to complete updates"
    if [ "$REBOOT_IF_NEEDED" = true ]; then
      log "INFO" "Automatic reboot enabled, rebooting in 1 minute"
      send_notification "System update completed - Rebooting" "$(cat "$LOG_FILE")"
      shutdown -r +1 "System rebooting to complete updates" &
    else
      log "WARNING" "Automatic reboot not enabled, manual reboot required"
    fi
  else
    log "INFO" "No reboot required"
  fi
  
  return 0
}

# Function to handle updates for SUSE
update_suse() {
  log "INFO" "Running SUSE update procedure"
  
  # Refresh repositories
  log "INFO" "Refreshing repositories"
  zypper refresh || { log "ERROR" "Failed to refresh repositories"; return 1; }
  
  # Check for updates
  log "INFO" "Checking for updates"
  UPDATES=$(zypper list-updates | grep '|' | wc -l)
  UPDATES=$((UPDATES-2)) # Adjust for header lines
  
  log "INFO" "Available updates: $UPDATES"
  
  if [ "$UPDATES" -eq 0 ]; then
    log "INFO" "System is up to date"
  else
    # List available updates
    log "INFO" "Available package updates:"
    zypper list-updates | tee -a "$LOG_FILE"
    
    # Stop if check-only mode
    if [ "$CHECK_ONLY" = true ]; then
      log "INFO" "Check-only mode, not installing updates"
    else
      # Exclude specified packages if any
      EXCLUDE_OPTION=""
      if [ -n "$PACKAGE_HOLD" ]; then
        IFS=',' read -ra HOLD_PACKAGES <<< "$PACKAGE_HOLD"
        for package in "${HOLD_PACKAGES[@]}"; do
          log "INFO" "Locking package: $package"
          zypper addlock "$package" || log "WARNING" "Failed to lock package: $package"
        done
      fi
      
      # Perform the upgrade
      log "INFO" "Installing updates"
      zypper --non-interactive update || {
        log "ERROR" "Failed to install updates"
        return 1
      }
      
      # Remove unused packages
      log "INFO" "Removing unused packages"
      zypper --non-interactive rm -u || log "WARNING" "Failed to remove unused packages"
      
      # Remove locks if any
      if [ -n "$PACKAGE_HOLD" ]; then
        IFS=',' read -ra HOLD_PACKAGES <<< "$PACKAGE_HOLD"
        for package in "${HOLD_PACKAGES[@]}"; do
          log "INFO" "Removing lock on package: $package"
          zypper removelock "$package" || log "WARNING" "Failed to unlock package: $package"
        done
      fi
      
      log "INFO" "Update completed successfully"
    fi
  fi
  
  # Check if reboot is needed
  if zypper ps -s | grep -q "requires reboot"; then
    log "WARNING" "System requires a reboot to complete updates"
    if [ "$REBOOT_IF_NEEDED" = true ]; then
      log "INFO" "Automatic reboot enabled, rebooting in 1 minute"
      send_notification "System update completed - Rebooting" "$(cat "$LOG_FILE")"
      shutdown -r +1 "System rebooting to complete updates" &
    else
      log "WARNING" "Automatic reboot not enabled, manual reboot required"
    fi
  else
    log "INFO" "No reboot required"
  fi
  
  return 0
}

# Function to handle updates for Arch Linux
update_arch() {
  log "INFO" "Running Arch Linux update procedure"
  
  # Refresh package databases
  log "INFO" "Refreshing package databases"
  pacman -Sy || { log "ERROR" "Failed to refresh package databases"; return 1; }
  
  # Check for updates
  log "INFO" "Checking for updates"
  UPDATES=$(pacman -Qu | wc -l)
  
  log "INFO" "Available updates: $UPDATES"
  
  if [ "$UPDATES" -eq 0 ]; then
    log "INFO" "System is up to date"
  else
    # List available updates
    log "INFO" "Available package updates:"
    pacman -Qu | tee -a "$LOG_FILE"
    
    # Stop if check-only mode
    if [ "$CHECK_ONLY" = true ]; then
      log "INFO" "Check-only mode, not installing updates"
    else
      # Exclude specified packages if any
      if [ -n "$PACKAGE_HOLD" ]; then
        log "INFO" "Ignoring packages: $PACKAGE_HOLD"
        sed -i "s/^#IgnorePkg.*$/IgnorePkg = $PACKAGE_HOLD/" /etc/pacman.conf
      fi
      
      # Perform the upgrade
      log "INFO" "Installing updates"
      pacman --noconfirm -Su || {
        log "ERROR" "Failed to install updates"
        return 1
      }
      
      # Remove orphaned packages
      log "INFO" "Removing orphaned packages"
      ORPHANS=$(pacman -Qtdq)
      if [ -n "$ORPHANS" ]; then
        pacman --noconfirm -Rns $(pacman -Qtdq) || log "WARNING" "Failed to remove orphaned packages"
      else
        log "INFO" "No orphaned packages found"
      fi
      
      # Reset ignored packages
      if [ -n "$PACKAGE_HOLD" ]; then
        log "INFO" "Resetting ignored packages"
        sed -i "s/^IgnorePkg.*$/#IgnorePkg   = /" /etc/pacman.conf
      fi
      
      log "INFO" "Update completed successfully"
    fi
  fi
  
  # Check if systemd-sysupdate was updated, which often requires reboot
  if pacman -Q linux | grep -v "$(uname -r)" || pacman -Q systemd | grep "installed" > /dev/null; then
    log "WARNING" "System requires a reboot to complete updates"
    if [ "$REBOOT_IF_NEEDED" = true ]; then
      log "INFO" "Automatic reboot enabled, rebooting in 1 minute"
      send_notification "System update completed - Rebooting" "$(cat "$LOG_FILE")"
      shutdown -r +1 "System rebooting to complete updates" &
    else
      log "WARNING" "Automatic reboot not enabled, manual reboot required"
    fi
  else
    log "INFO" "No reboot required"
  fi
  
  return 0
}

# Main function
main() {
  # Start logging
  log "INFO" "Starting system update check"
  log "INFO" "Script version: 1.0"
  
  # Rotate logs
  rotate_logs
  
  # Detect distribution
  detect_distro || { 
    log "ERROR" "Failed to detect Linux distribution"
    send_notification "System update failed" "$(cat "$LOG_FILE")"
    exit 1
  }
  
  # Run appropriate update function based on distribution
  case $DISTRO in
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