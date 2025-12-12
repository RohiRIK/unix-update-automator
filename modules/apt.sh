#!/bin/bash

# Module for Debian/Ubuntu updates

update_debian() {
  log "INFO" "Running Debian/Ubuntu update procedure"

  # Update package lists
  log "INFO" "Updating package lists"
  apt-get update -qq || { log "ERROR" "Failed to update package lists"; return 1; }

  # Check for updates
  UPDATES=$(apt-get -s upgrade | grep -c "^Inst")
  SECURITY_UPDATES=$(apt-get -s upgrade | grep -ci "security")
  
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
