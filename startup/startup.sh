#!/bin/bash
# Startup - Demo Version
# Simplified automation suite focusing on VPN and backup functionality

# Configuration
LOG_DIR="$HOME/.local/share/startup-services"
LOG_FILE="$LOG_DIR/startup.log"
RCLONE_REMOTE="gdrive"
BACKUP_PATH="$HOME/Documents"
PROTONVPN_CONFIG="$HOME/.config/Proton/VPN/app-config.json"

# Timing configurations
GNOME_LOAD_DELAY=5
VPN_START_DELAY=4
VPN_CONNECTION_TIMEOUT=30
BACKUP_UPLOAD_DELAY=60

# Max log file size (10MB)
MAX_LOG_SIZE=10485760

# Create log directory
mkdir -p "$LOG_DIR"

# Rotate logs if needed
rotate_logs() {
    if [ -f "$LOG_FILE" ]; then
        local size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            mv "$LOG_FILE" "$LOG_FILE.old"
            gzip "$LOG_FILE.old" &
        fi
    fi
}

rotate_logs

# Logging function
log() {
    local level="${2:-INFO}"
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo "$timestamp [$level] $1" | tee -a "$LOG_FILE"
}

# Notification function
notify() {
    notify-send "Startup Services" "$1" -i "$2" -t 3000
}

# Cleanup function
cleanup() {
    unset GPG_PASSPHRASE
}
trap cleanup EXIT

# Check dependencies
check_dependencies() {
    local missing=()
    for cmd in zenity notify-send gpg tar rclone secret-tool; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log "Missing dependencies: ${missing[*]}" "ERROR"
        notify "❌ Missing dependencies: ${missing[*]}" "dialog-error"
        return 1
    fi
    return 0
}

# Check network connectivity
check_network() {
    if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
        log "No network connectivity detected" "WARN"
        return 1
    fi
    return 0
}

# Check if AppIndicator is enabled (needed for ProtonVPN tray icon)
check_appindicator() {
    if ! gnome-extensions list 2>/dev/null | grep -q "appindicator"; then
        log "AppIndicator extension not found - ProtonVPN tray icon may not appear" "WARN"
        notify "⚠️ AppIndicator extension not installed\nProtonVPN tray icon may not appear" "dialog-warning"
        return 1
    fi
    if ! gnome-extensions info appindicatorsupport@rgcjonas.gmail.com 2>/dev/null | grep -q "State: ENABLED"; then
        log "AppIndicator extension not enabled - enabling now..." "WARN"
        notify "⚠️ Enabling AppIndicator extension..." "dialog-warning"
        gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com
        sleep 2
    fi
    return 0
}

# Verify ProtonVPN config
verify_protonvpn_config() {
    if [ ! -f "$PROTONVPN_CONFIG" ]; then
        log "ProtonVPN config file not found at $PROTONVPN_CONFIG" "ERROR"
        return 1
    fi
    
    local connect_setting=$(grep -o '"connect_at_app_startup": *"[^"]*"' "$PROTONVPN_CONFIG" | cut -d'"' -f4)
    
    if [ -z "$connect_setting" ]; then
        log "Could not read connect_at_app_startup setting" "WARN"
        return 1
    fi
    
    log "ProtonVPN autoconnect setting: $connect_setting" "INFO"
    return 0
}

# Check VPN connection status
check_vpn_connection() {
    if ip a 2>/dev/null | grep -q "proton"; then
        return 0
    fi
    return 1
}

# Start ProtonVPN
start_protonvpn() {
    log "Starting ProtonVPN..."
    
    # Kill any existing instances first
    if pgrep -x protonvpn-app >/dev/null; then
        log "ProtonVPN already running - restarting..." "WARN"
        pkill -x protonvpn-app
        sleep 2
    fi
    
    verify_protonvpn_config
    sleep "$GNOME_LOAD_DELAY"
    
    log "Launching ProtonVPN with --start-minimized flag..."
    
    (
        protonvpn-app --start-minimized 2> >(grep -v "No server available" >> "$LOG_DIR/protonvpn.log") &
        
        sleep "$VPN_START_DELAY"
        
        if pgrep -x protonvpn-app >/dev/null; then
            log "ProtonVPN started successfully (PID: $(pgrep -x protonvpn-app))" "SUCCESS"
            notify "✅ ProtonVPN started and minimized" "network-vpn"
            
            local elapsed=0
            local connected=false
            while [ $elapsed -lt "$VPN_CONNECTION_TIMEOUT" ]; do
                if grep -q "CONN:STATE_CHANGED | Connected" "$LOG_DIR/protonvpn.log" 2>/dev/null || check_vpn_connection; then
                    log "ProtonVPN connection established after ${elapsed}s" "SUCCESS"
                    connected=true
                    break
                fi
                sleep 1
                ((elapsed++))
            done
            
            if ! $connected; then
                log "ProtonVPN started but connection status unknown after ${VPN_CONNECTION_TIMEOUT}s timeout" "WARN"
            fi
        else
            log "ProtonVPN failed to start - check $LOG_DIR/protonvpn.log for details" "ERROR"
            notify "❌ ProtonVPN failed to start" "dialog-error"
        fi
    ) & disown
}

