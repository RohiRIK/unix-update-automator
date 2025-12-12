#!/bin/bash

# Module for npm updates

update_npm() {
    log "INFO" "Running npm update procedure"

    if ! command -v npm &> /dev/null; then
        log "WARNING" "npm not found, skipping npm updates."
        return
    fi

    log "INFO" "Checking for outdated global npm packages"
    OUTDATED_NPM=$(npm -g outdated | wc -l)

    if [ "$OUTDATED_NPM" -eq 0 ]; then
        log "INFO" "All global npm packages are up to date"
        return
    fi

    log "INFO" "Available npm package updates:"
    npm -g outdated | tee -a "$LOG_FILE"

    if [ "$CHECK_ONLY" = true ]; then
        log "INFO" "Check-only mode, not installing npm updates"
        return
    fi

    log "INFO" "Updating global npm packages"
    if npm -g update; then
        log "INFO" "npm packages updated successfully"
    else
        log "ERROR" "Failed to update npm packages"
        return 1
    fi
}
