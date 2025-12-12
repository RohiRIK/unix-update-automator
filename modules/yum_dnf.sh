#!/bin/bash

# Module for RHEL/CentOS/Fedora updates

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
    UPDATES=$($PKG_MGR check-update | grep -c -vE "^$|^Loaded")
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
      $PKG_MGR -y "$EXCLUDE_OPTION" update || {
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
