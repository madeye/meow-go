#!/usr/bin/env bash
#
# End-to-end test: mihomo-android on Android emulator
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EMULATOR="${EMULATOR:-/Volumes/Data/workspace/android/emulator/emulator}"
ADB="${ADB:-/Volumes/Data/workspace/android/platform-tools/adb}"
AVD="${AVD:-Medium_Phone_API_36.1}"
APK="${APK:-$SCRIPT_DIR/mobile/build/outputs/apk/debug/mobile-arm64-v8a-debug.apk}"
SSSERVER="${SSSERVER:-ssserver}"
V2RAY_PLUGIN="${V2RAY_PLUGIN:-v2ray-plugin}"
PKG="io.github.madeye.meow"

SS_ADDR="0.0.0.0:8388"
SS_PASSWORD="testpassword123"
SS_METHOD="aes-256-gcm"
SS_HOST_FROM_EMU="10.0.2.2"
SS_PORT=8388
SUB_PORT=8080

SSSERVER_PID=""
HTTPD_PID=""

cleanup() {
    echo ""
    echo "=== Cleanup ==="
    for pid_var in SSSERVER_PID HTTPD_PID; do
        pid="${!pid_var}"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "Killing $pid_var (PID $pid)"
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        fi
    done
    rm -rf /tmp/test-sub
    if [[ "${SKIP_EMULATOR_BOOT:-}" != "true" ]] && "$ADB" get-state &>/dev/null; then
        echo "Shutting down emulator..."
        "$ADB" emu kill 2>/dev/null || true
    fi
    echo "Cleanup done."
}
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
info() { echo "--- $*"; }

ensure_emulator() {
    # Quick check: does adb see any device? (no timeout risk)
    local state
    state=$("$ADB" get-state 2>&1 || true)
    if [[ "$state" != "device" ]]; then
        fail "Emulator crashed or disconnected (adb state: $state)"
    fi
}

wait_for_boot() {
    info "Waiting for emulator to boot..."
    "$ADB" wait-for-device
    local n=0
    while [[ $n -lt 120 ]]; do
        # Check if emulator process is still alive
        if ! "$ADB" get-state 2>/dev/null | grep -q "device"; then
            if [[ $n -gt 10 ]]; then
                fail "Emulator process died during boot"
            fi
        fi
        local val
        val=$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n')
        if [[ "$val" == "1" ]]; then
            info "Emulator booted."
            return 0
        fi
        sleep 2
        n=$((n + 2))
    done
    fail "Emulator did not boot within 120s"
}

screenshot() {
    local name="$1"
    "$ADB" shell screencap -p /sdcard/screen_${name}.png 2>/dev/null || true
    "$ADB" pull /sdcard/screen_${name}.png "$SCRIPT_DIR/screen_${name}.png" 2>/dev/null || true
    info "  Screenshot saved: screen_${name}.png"
}

# Step 1: Prerequisites
info "Step 1: Verify prerequisites"
command -v "$SSSERVER" &>/dev/null || [[ -f "$SSSERVER" ]] || fail "ssserver not found"
[[ -f "$APK" ]] || fail "APK not found at $APK"
[[ "${SKIP_EMULATOR_BOOT:-}" == "true" ]] || [[ -x "$EMULATOR" ]] || command -v "$EMULATOR" &>/dev/null || fail "Emulator not found"
[[ -x "$ADB" ]] || command -v "$ADB" &>/dev/null || fail "adb not found"
info "All prerequisites OK."

# Step 2: ssserver (plain SS, no plugin — mihomo-rust can't spawn v2ray-plugin on Android)
info "Step 2: Starting ssserver on $SS_ADDR ..."
"$SSSERVER" -s "$SS_ADDR" -k "$SS_PASSWORD" -m "$SS_METHOD" -U &
SSSERVER_PID=$!
sleep 1
kill -0 "$SSSERVER_PID" 2>/dev/null || fail "ssserver failed to start"
info "ssserver running (PID $SSSERVER_PID)"

# Step 3: Subscription HTTP server
info "Step 3: Starting subscription HTTP server on port $SUB_PORT ..."
mkdir -p /tmp/test-sub
cat > /tmp/test-sub/config.yaml <<SUBEOF
mixed-port: 7890
mode: rule
log-level: info
allow-lan: false
dns:
  enable: true
  listen: 127.0.0.1:1053
  nameserver:
    - 114.114.114.114
