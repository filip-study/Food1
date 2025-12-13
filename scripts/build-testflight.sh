#!/bin/bash
# ============================================================================
# Food1 TestFlight Build & Upload Script
# ============================================================================
# Automated script for building and uploading to TestFlight.
# Called by n8n workflow on daily schedule.
#
# Prerequisites:
#   1. App Store Connect API Key (.p8) in ~/.appstoreconnect/private_keys/
#   2. API Key ID and Issuer ID configured below
#   3. Valid Apple Developer account with App Manager access
#
# Usage:
#   ./scripts/build-testflight.sh
#
# Environment variables (optional overrides):
#   ASC_KEY_ID      - App Store Connect API Key ID
#   ASC_ISSUER_ID   - App Store Connect Issuer ID
#   ASC_KEY_PATH    - Path to .p8 file
# ============================================================================

set -e  # Exit on any error

# ============================================================================
# CONFIGURATION - UPDATE THESE VALUES
# ============================================================================
# Load credentials from env file (gitignored)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/.build-env" ]]; then
    source "${SCRIPT_DIR}/.build-env"
fi

# App Store Connect API credentials
# Set via .build-env file or environment variables
ASC_KEY_ID="${ASC_KEY_ID:-}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"

# Project configuration
PROJECT_DIR="/Users/filip/Documents/git/Food1"
PROJECT_NAME="Food1"
SCHEME="Food1"
CONFIGURATION="Release"

# Build output directories
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
EXPORT_OPTIONS="${PROJECT_DIR}/scripts/ExportOptions.plist"

# Xcode settings (for Xcode 26+)
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

# Logging
LOG_FILE="${BUILD_DIR}/build-$(date +%Y%m%d-%H%M%S).log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# ============================================================================
# FUNCTIONS
# ============================================================================

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_section() {
    echo "" | tee -a "$LOG_FILE"
    echo "============================================================" | tee -a "$LOG_FILE"
    echo "$1" | tee -a "$LOG_FILE"
    echo "============================================================" | tee -a "$LOG_FILE"
}

check_prerequisites() {
    log_section "Checking Prerequisites"

    # Check API key
    if [[ "$ASC_KEY_ID" == "YOUR_KEY_ID_HERE" ]]; then
        log "ERROR: ASC_KEY_ID not configured. Edit this script or set environment variable."
        exit 1
    fi

    if [[ "$ASC_ISSUER_ID" == "YOUR_ISSUER_ID_HERE" ]]; then
        log "ERROR: ASC_ISSUER_ID not configured. Edit this script or set environment variable."
        exit 1
    fi

    if [[ ! -f "$ASC_KEY_PATH" ]]; then
        log "ERROR: API key file not found at: $ASC_KEY_PATH"
        log "Please download your AuthKey_${ASC_KEY_ID}.p8 from App Store Connect"
        exit 1
    fi

    log "API Key ID: $ASC_KEY_ID"
    log "Issuer ID: $ASC_ISSUER_ID"
    log "Key Path: $ASC_KEY_PATH (found)"

    # Check Xcode
    if ! command -v xcodebuild &> /dev/null; then
        log "ERROR: xcodebuild not found. Is Xcode installed?"
        exit 1
    fi

    XCODE_VERSION=$(xcodebuild -version | head -n 1)
    log "Xcode: $XCODE_VERSION"

    # Check project
    if [[ ! -d "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" ]]; then
        log "ERROR: Project not found at: ${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj"
        exit 1
    fi

    log "Project: ${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj (found)"
    log "All prerequisites satisfied!"
}

pull_latest() {
    log_section "Pulling Latest from GitHub"

    cd "$PROJECT_DIR"

    # Stash any local changes (shouldn't be any in CI)
    git stash --quiet 2>/dev/null || true

    # Pull latest
    git fetch origin main
    git reset --hard origin/main

    COMMIT_HASH=$(git rev-parse --short HEAD)
    COMMIT_MSG=$(git log -1 --pretty=%B | head -n 1)

    log "Updated to: $COMMIT_HASH - $COMMIT_MSG"
}

