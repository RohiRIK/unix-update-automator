#!/bin/bash

# Onboarding script for Unix-like Update Automation
# This script will install the update automation script and set up a scheduled job.

# --- Configuration ---
LINUX_INSTALL_DIR="$HOME/.auto-updates"
MACOS_INSTALL_DIR="$HOME/Library/Application Support/unix-update-automator"
SCRIPT_NAME="unix_update_automator.sh"
MODULES_DIR="modules"
LOCK_FILE="/var/run/unix_update_automator.lock"

# --- Helper Functions ---
ask_yes_no() {
    local prompt=""
    local default="$2"
    local answer

    while true; do
        read -r -p "$prompt [y/n] (default: $default): " answer
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
        read -r -p "Enter the email address for notifications (leave blank for no email): " email
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

ask_schedule_cron() {
    echo "Choose a schedule for the updates:"
    echo "  1) Daily"
    echo "  2) Weekly (recommended)"
    echo "  3) Monthly"
    echo "  4) Custom cron expression"
    
    while true; do
        read -r -p "Enter your choice (default: 2): " choice
        choice=${choice:-2}
        case $choice in
            1) CRON_SCHEDULE="0 2 * * *"; return;;
            2) CRON_SCHEDULE="0 2 * * 0"; return;;
            3) CRON_SCHEDULE="0 2 1 * *"; return;;
            4) read -r -p "Enter your custom cron expression: " CRON_SCHEDULE; return;;
            * ) echo "Invalid choice.";;
        esac
    done
}

ask_schedule_launchd() {
    echo "Choose a schedule for the updates:"
    echo "  1) Daily (at 2 AM)"
    echo "  2) Weekly (on Sunday at 2 AM)"
    
    while true; do
        read -r -p "Enter your choice (default: 2): " choice
        choice=${choice:-2}
        case $choice in
            1) 
                LAUNCHD_DAY=
                LAUNCHD_WEEKDAY=
                return;;
            2) 
                LAUNCHD_DAY=
                LAUNCHD_WEEKDAY=0
                return;;
            * ) echo "Invalid choice.";;
        esac
    done
}

# --- Main Logic ---
echo "--- Unix-like Update Automation Onboarding ---"
echo

# Determine OS
if [ "$(uname)" == "Darwin" ]; then
    OS="macOS"
    INSTALL_DIR="$MACOS_INSTALL_DIR"
else
    OS="Linux"
    INSTALL_DIR="$LINUX_INSTALL_DIR"
    # Check for root privileges on Linux
    if [ "$EUID" -ne 0 ]; then
        echo "This script needs to be run with sudo to install the cron job for the root user."
        echo "Please run as: sudo $0"
        exit 1
    fi
fi

echo "Detected OS: $OS"
echo

# Gather parameters
if [ "$OS" == "Linux" ]; then
    ask_schedule_cron
    if ask_yes_no "Automatically reboot if needed?" "n"; then REBOOT_PARAM="--reboot"; else REBOOT_PARAM=""; fi
else
    ask_schedule_launchd
    REBOOT_PARAM=""
fi

ask_email
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
echo "--- Scheduled Job Setup ---"

if [ "$OS" == "Linux" ]; then
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
else # macOS
    PLIST_LABEL="com.user.autoupdate"
    PLIST_FILE="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
    
    # Create the plist content
    read -r -d '' PLIST_CONTENT << EOM
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/$SCRIPT_NAME</string>
        <string>$REBOOT_PARAM</string>
        <string>$NPM_PARAM</string>
        <string>$PIP_PARAM</string>
        <string>$EMAIL_PARAM</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
        $( [ -n "$LAUNCHD_DAY" ] && echo "<key>Day</key><integer>$LAUNCHD_DAY</integer>" )
        $( [ -n "$LAUNCHD_WEEKDAY" ] && echo "<key>Weekday</key><integer>$LAUNCHD_WEEKDAY</integer>" )
    </dict>
    <key>StandardOutPath</key>
    <string>$INSTALL_DIR/launchd.log</string>
    <key>StandardErrorPath</key>
    <string>$INSTALL_DIR/launchd.log</string>
</dict>
</plist>
EOM

    echo "A launchd plist will be created at the following location:"
    echo "$PLIST_FILE"
    echo
    echo "--- Plist Content ---"
    echo "$PLIST_CONTENT"
    echo "---------------------"
    echo

    if ask_yes_no "Do you want to proceed with creating this launchd agent?" "y"; then
        echo "$PLIST_CONTENT" > "$PLIST_FILE"
        echo "launchd agent created successfully."
        echo "To load it, run:"
        echo "  launchctl load $PLIST_FILE"
        echo "To unload it, run:"
        echo "  launchctl unload $PLIST_FILE"
    else
        echo "launchd agent creation aborted."
    fi
fi

echo
echo "--- Onboarding Complete ---"
echo "The update script is now installed in $INSTALL_DIR"
if [ "$OS" == "Linux" ]; then
    echo "You can edit the crontab for the root user at any time with 'sudo crontab -e -u root'"
else
    echo "You can manage the scheduled job with launchctl."
fi