proxies:
  - name: test-ss
    type: ss
    server: $SS_HOST_FROM_EMU
    port: $SS_PORT
    cipher: $SS_METHOD
    password: $SS_PASSWORD
proxy-groups:
  - name: Proxy
    type: select
    proxies:
      - test-ss
rules:
  - MATCH,test-ss
SUBEOF

cd /tmp/test-sub && python3 -m http.server "$SUB_PORT" &
HTTPD_PID=$!
cd "$SCRIPT_DIR"
sleep 1
kill -0 "$HTTPD_PID" 2>/dev/null || fail "HTTP server failed to start"
info "Subscription HTTP server running (PID $HTTPD_PID)"

# Step 4: Boot emulator
if [[ "${SKIP_EMULATOR_BOOT:-}" == "true" ]]; then
    info "Step 4: Skipping emulator boot"
    "$ADB" wait-for-device
else
    info "Step 4: Booting emulator ($AVD) ..."
    "$EMULATOR" -avd "$AVD" -no-snapshot-load -no-audio -gpu auto &
    wait_for_boot
    sleep 5
    "$ADB" shell input keyevent KEYCODE_HOME
    sleep 2
fi

"$ADB" shell settings put global window_animation_scale 0
"$ADB" shell settings put global transition_animation_scale 0
"$ADB" shell settings put global animator_duration_scale 0

# Step 5: Install APK and tools
ensure_emulator
info "Step 5: Installing debug APK ..."
"$ADB" uninstall "$PKG" 2>/dev/null || true
"$ADB" install -g "$APK" || fail "APK install failed"
info "APK installed."

# No external binaries needed — tests use nc (netcat) built into Android

# Step 6: Configure subscription
info "Step 6: Configuring subscription..."
info "  Launching app to initialize databases..."
"$ADB" shell am start -W -n "$PKG/.MainActivity"
sleep 8
screenshot "01_init"
"$ADB" shell am force-stop "$PKG"
sleep 2

info "  Creating database with subscription profile on host..."
SUB_YAML=$(cat /tmp/test-sub/config.yaml)

