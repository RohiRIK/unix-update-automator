#!/bin/bash

# Onboarding script for Linux Update Automation
# This script will install the update automation script and set up a cron job for it.

# --- Configuration ---
INSTALL_DIR="$HOME/.auto-updates"
SCRIPT_NAME="linux_update_automation.sh"
MODULES_DIR="modules"
LOCK_FILE="/var/run/linux_update_automation.lock"

# --- Helper Functions ---
ask_yes_no() {
    local prompt="$1"
    local default="$2"
    local answer

    while true; do
        read -p "$prompt [y/n] (default: $default): " answer
        answer=${answer:-$default}
        case $answer in
            [Yy]* ) return 0;; 
            [Nn]* ) return 1;; 
            * ) echo "Please answer yes or no.";;
        esac
    done
}

ask_email() {
    local email
    while true; do
        read -p "Enter the email address for notifications (leave blank for no email): " email
        if [[ -z "$email" || "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
            EMAIL_PARAM="--email=$email"
            if [[ -z "$email" ]]; then
                EMAIL_PARAM=""
            fi
            return
        else
            echo "Invalid email address."
        fi
    done
}

ask_schedule() {
    local schedule
    echo "Choose a schedule for the updates:"
    echo "  1) Daily"
    echo "  2) Weekly (recommended)"
    echo "  3) Monthly"
    echo "  4) Custom cron expression"
    
    while true; do
        read -p "Enter your choice (default: 2): " choice
        choice=${choice:-2}
        case $choice in
            1) CRON_SCHEDULE="0 2 * * *";; # 2 AM every day
            2) CRON_SCHEDULE="0 2 * * 0";; # 2 AM every Sunday
            3) CRON_SCHEDULE="0 2 1 * *";; # 2 AM on the 1st of every month
            4) read -p "Enter your custom cron expression: " CRON_SCHEDULE;; 
            * ) echo "Invalid choice.";;
        esac
    done
}

# --- Main Logic ---
echo "--- Linux Update Automation Onboarding ---"
echo 

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "This script needs to be run with sudo to install the cron job for the root user."
  echo "Please run as: sudo $0"
  exit 1
fi

# Gather parameters
ask_schedule
ask_email
if ask_yes_no "Automatically reboot if needed?" "n"; then REBOOT_PARAM="--reboot"; else REBOOT_PARAM=""; fi
if ask_yes_no "Update global npm packages?" "n"; then NPM_PARAM="--with-npm"; else NPM_PARAM=""; fi
if ask_yes_no "Update global pip packages?" "n"; then PIP_PARAM="--with-pip"; else PIP_PARAM=""; fi

echo 
echo "--- Installation ---"

# Create installation directory
echo "Creating installation directory at $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# Copy files
echo "Copying script and modules to $INSTALL_DIR..."
cp "$SCRIPT_NAME" "$INSTALL_DIR/"
cp -r "$MODULES_DIR" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

echo "Installation complete."
echo 
echo "--- Cron Job Setup ---"

# Construct cron job command
CRON_COMMAND="/usr/bin/flock -xn $LOCK_FILE -c \"$INSTALL_DIR/$SCRIPT_NAME $REBOOT_PARAM $NPM_PARAM $PIP_PARAM $EMAIL_PARAM >> $INSTALL_DIR/cron.log 2>&1\""
CRON_JOB="$CRON_SCHEDULE $CRON_COMMAND"

echo "The following cron job will be added to the root user's crontab:"
echo "$CRON_JOB"
echo 

if ask_yes_no "Do you want to proceed with adding this cron job?" "y"; then
    # Add cron job to root's crontab
    (crontab -u root -l 2>/dev/null; echo "$CRON_JOB") | crontab -u root -
    echo "Cron job added successfully."
else
    echo "Cron job installation aborted."
fi

echo 
echo "--- Onboarding Complete ---"
echo "The update script is now installed in $INSTALL_DIR"
echo "You can edit the crontab for the root user at any time with 'sudo crontab -e -u root'"
