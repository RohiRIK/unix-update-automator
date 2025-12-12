#!/bin/bash

# Module for Arch Linux updates

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