# Create a fresh Room database on the host with the correct schema
rm -f /tmp/mihomo.db /tmp/mihomo.db-wal /tmp/mihomo.db-shm
sqlite3 /tmp/mihomo.db <<DBEOF
CREATE TABLE IF NOT EXISTS room_master_table (id INTEGER PRIMARY KEY,identity_hash TEXT);
INSERT OR REPLACE INTO room_master_table (id,identity_hash) VALUES(42,'7f1239e0c92bebb6bf8dc11159ea06e5');
CREATE TABLE IF NOT EXISTS clash_profile (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    yaml_content TEXT NOT NULL,
    selected INTEGER NOT NULL,
    last_updated INTEGER NOT NULL,
    tx INTEGER NOT NULL,
    rx INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS daily_traffic (
    date TEXT NOT NULL,
    tx INTEGER NOT NULL,
    rx INTEGER NOT NULL,
    PRIMARY KEY(date)
);
INSERT INTO clash_profile (name, url, yaml_content, selected, last_updated, tx, rx)
VALUES ('Test Sub', 'http://$SS_HOST_FROM_EMU:$SUB_PORT/config.yaml', '$(echo "$SUB_YAML" | sed "s/'/''/g")', 1, $(date +%s), 0, 0);
DBEOF

info "  Verifying profile..."
sqlite3 /tmp/mihomo.db "SELECT id, name, selected FROM clash_profile;" | while IFS= read -r line; do
    info "    Profile: $line"
done

# Push to device — use run-as to place it in app's database dir
"$ADB" push /tmp/mihomo.db /data/local/tmp/mihomo.db
"$ADB" shell "cat /data/local/tmp/mihomo.db | run-as $PKG sh -c 'cat > databases/mihomo.db'"
"$ADB" shell "run-as $PKG rm -f databases/mihomo.db-wal databases/mihomo.db-shm"
"$ADB" shell rm -f /data/local/tmp/mihomo.db
info "  Subscription configuration done."

# Step 7: Enable VPN
ensure_emulator
info "Step 7: Enabling VPN..."

# Launch app with auto_connect=true intent extra — triggers VPN start after 1s
"$ADB" shell am start -W -n "$PKG/.MainActivity" --ez auto_connect true
sleep 2
screenshot "02_app_launched"

# Handle VPN consent dialog
info "  Checking for VPN consent dialog..."
VPN_ACCEPTED=false

# Helper: try to tap the positive button in the VPN consent dialog.
# Returns 0 if the dialog is dismissed, 1 otherwise.
try_dismiss_vpn_dialog() {
    # Dump current UI hierarchy
    "$ADB" shell uiautomator dump /sdcard/ui_dump.xml 2>/dev/null || true
    "$ADB" pull /sdcard/ui_dump.xml /tmp/ui_dump.xml 2>/dev/null || true
    local ui_xml
    ui_xml=$(cat /tmp/ui_dump.xml 2>/dev/null || true)

    if [[ -z "$ui_xml" ]]; then
        info "  uiautomator dump returned empty, skipping XML-based tap"
        return 1
    fi

    # Log the dump for debugging
    info "  UI dump size: ${#ui_xml} bytes"

    # Strategy 1: Find button by resource-id (android:id/button1 is the standard positive button)
    local ok_line
    ok_line=$(echo "$ui_xml" | tr '>' '\n' | grep -F 'resource-id="android:id/button1"' | head -1 || true)

    # Strategy 2: Find button by text — match common labels across Android versions/locales
    if [[ -z "$ok_line" ]]; then
        ok_line=$(echo "$ui_xml" | tr '>' '\n' | grep -iE 'text="(OK|Ok|ok|Allow|ALLOW|Got it|GOT IT|Okay|OKAY)"' | head -1 || true)
    fi

    # Strategy 3: Find any clickable Button widget as last resort
    if [[ -z "$ok_line" ]]; then
        ok_line=$(echo "$ui_xml" | tr '>' '\n' | grep -E 'class="android\.widget\.Button".*clickable="true"' | tail -1 || true)
    fi

    if [[ -n "$ok_line" ]]; then
        local ok_bounds
        ok_bounds=$(echo "$ok_line" | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' || true)
        if [[ -n "$ok_bounds" ]]; then
            local nums x1 y1 x2 y2
            nums=$(echo "$ok_bounds" | grep -o '[0-9]*')
            x1=$(echo "$nums" | sed -n '1p'); y1=$(echo "$nums" | sed -n '2p')
            x2=$(echo "$nums" | sed -n '3p'); y2=$(echo "$nums" | sed -n '4p')
            local cx=$(( (x1 + x2) / 2 )) cy=$(( (y1 + y2) / 2 ))
            info "  Tapping button at ($cx, $cy)"
            "$ADB" shell input tap "$cx" "$cy"
            sleep 2

            # Verify dialog was dismissed
            if ! "$ADB" shell dumpsys activity activities 2>/dev/null | grep -qi "vpndialogs"; then
                return 0
            fi
        fi
    fi
    return 1
}

for i in $(seq 1 15); do
    ACTIVITIES=$("$ADB" shell dumpsys activity activities 2>/dev/null || true)
    if echo "$ACTIVITIES" | grep -qi "vpndialogs\|com.android.vpndialogs"; then
        info "  VPN consent dialog detected (attempt $i), accepting..."
        screenshot "03_vpn_dialog"
        sleep 1

        # Try XML-based button tap (up to 3 attempts — dump can be flaky)
        for attempt in 1 2 3; do
            if try_dismiss_vpn_dialog; then
                VPN_ACCEPTED=true
                break 2
            fi
            info "  Tap attempt $attempt did not dismiss dialog, retrying..."
            sleep 1
        done

        # Fallback: keyboard navigation (TAB to focus OK button, ENTER to press)
        if "$ADB" shell dumpsys activity activities 2>/dev/null | grep -qi "vpndialogs"; then
            info "  Trying keyboard fallback (TAB+ENTER)..."
            "$ADB" shell input keyevent KEYCODE_TAB; sleep 0.3
            "$ADB" shell input keyevent KEYCODE_TAB; sleep 0.3
            "$ADB" shell input keyevent KEYCODE_ENTER; sleep 2
        fi

        # Fallback: DPAD navigation (for TV-style or keyboard-driven UIs)
        if "$ADB" shell dumpsys activity activities 2>/dev/null | grep -qi "vpndialogs"; then
            info "  Trying DPAD fallback..."
            "$ADB" shell input keyevent KEYCODE_DPAD_RIGHT; sleep 0.3
            "$ADB" shell input keyevent KEYCODE_DPAD_CENTER; sleep 2
        fi

        VPN_ACCEPTED=true
        screenshot "04_after_vpn_accept"
        break
    fi
    sleep 1
done

if [[ "$VPN_ACCEPTED" != "true" ]]; then
    info "  No VPN consent dialog (may already be approved)"
fi

# Step 8: Verify connectivity
ensure_emulator
info "Step 8: Verifying VPN connection..."
sleep 8
screenshot "05_vpn_status"

PASS=0
TOTAL=5

ensure_emulator
info "  Test 1: tun0 interface..."
TUN_CHECK=$("$ADB" shell ip addr show tun0 2>&1 || true)
if echo "$TUN_CHECK" | grep -q "inet "; then
    info "  PASS: tun0 exists"; PASS=$((PASS + 1))
else
    echo "  FAIL: tun0 not found"
fi

ensure_emulator
info "  Test 2: DNS resolution..."
DNS_OUT=$("$ADB" shell "ping -c 1 -W 5 google.com 2>&1" || true)
if echo "$DNS_OUT" | grep -qE "PING google\.com \([0-9]+\.[0-9]+"; then
    info "  PASS: DNS OK"; PASS=$((PASS + 1))
else
    echo "  FAIL: DNS failed"
fi

ensure_emulator
info "  Test 3: TCP 1.1.1.1:80..."
NC1=$("$ADB" shell "echo '' | nc -w 5 1.1.1.1 80 >/dev/null 2>&1; echo \$?" | tr -d '\r' | tail -1)
if [[ "$NC1" == "0" ]]; then
    info "  PASS"; PASS=$((PASS + 1))
else
    echo "  FAIL (exit=$NC1)"
fi

ensure_emulator
info "  Test 4: TCP 8.8.8.8:443..."
NC2=$("$ADB" shell "echo '' | nc -w 5 8.8.8.8 443 >/dev/null 2>&1; echo \$?" | tr -d '\r' | tail -1)
if [[ "$NC2" == "0" ]]; then
    info "  PASS"; PASS=$((PASS + 1))
else
    echo "  FAIL (exit=$NC2)"
fi

ensure_emulator
info "  Test 5: HTTP request..."
# Use a shell script on device: write HTTP request, then sleep to keep connection open for response.
HTTP_OUT=$("$ADB" shell "{ printf 'GET /config.yaml HTTP/1.0\r\nHost: 10.0.2.2\r\nConnection: close\r\n\r\n'; sleep 5; } | nc 10.0.2.2 $SUB_PORT 2>/dev/null | head -1" | tr -d '\r' || true)
info "  HTTP response: $HTTP_OUT"
if echo "$HTTP_OUT" | grep -qE "HTTP/.* 200"; then
    info "  PASS: HTTP 200"; PASS=$((PASS + 1))
else
    # Fallback: try Google's generate_204 endpoint
    info "  Trying Google generate_204..."
    HTTP_OUT2=$("$ADB" shell "{ printf 'GET /generate_204 HTTP/1.0\r\nHost: connectivitycheck.gstatic.com\r\nConnection: close\r\n\r\n'; sleep 5; } | nc 142.251.46.228 80 2>/dev/null | head -1" | tr -d '\r' || true)
    info "  HTTP response: $HTTP_OUT2"
    if echo "$HTTP_OUT2" | grep -qE "HTTP/.* (200|204|301|302)"; then
        HTTP_CODE=$(echo "$HTTP_OUT2" | grep -oE "[0-9]{3}" | head -1)
        info "  PASS: HTTP $HTTP_CODE"; PASS=$((PASS + 1))
    else
        echo "  FAIL: HTTP requests failed"
    fi
fi

info "  Recent VPN logcat:"
"$ADB" logcat -d 2>/dev/null | grep -iE "mihomo|vpn|tun" | tail -30 || true

echo ""
echo "========================================"
echo "  E2E Test Results: $PASS/$TOTAL passed"
echo "========================================"
if [[ $PASS -eq $TOTAL ]]; then
    echo "  ALL TESTS PASSED"; exit 0
else
    echo "  SOME TESTS FAILED"; exit 1
fi