# Start services function
start_services() {
    local start_time=$(date +%s)
    log "========== Starting Services ==========" "INFO"
    
    if ! check_dependencies; then
        log "Cannot start services - missing dependencies" "ERROR"
        return 1
    fi
    
    # Start Bluetooth
    log "Starting Bluetooth service..."
    if sudo -n /usr/bin/systemctl start bluetooth 2>/dev/null; then
        log "Bluetooth started" "SUCCESS"
    else
        log "Bluetooth failed to start (may need sudo access)" "ERROR"
        notify "⚠️ Bluetooth failed to start" "dialog-warning"
    fi
    
    check_appindicator
    start_protonvpn
    start_obsidian_backup
    
    local elapsed=$(($(date +%s) - start_time))
    log "All startup services initiated in ${elapsed}s" "SUCCESS"
    notify "✅ Startup services launched" "emblem-default"
}

# Obsidian backup function
start_obsidian_backup() {
    log "Starting Obsidian Vault backup process..."
    
    local vault_path="$BACKUP_PATH/Obsidian Vault"
    
    if [ ! -d "$vault_path" ]; then
        log "Obsidian Vault directory not found at $vault_path" "ERROR"
        notify "⚠️ Obsidian Vault not found - skipping backup" "dialog-warning"
        return 1
    fi
    
    cd "$BACKUP_PATH" || {
        log "Failed to change to backup directory: $BACKUP_PATH" "ERROR"
        notify "❌ Backup failed: Directory not accessible" "dialog-error"
        return 1
    }
    
    GPG_PASSPHRASE="$(secret-tool lookup service startup_key passphrase startup_passphrase 2>/dev/null)"
    
    if [ -z "$GPG_PASSPHRASE" ]; then
        log "Failed to retrieve GPG passphrase from keyring" "ERROR"
        notify "❌ Backup failed: No GPG passphrase in keyring" "dialog-error"
        return 1
    fi
    
    log "Creating encrypted archive of Obsidian Vault..."
    if tar czf - "Obsidian Vault" 2>>"$LOG_FILE" | \
        gpg --yes --symmetric --cipher-algo AES256 \
            --batch --passphrase "$GPG_PASSPHRASE" \
            -o folder.tar.gz.gpg 2>>"$LOG_FILE"; then
        log "Encrypted archive created successfully" "SUCCESS"
        
        local archive_size=$(du -h folder.tar.gz.gpg | cut -f1)
        log "Archive size: $archive_size" "INFO"
        
        if gpg --batch --passphrase "$GPG_PASSPHRASE" -d folder.tar.gz.gpg 2>/dev/null | tar tz &>/dev/null; then
            log "Archive integrity verified" "SUCCESS"
        else
            log "Archive verification failed!" "ERROR"
            notify "❌ Backup archive corrupted" "dialog-error"
            unset GPG_PASSPHRASE
            return 1
        fi
    else
        log "Failed to create encrypted archive" "ERROR"
        notify "❌ Backup encryption failed" "dialog-error"
        unset GPG_PASSPHRASE
        return 1
    fi
    
    unset GPG_PASSPHRASE
    
    # Upload to Google Drive in background
    (
        sleep "$BACKUP_UPLOAD_DELAY"
        log "Starting rclone upload to Google Drive..."
        
        if ! check_network; then
            log "No network connectivity - backup upload skipped" "WARN"
            notify "⚠️ Backup upload skipped - no network" "dialog-warning"
            return 1
        fi
        
        if ! rclone listremotes 2>/dev/null | grep -q "^${RCLONE_REMOTE}:"; then
            log "rclone remote '${RCLONE_REMOTE}' not configured" "ERROR"
            notify "❌ Backup upload failed: rclone not configured" "dialog-error"
            return 1
        fi
        
        if ! rclone about "${RCLONE_REMOTE}:" &>/dev/null; then
            log "rclone authentication failed - run: rclone config reconnect ${RCLONE_REMOTE}:" "ERROR"
            notify "❌ Backup upload failed: rclone auth expired\nRun: rclone config reconnect ${RCLONE_REMOTE}:" "dialog-error"
            return 1
        fi
        
        log "Uploading to ${RCLONE_REMOTE}:/Obsidian Vault..." "INFO"
        local upload_start=$(date +%s)
        
        if rclone copy --progress --checksum --drive-chunk-size 64M \
            "$BACKUP_PATH/folder.tar.gz.gpg" \
            "${RCLONE_REMOTE}:/Obsidian Vault" \
            >> "$LOG_FILE" 2>&1; then
            local upload_time=$(($(date +%s) - upload_start))
            log "Backup uploaded successfully to Google Drive in ${upload_time}s" "SUCCESS"
            notify "✅ Obsidian Vault backed up to Google Drive" "cloud-upload"
        else
            log "rclone upload failed - check $LOG_FILE for details" "ERROR"
            notify "❌ Backup upload failed" "dialog-error"
        fi
    ) & disown
    
    log "Backup process initiated (upload will complete in background)" "INFO"
}

