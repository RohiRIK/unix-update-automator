#!/bin/bash

# Module for macOS updates using Homebrew

update_macos() {
  log "INFO" "Running macOS (Homebrew) update procedure"

  if ! command -v brew &>/dev/null; then
    log "ERROR" "Homebrew not found. Please install it to manage macOS packages."
    return 1
  fi

  # Update Homebrew itself
  log "INFO" "Updating Homebrew..."
  brew update || { log "ERROR" "Failed to update Homebrew"; return 1; }

  # Check for outdated packages
  log "INFO" "Checking for outdated packages (casks included)..."
  OUTDATED_COUNT=$(brew outdated --cask --formula | wc -l)

  if [ "$OUTDATED_COUNT" -eq 0 ]; then
    log "INFO" "All Homebrew packages are up to date."
  else
    log "INFO" "Available package updates:"
    brew outdated --cask --formula | tee -a "$LOG_FILE"

    # Stop if check-only mode
    if [ "$CHECK_ONLY" = true ]; then
      log "INFO" "Check-only mode, not installing updates."
    else
      # Perform the upgrade
      log "INFO" "Upgrading all outdated packages (casks included)..."
      brew upgrade --cask --formula || { 
        log "ERROR" "Failed to upgrade Homebrew packages."
        return 1
      }

      # Cleanup old versions
      log "INFO" "Cleaning up old versions of packages..."
      brew cleanup || log "WARNING" "Failed to clean up old Homebrew packages."
      
      log "INFO" "Homebrew update completed successfully."
    fi
  fi

  # macOS does not have a standard "reboot required" flag like Linux.
  # We could check for kernel updates, but that's less common and harder to track with Homebrew.
  # For now, we will not handle reboots on macOS.
  log "INFO" "Reboot check is not applicable for macOS in this script."
  
  return 0
}
