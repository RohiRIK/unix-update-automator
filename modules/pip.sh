#!/bin/bash

# Module for pip updates

update_pip() {
    log "INFO" "Running pip update procedure"

    if ! command -v pip &> /dev/null; then
        log "WARNING" "pip not found, skipping pip updates."
        return
    fi

    log "INFO" "Checking for outdated pip packages"
    pip list --outdated | tail -n +3 > /tmp/pip_updates.txt
    OUTDATED_PIP=$(cat /tmp/pip_updates.txt | wc -l)

    if [ "$OUTDATED_PIP" -eq 0 ]; then
        log "INFO" "All pip packages are up to date"
        rm /tmp/pip_updates.txt
        return
    fi

    log "INFO" "Available pip package updates:"
    cat /tmp/pip_updates.txt | tee -a "$LOG_FILE"

    if [ "$CHECK_ONLY" = true ]; then
        log "INFO" "Check-only mode, not installing pip updates"
        rm /tmp/pip_updates.txt
        return
    fi

    log "INFO" "Updating pip packages"
    if pip install --upgrade $(awk '{print $1}' /tmp/pip_updates.txt); then
        log "INFO" "pip packages updated successfully"
    else
        log "ERROR" "Failed to update pip packages"
        rm /tmp/pip_updates.txt
        return 1
    fi

    rm /tmp/pip_updates.txt
}