# Stop services function
stop_services() {
    local start_time=$(date +%s)
    log "========== Stopping Services ==========" "INFO"
    
    log "Stopping ProtonVPN..."
    if pgrep -x protonvpn-app >/dev/null; then
        pkill -x protonvpn-app
        sleep 2
        if ! pgrep -x protonvpn-app >/dev/null; then
            log "ProtonVPN stopped" "SUCCESS"
        else
            log "ProtonVPN failed to stop completely" "WARN"
            pkill -9 -x protonvpn-app
        fi
    else
        log "ProtonVPN was not running" "WARN"
    fi
    
    local elapsed=$(($(date +%s) - start_time))
    log "Services stopped in ${elapsed}s" "SUCCESS"
    log "NOTE: Bluetooth remains active" "INFO"
    notify "🛑 Startup services stopped" "emblem-default"
}

# Status check function
check_service_status() {
    log "========== Service Status Check ==========" "INFO"
    
    if pgrep -x protonvpn-app >/dev/null; then
        local vpn_pid=$(pgrep -x protonvpn-app)
        log "ProtonVPN: Running (PID: $vpn_pid)" "INFO"
        
        if check_vpn_connection; then
            log "ProtonVPN: Connected to VPN" "SUCCESS"
        else
            log "ProtonVPN: Running but not connected" "WARN"
        fi
    else
        log "ProtonVPN: Not running" "WARN"
    fi
    
    if systemctl is-active --quiet bluetooth; then
        log "Bluetooth: Active" "INFO"
    else
        log "Bluetooth: Inactive" "WARN"
    fi
    
    log "=========================================" "INFO"
}

# Main logic
main() {
    log "========== Startup Script Executed (Demo Version) ==========" "INFO"
    log "Script location: $0" "INFO"
    log "User: $USER" "INFO"
    log "Log file: $LOG_FILE" "INFO"
    
    if pgrep -x protonvpn-app >/dev/null 2>&1; then
        zenity --question \
            --title="Startup Services Manager" \
            --text="✅ <b>Services are currently running</b>\n\nDo you want to stop them?\n\n<i>Note: Bluetooth will remain active</i>" \
            --ok-label="Yes, Stop Services" \
            --cancel-label="No, Keep Running" \
            --width=400 \
            --window-icon=info
        
        if [ $? -eq 0 ]; then
            stop_services
        else
            log "User chose to keep services running" "INFO"
            check_service_status
        fi
    else
        zenity --question \
            --title="Startup Services Manager" \
            --text="🛑 <b>Services are not running</b>\n\nDo you want to start them?" \
            --ok-label="Yes, Start Services" \
            --cancel-label="No" \
            --width=350 \
            --window-icon=info
        
        if [ $? -eq 0 ]; then
            start_services
        else
            log "User cancelled service startup" "INFO"
        fi
    fi
    
    log "========== Script Finished ==========" "INFO"
}

# Execute main function
main