setup_config() {
    log_section "Setting Up Build Configuration"

    cd "$PROJECT_DIR"

    # Ensure APIConfig exists (copy from template if needed)
    if [[ ! -f "Food1/Config/APIConfig.swift" ]]; then
        if [[ -f "Food1/Config/APIConfig.swift.example" ]]; then
            log "Copying APIConfig.swift from example..."
            cp "Food1/Config/APIConfig.swift.example" "Food1/Config/APIConfig.swift"
        else
            log "WARNING: APIConfig.swift not found and no example available"
        fi
    else
        log "APIConfig.swift exists"
    fi
}

bump_build_number() {
    log_section "Bumping Build Number"

    cd "$PROJECT_DIR"

    # Generate new build number: YYYYMMDDNN (date + daily sequence)
    TODAY=$(date +%Y%m%d)
    PBXPROJ="${PROJECT_NAME}.xcodeproj/project.pbxproj"

    # Get current build number
    CURRENT_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION = " "$PBXPROJ" | sed 's/.*= \([0-9]*\);/\1/')
    log "Current build number: $CURRENT_BUILD"

    # Check if current build is from today
    if [[ "${CURRENT_BUILD:0:8}" == "$TODAY" ]]; then
        # Same day - increment the sequence
        SEQUENCE=$((${CURRENT_BUILD:8} + 1))
        NEW_BUILD="${TODAY}$(printf '%02d' $SEQUENCE)"
    else
        # New day - start at 01
        NEW_BUILD="${TODAY}01"
    fi

    log "New build number: $NEW_BUILD"

    # Update build number in project.pbxproj (for main target only, lines with Release config)
    sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = ${NEW_BUILD};/g" "$PBXPROJ"

    log "Build number updated in project"
}

clean_build() {
    log_section "Cleaning Previous Build"

    cd "$PROJECT_DIR"

    # Remove old build artifacts
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    # Clean Xcode build
    xcodebuild clean \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        2>&1 | tee -a "$LOG_FILE"

    log "Build directory cleaned"
}

build_archive() {
    log_section "Building Archive"

    cd "$PROJECT_DIR"

    # Build archive
    xcodebuild archive \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=iOS" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$ASC_KEY_PATH" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
        2>&1 | tee -a "$LOG_FILE"

    if [[ ! -d "$ARCHIVE_PATH" ]]; then
        log "ERROR: Archive was not created!"
        exit 1
    fi

    log "Archive created: $ARCHIVE_PATH"
}

export_and_upload() {
    log_section "Exporting & Uploading to TestFlight"

    cd "$PROJECT_DIR"

    # Export and upload in one step, capture exit code
    set +e  # Temporarily disable exit on error
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS" \
        -exportPath "$EXPORT_PATH" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$ASC_KEY_PATH" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
        2>&1 | tee -a "$LOG_FILE"
    EXPORT_RESULT=${PIPESTATUS[0]}
    set -e  # Re-enable exit on error

    # Check if export succeeded
    if [[ $EXPORT_RESULT -ne 0 ]]; then
        log "ERROR: Export/upload failed with code $EXPORT_RESULT"
        log "Check the log for details: $LOG_FILE"
        exit 1
    fi

    log "Export and upload completed successfully!"
}

send_notification() {
    log_section "Build Complete"

    # Get build info
    INFO_PLIST="${ARCHIVE_PATH}/Products/Applications/${PROJECT_NAME}.app/Info.plist"
    if [[ -f "$INFO_PLIST" ]]; then
        VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "unknown")
        BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "unknown")
        log "Version: $VERSION ($BUILD)"
    fi

    log "TestFlight build submitted successfully!"
    log "Check App Store Connect for processing status."
    log ""
    log "Build log saved to: $LOG_FILE"

    # Optional: Add notification hooks here (Slack, Discord, email, etc.)
    # Example: curl -X POST "your-webhook-url" -d "{\"text\": \"Food1 $VERSION build submitted to TestFlight\"}"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log_section "Food1 TestFlight Build Started"
    log "Timestamp: $TIMESTAMP"
    log "Log file: $LOG_FILE"

    check_prerequisites
    pull_latest
    setup_config
    bump_build_number
    clean_build
    build_archive
    export_and_upload
    send_notification

    log_section "BUILD SUCCESSFUL"
}

# Run main function
main "$@"
