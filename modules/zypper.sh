#!/bin/bash

# Module for SUSE updates

update_suse() {
  log "INFO" "Running SUSE update procedure"
  
  # Refresh repositories
  log "INFO" "Refreshing repositories"
  zypper refresh || { log "ERROR" "Failed to refresh repositories"; return 1; }
  
  # Check for updates
  log "INFO" "Checking for updates"
  UPDATES=$(zypper list-updates | grep -c '|')
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
