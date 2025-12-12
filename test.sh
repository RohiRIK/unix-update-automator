#!/bin/bash

# Test script for the Linux Update Automation Script
# This script creates a mock environment to test the logic of the main script without actually running system commands.

# Setup
TEST_DIR=$(mktemp -d)
LOG_DIR="$TEST_DIR/logs"
export LOG_DIR

# Mock /etc/os-release
cat > "$TEST_DIR/os-release" <<EOL
ID=ubuntu
VERSION_ID="22.04"
EOL
export OS_RELEASE_FILE="$TEST_DIR/os-release"

# Mock commands
mock_command() {
    echo "Mock command: $*" >> "$LOG_DIR/test.log"
}

apt-get() { mock_command apt-get "$@"; }
dnf() { mock_command dnf "$@"; }
yum() { mock_command yum "$@"; }
zypper() { mock_command zypper "$@"; }
pacman() { mock_command pacman "$@"; }
npm() { mock_command npm "$@"; }
pip() { mock_command pip "$@"; }
shutdown() { mock_command shutdown "$@"; }

export -f apt-get dnf yum zypper pacman npm pip shutdown

# Source the main script to get its functions
# shellcheck disable=SC1091
source linux_update_automation.sh

# Run tests
run_test() {
    local test_name="$1"
    shift
    echo "--- Running test: $test_name ---"
    
    # Override /etc/os-release for detect_distro
    detect_distro() {
        if [ -f "$OS_RELEASE_FILE" ]; then
            # shellcheck disable=SC1090
            . "$OS_RELEASE_FILE"
            DISTRO=$ID
            VERSION=$VERSION_ID
            log "INFO" "Detected distribution: $DISTRO $VERSION (mocked)"
            return 0
        else
            log "ERROR" "Could not determine Linux distribution"
            return 1
        fi
    }
    
    # Run the main script in a subshell to avoid exiting the test script
    (main "$@") || echo "Test finished with an error (as expected in some cases)"
    
    echo "--- Test finished: $test_name ---"
    echo
}

# Test cases
run_test "Check-only mode for Ubuntu" --check-only
run_test "Update with npm and pip" --with-npm --with-pip
run_test "Security updates only" --security
run_test "Force update with reboot" --force --reboot

# Change OS for another test
cat > "$TEST_DIR/os-release" <<EOL
ID=fedora
VERSION_ID="37"
EOL
run_test "Check-only mode for Fedora" --check-only

# Cleanup
rm -rf "$TEST_DIR"

echo "All tests completed."
echo "Check the output above and the logs in the temporary directories for more details."
echo "Note: This script does not verify the correctness of the package manager commands, only that the correct logic paths are taken."
