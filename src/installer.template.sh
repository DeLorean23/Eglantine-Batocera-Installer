#!/bin/bash
# Eglantine Installer & Updater for Batocera v43
# Installs the Eglantine Switch 2 emulator (https://github.com/Djihads80/Eglantine)
# as its own system "Switch 2" and updates it when a newer build is available.
# Created by DeLorean23
# https://github.com/DeLorean23/Eglantine-Batocera-Installer
# License: MIT

set -uo pipefail

REPO="Djihads80/Eglantine"
API_URL="https://api.github.com/repos/${REPO}/releases?per_page=20"

BASE="/userdata/system/eglantine"
BIN="$BASE/bin"
BACKUP="$BASE/backup"
TMP="$BASE/tmp"
USERDIR="$BASE/user"                 # Eglantine portable data folder (config, saves, cache)
ASSETS="$BASE/assets"
VERSION_FILE="$BASE/version.txt"
VARIANT_FILE="$BASE/variant.txt"     # which build is installed: pgo or normal
VARIANT="@@VARIANT@@"                # build this installer installs
VARIANT_LABEL="@@VARIANT_LABEL@@"
ROM_DIR="/userdata/roms/switch2"
BIOS_DIR="/userdata/bios/switch2"
KEYS_DIR="$BIOS_DIR/keys"
FW_DIR="$BIOS_DIR/firmware"
ES_CFG="/userdata/system/configs/emulationstation/es_systems_switch2.cfg"
LOG_DIR="/userdata/system/logs"
LOG="$LOG_DIR/eglantine-installer.log"

SELF="$(readlink -f "$0")"
SELF_DIR="$(dirname "$SELF")"
SELF_NAME="$(basename "$SELF")"
SELF_STEM="${SELF_NAME%.*}"

# ---------------------------------------------------------------------------
# Open a visible terminal window (Ports scripts run without one by default)
# ---------------------------------------------------------------------------
if [[ "${1:-}" != "--in-terminal" ]]; then
    mkdir -p "$LOG_DIR"
    export DISPLAY="${DISPLAY:-:0.0}"
    if command -v xterm >/dev/null 2>&1; then
        exec xterm -fullscreen -fa "Monospace" -fs 11 -bg black -fg white \
            -T "Eglantine Installer & Updater" -e /bin/bash "$SELF" --in-terminal
    fi
    echo "xterm not found - cannot open a terminal window." >> "$LOG"
    exit 1
fi

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG") 2>&1
echo "===== $(date) ====="

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
show_banner() {
cat <<'BANNER'
                                                                                                      .    .
                                                                                                 .      *
                                                                                       _
                                   _       ____,--'`                      __|"/_____ __\"!_   .---.  *   .
                           __..--"`..-='"``                   _________.-----------.'o8888_\-" _." \       .
                     _.-""` .oooo"                        _.-"  `````.' .-"'````""\ \ '. / ""--"". __|  .
                  .-  ,`  '""'`                     ___<"_-._____ .-"_."-._________! \  "-!-``-._   \    *
                ."   /_.-_.-`      ____..--------`"'__..-----''`  \ "----'           |     ____  ".  \  .
              ,"  ` _.-._ _ ___  /'--====--.---''`      __.._      "           _____ /__ ." __ ".  \ | -- - -
          -- /  `    _/        -'--/.^^.7__/__        ." ___ '. ====\=========""''`," "`/ ."  \`||  \
            | ``    <_ -       \____...______/\_____ / `/   '.\\     \       ____.'____/  |(^ | !| _!
             \ ``     '--.      \.._______  /   `'""!|`| (^  ||`"-----===="""          |` '.__' /"`
              "-.`    `._ ._              `"'"------||  \__ .'/ ----================""" "._____. ____
                 `"Oo._     `"oo.____                `'._____' ____
                      `"==-..______. ```                                                               
                                 ````                                                         ____________
                                                                    ________________.

                         
                   Eglantine Installer & Updater
                       Created by DeLorean23
BANNER
printf '\n'
}

fail() {
    echo
    echo "[ERROR] $*"
    echo "Log: $LOG"
    rm -rf "$TMP"
    echo
    wait_key
    exit 1
}

# Writes the controller helper that answers y/n with A/B
write_pad_helper() {
cat > "$1" <<'PY'
import sys, select
try:
    from evdev import InputDevice, list_devices, ecodes as e
except Exception:
    sys.exit(0)
devs = []
for p in list_devices():
    try:
        d = InputDevice(p)
        keys = set(d.capabilities().get(e.EV_KEY, []))
        if e.BTN_SOUTH in keys and e.BTN_EAST in keys:
            devs.append(d)
        else:
            d.close()
    except Exception:
        pass
if not devs:
    sys.exit(0)
fds = {d.fd: d for d in devs}
while True:
    r, _, _ = select.select(list(fds), [], [], 1.0)
    for fd in r:
        try:
            for ev in fds[fd].read():
                if ev.type == e.EV_KEY and ev.value == 1:
                    if ev.code == e.BTN_SOUTH:
                        print("y", flush=True); sys.exit(0)
                    if ev.code == e.BTN_EAST:
                        print("n", flush=True); sys.exit(0)
        except OSError:
            fds.pop(fd, None)
    if not fds:
        sys.exit(0)
PY
}

ask_yes_no() {  # returns 0 for yes, 1 for no
    local prompt="$1" answer="" key pad_pid helper out
    helper="$(mktemp /tmp/eglantine-pad-XXXX.py)"
    out="$(mktemp /tmp/eglantine-pad-XXXX.txt)"
    write_pad_helper "$helper"
    python3 "$helper" > "$out" 2>/dev/null &
    pad_pid=$!
    printf '%s [y/n] (Controller: A = yes, B = no): ' "$prompt"
    while [[ -z "$answer" ]]; do
        if read -rsn1 -t 0.2 key; then
            case "$key" in
                y|Y) answer="y" ;;
                n|N) answer="n" ;;
            esac
        fi
        if [[ -z "$answer" && -s "$out" ]]; then
            answer="$(head -c1 "$out")"
        fi
    done
    kill "$pad_pid" 2>/dev/null; wait "$pad_pid" 2>/dev/null
    rm -f "$helper" "$out"
    echo "$answer"
    [[ "$answer" == "y" ]]
}

wait_key() {  # waits for Enter (keyboard) or A / B (controller)
    local key pad_pid helper out
    helper="$(mktemp /tmp/eglantine-pad-XXXX.py)"
    out="$(mktemp /tmp/eglantine-pad-XXXX.txt)"
    write_pad_helper "$helper"
    python3 "$helper" > "$out" 2>/dev/null &
    pad_pid=$!
    printf 'Press A / Enter to exit '
    while true; do
        if read -rsn1 -t 0.2 key; then break; fi
        [[ -s "$out" ]] && break
    done
    kill "$pad_pid" 2>/dev/null; wait "$pad_pid" 2>/dev/null
    rm -f "$helper" "$out"
    echo
}

extract_payload() {  # extract_payload <name> <target file>
    awk -v n="$1" '$0=="__"n"_BEGIN__"{f=1;next} $0=="__"n"_END__"{f=0} f' "$SELF" | base64 -d > "$2"
}

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------
clear
show_banner

[[ "$(uname -m)" == "x86_64" ]] || fail "This installer only supports x86_64 PCs."
command -v curl >/dev/null 2>&1    || fail "curl not found."
command -v python3 >/dev/null 2>&1 || fail "python3 not found."

GLIBC="$(ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+$')"
if [[ -n "$GLIBC" ]]; then
    if ! python3 -c "import sys; a=tuple(map(int,'$GLIBC'.split('.'))); sys.exit(0 if a>=(2,39) else 1)"; then
        echo "[WARNING] glibc $GLIBC found. Eglantine needs glibc 2.39 or newer and may not start."
        echo
    fi
fi

echo "Checking for the latest Eglantine build..."
RELEASE_JSON="$(mktemp /tmp/eglantine-rel-XXXX.json)"
if ! curl -fsSL -H "Accept: application/vnd.github+json" "$API_URL" -o "$RELEASE_JSON"; then
    rm -f "$RELEASE_JSON"
    fail "Could not reach GitHub. Check the internet connection."
fi

# Pick the newest release that has the Linux x86_64 AppImage of this variant
INFO="$(python3 - "$RELEASE_JSON" "$VARIANT" <<'PY'
import json, sys
try:
    rels = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
if not isinstance(rels, list):
    sys.exit(1)
rels = [r for r in rels if not r.get("draft")]
rels.sort(key=lambda r: r.get("published_at") or "", reverse=True)
for r in rels:
    for a in r.get("assets", []):
        suffix = "-linux-x86_64-pgo.AppImage" if sys.argv[2] == "pgo" else "-linux-x86_64.AppImage"
        if a.get("name", "").endswith(suffix):
            print(r["tag_name"])
            print(r.get("name") or r["tag_name"])
            print(a["browser_download_url"]); print(a["size"])
            sys.exit(0)
sys.exit(2)
PY
)"
rc=$?
rm -f "$RELEASE_JSON"
(( rc == 0 )) || fail "No suitable Linux build found on GitHub (or the GitHub API limit was reached, try again later)."

mapfile -t R <<< "$INFO"
TAG="${R[0]}"; TITLE="${R[1]}"
URL_APP="${R[2]}"; SIZE_APP="${R[3]}"

INSTALLED=""
[[ -f "$VERSION_FILE" ]] && INSTALLED="$(head -n1 "$VERSION_FILE")"
INSTALLED_VARIANT="pgo"
[[ -f "$VARIANT_FILE" ]] && INSTALLED_VARIANT="$(head -n1 "$VARIANT_FILE")"
[[ "$INSTALLED_VARIANT" == "normal" ]] || INSTALLED_VARIANT="pgo"
label() { [[ "$1" == "pgo" ]] && echo "PGO" || echo "non-PGO"; }

FRESH=1
[[ -n "$INSTALLED" && -x "$BIN/$INSTALLED_VARIANT/AppRun" ]] && FRESH=0

echo "Latest build:    $TITLE ($VARIANT_LABEL)"
if [[ -n "$INSTALLED" ]]; then
    echo "Installed build: $INSTALLED ($(label "$INSTALLED_VARIANT"))"
else
    echo "Installed build: none"
fi
echo

if (( FRESH == 0 )) && [[ "$INSTALLED" == "$TAG" && "$INSTALLED_VARIANT" == "$VARIANT" ]]; then
    echo "up to date"
    echo
    wait_key
    exit 0
fi

echo "----------------------------------------------------------------------"
echo " WARNING: This is an unofficial system."
echo " Future Batocera updates may affect it."
if (( FRESH == 1 )); then
    echo
    echo " After the installation Batocera needs a REBOOT."
    echo " You will be asked before it reboots."
fi
echo "----------------------------------------------------------------------"
echo

if (( FRESH == 1 )); then
    QUESTION="Install Eglantine ($TAG)?"
else
    if [[ "$INSTALLED" == "$TAG" ]]; then
        echo "Switching to the $VARIANT_LABEL build ($TAG)"
    else
        echo "Update found: $TAG ($VARIANT_LABEL)"
    fi
    echo
    QUESTION="Install the update?"
fi

if ! ask_yes_no "$QUESTION"; then
    echo
    echo "Cancelled. Nothing was changed."
    echo
    wait_key
    exit 0
fi
echo

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------
rm -rf "$TMP"
mkdir -p "$TMP" || fail "Cannot create $TMP"

download() {  # download <label> <url> <file> <size>
    echo "Downloading $1 build..."
    curl -fL --retry 3 -o "$3" "$2" || fail "Download of the $1 build failed."
    local got
    got="$(stat -c %s "$3" 2>/dev/null || echo 0)"
    [[ "$got" == "$4" ]] || fail "The $1 build is incomplete ($got of $4 bytes)."
    echo
}
download "$VARIANT_LABEL" "$URL_APP" "$TMP/$VARIANT.AppImage" "$SIZE_APP"

# Unpack the AppImages (no FUSE needed, faster start)
echo "Unpacking..."
for v in "$VARIANT"; do
    chmod +x "$TMP/$v.AppImage"
    ( cd "$TMP" && "./$v.AppImage" --appimage-extract >/dev/null 2>&1 ) \
        || fail "Unpacking the $v build failed."
    mv "$TMP/squashfs-root" "$TMP/$v" || fail "Unpacking the $v build failed."
    [[ -x "$TMP/$v/AppRun" ]] || fail "The $v build has no AppRun."
    rm -f "$TMP/$v.AppImage"
done
echo "Done."
echo

# ---------------------------------------------------------------------------
# Install (keep the previous version as backup)
# ---------------------------------------------------------------------------
echo "Installing Eglantine..."
mkdir -p "$BASE"
if [[ -d "$BIN" ]]; then
    rm -rf "$BACKUP"
    mkdir -p "$BACKUP"
    mv "$BIN" "$BACKUP/bin" || fail "Could not back up the previous version."
    [[ -f "$VERSION_FILE" ]] && cp "$VERSION_FILE" "$BACKUP/version.txt"
    [[ -f "$VARIANT_FILE" ]] && cp "$VARIANT_FILE" "$BACKUP/variant.txt"
    echo "Previous version saved to: $BACKUP"
fi
mkdir -p "$BIN"
mv "$TMP/$VARIANT" "$BIN/$VARIANT" || fail "Could not install the new version."
rm -rf "$TMP"
echo "$TAG" > "$VERSION_FILE"
echo "$VARIANT" > "$VARIANT_FILE"

# Folders: games, keys, firmware
mkdir -p "$ROM_DIR" "$KEYS_DIR" "$FW_DIR" "$ASSETS" \
    "$USERDIR/config" "$USERDIR/nand/system/Contents" \
    /userdata/system/configs/emulationstation

# Eglantine reads keys and firmware from its data folder -> link it to bios/switch2
link_dir() {  # link_dir <link> <target>
    if [[ -L "$1" ]]; then
        ln -sfn "$2" "$1"
    elif [[ -d "$1" ]]; then
        cp -an "$1"/. "$2"/ 2>/dev/null
        rm -rf "$1"
        ln -s "$2" "$1"
    else
        ln -s "$2" "$1"
    fi
}
link_dir "$USERDIR/keys" "$KEYS_DIR"
link_dir "$USERDIR/nand/system/Contents/registered" "$FW_DIR"

# Default settings (only the first time, your own settings are never overwritten)
if [[ ! -f "$USERDIR/config/qt-config.ini" ]]; then
cat > "$USERDIR/config/qt-config.ini" <<'INI'
[Renderer]
backend\default=false
backend=1
use_asynchronous_shaders\default=false
use_asynchronous_shaders=true
use_disk_shader_cache\default=false
use_disk_shader_cache=true
INI
fi

# Game launcher used by EmulationStation
cat > "$BASE/launch.sh" <<'SH'
#!/bin/bash
# Starts a game in Eglantine, fullscreen:
#   a Switch 2 game folder (name.s2) or a file (.nsp .nsz .nup .xci .xcz .nca .nro .nso .kip)
BASE="/userdata/system/eglantine"
LOG="/userdata/system/logs/eglantine.log"
CONF="/userdata/system/batocera.conf"
ROM="${1:-}"
if [[ -d "$ROM" ]]; then
    MAIN="$ROM/base/exefs/main"
    [[ -f "$MAIN" ]] || MAIN="$(find "$ROM" -type f -path '*/exefs/main' 2>/dev/null | sort | head -n1)"
    [[ -f "$MAIN" ]] || { echo "No exefs/main in: $ROM" >> "$LOG"; exit 1; }
elif [[ -f "$ROM" ]]; then
    MAIN="$ROM"
else
    echo "Game not found: $ROM" >> "$LOG"; exit 1
fi

V="$(head -n1 "$BASE/variant.txt" 2>/dev/null)"
[[ "$V" == "normal" ]] || V="pgo"
APP="$BASE/bin/$V/AppRun"
[[ -x "$APP" ]] || { echo "Eglantine not installed: $APP" >> "$LOG"; exit 1; }

cd "$BASE" || exit 1   # "user" folder here = portable data folder
{ echo "===== $(date) ====="; echo "Game: $ROM"; echo "Build: $V"; } >> "$LOG"

setsid "$APP" -f -g "$MAIN" >> "$LOG" 2>&1 &
PID=$!
python3 "$BASE/hotkey.py" "$PID" >> "$LOG" 2>&1 &
HK=$!
python3 "$BASE/dialogpad.py" "$PID" >> "$LOG" 2>&1 &
DP=$!
wait "$PID"
RC=$?
kill "$HK" "$DP" 2>/dev/null
exit "$RC"
SH

# Controller support for pop-up windows before a game starts
# (e.g. "Use the recommended settings for Mario Kart World?")
cat > "$BASE/dialogpad.py" <<'PY'
#!/usr/bin/python3
# Controller support for emulator pop-up windows (e.g. "Use the recommended
# settings?" before a game starts). Only active while a dialog window has the
# focus, so it never sends keys into a running game.
#   D-pad left / right -> Shift+Tab / Tab   (switch between buttons)
#   D-pad up / down    -> Up / Down         (lists)
#   A                  -> Enter             (confirm the marked button)
#   B                  -> Escape            (No / Cancel)
# Usage: dialogpad.py <emulator pid>
import ctypes
import ctypes.util
import os
import select
import sys
import time

PID = int(sys.argv[1]) if len(sys.argv) > 1 else 0


def alive():
    if not PID:
        return True
    try:
        os.kill(PID, 0)
        return True
    except OSError:
        return False


# --------------------------------------------------------------------------
# X11: is the focused window a dialog?
# --------------------------------------------------------------------------
class X11:
    def __init__(self):
        name = ctypes.util.find_library("X11") or "libX11.so.6"
        x = ctypes.CDLL(name)
        x.XOpenDisplay.restype = ctypes.c_void_p
        x.XOpenDisplay.argtypes = [ctypes.c_char_p]
        x.XDefaultRootWindow.restype = ctypes.c_ulong
        x.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
        x.XInternAtom.restype = ctypes.c_ulong
        x.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
        x.XGetWindowProperty.argtypes = [
            ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_long, ctypes.c_long,
            ctypes.c_int, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong),
            ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_ulong),
            ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_void_p)]
        x.XFree.argtypes = [ctypes.c_void_p]
        x.XGetInputFocus.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_ulong),
                                     ctypes.POINTER(ctypes.c_int)]
        x.XQueryTree.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong),
                                 ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_void_p),
                                 ctypes.POINTER(ctypes.c_uint)]
        x.XSetErrorHandler.restype = ctypes.c_void_p
        self._err = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p)(lambda d, e: 0)
        x.XSetErrorHandler(self._err)
        self.x = x
        self.d = x.XOpenDisplay(None)
        if not self.d:
            raise RuntimeError("no X display")
        self.root = x.XDefaultRootWindow(self.d)
        atom = lambda n: x.XInternAtom(self.d, n, 0)
        self.a_active = atom(b"_NET_ACTIVE_WINDOW")
        self.a_type = atom(b"_NET_WM_WINDOW_TYPE")
        self.a_dialog = atom(b"_NET_WM_WINDOW_TYPE_DIALOG")
        self.a_transient = atom(b"WM_TRANSIENT_FOR")

    def _prop(self, win, prop):
        t, f = ctypes.c_ulong(), ctypes.c_int()
        n, after = ctypes.c_ulong(), ctypes.c_ulong()
        data = ctypes.c_void_p()
        ok = self.x.XGetWindowProperty(self.d, win, prop, 0, 64, 0, 0,
                                       ctypes.byref(t), ctypes.byref(f), ctypes.byref(n),
                                       ctypes.byref(after), ctypes.byref(data))
        if ok != 0 or not data.value:
            return []
        try:
            if f.value != 32:
                return []
            arr = ctypes.cast(data, ctypes.POINTER(ctypes.c_ulong))
            return [arr[i] for i in range(n.value)]
        finally:
            self.x.XFree(data)

    def _is_dialog(self, win):
        return self.a_dialog in self._prop(win, self.a_type) or bool(self._prop(win, self.a_transient))

    def _focus_chain(self):
        """Focused window and its parents (works with and without a window manager)."""
        focus, rev = ctypes.c_ulong(), ctypes.c_int()
        self.x.XGetInputFocus(self.d, ctypes.byref(focus), ctypes.byref(rev))
        win, out = focus.value, []
        for _ in range(8):
            if win in (0, 1, self.root):
                break
            out.append(win)
            root, parent = ctypes.c_ulong(), ctypes.c_ulong()
            kids, n = ctypes.c_void_p(), ctypes.c_uint()
            if not self.x.XQueryTree(self.d, win, ctypes.byref(root), ctypes.byref(parent),
                                     ctypes.byref(kids), ctypes.byref(n)):
                break
            if kids.value:
                self.x.XFree(kids)
            win = parent.value
        return out

    def dialog_focused(self):
        act = self._prop(self.root, self.a_active)
        if act and act[0] and self._is_dialog(act[0]):
            return True
        return any(self._is_dialog(w) for w in self._focus_chain())


# --------------------------------------------------------------------------
# Controller -> keyboard
# --------------------------------------------------------------------------
def main():
    os.environ.setdefault("DISPLAY", ":0.0")
    try:
        from evdev import InputDevice, list_devices, UInput, ecodes as e
    except Exception:
        return
    xs = None
    for _ in range(20):          # X may need a moment
        try:
            xs = X11()
            break
        except Exception:
            time.sleep(0.5)
    if xs is None:
        return

    pads = {}
    for p in list_devices():
        try:
            d = InputDevice(p)
            keys = set(d.capabilities().get(e.EV_KEY, []))
            if e.BTN_SOUTH in keys and e.BTN_EAST in keys:
                pads[d.fd] = d
            else:
                d.close()
        except Exception:
            pass
    if not pads:
        return
    try:
        ui = UInput({e.EV_KEY: [e.KEY_TAB, e.KEY_LEFTSHIFT, e.KEY_UP, e.KEY_DOWN,
                                e.KEY_ENTER, e.KEY_ESC]}, name="Dialog Pad Keyboard")
    except Exception:
        return

    def tap(key, shift=False):
        if shift:
            ui.write(e.EV_KEY, e.KEY_LEFTSHIFT, 1)
        ui.write(e.EV_KEY, key, 1); ui.syn()
        ui.write(e.EV_KEY, key, 0)
        if shift:
            ui.write(e.EV_KEY, e.KEY_LEFTSHIFT, 0)
        ui.syn()

    hat = {e.ABS_HAT0X: 0, e.ABS_HAT0Y: 0}
    checked, active = 0.0, False
    while alive() and pads:
        r, _, _ = select.select(list(pads), [], [], 0.3)
        now = time.time()
        if now - checked > 0.25:
            try:
                active = xs.dialog_focused()
            except Exception:
                active = False
            checked = now
        for fd in r:
            try:
                events = list(pads[fd].read())
            except OSError:
                pads.pop(fd, None)
                continue
            if not active:
                continue
            for ev in events:
                if ev.type == e.EV_KEY and ev.value == 1:
                    if ev.code == e.BTN_SOUTH:
                        tap(e.KEY_ENTER)
                    elif ev.code == e.BTN_EAST:
                        tap(e.KEY_ESC)
                    elif ev.code == e.BTN_DPAD_LEFT:
                        tap(e.KEY_TAB, shift=True)
                    elif ev.code == e.BTN_DPAD_RIGHT:
                        tap(e.KEY_TAB)
                    elif ev.code == e.BTN_DPAD_UP:
                        tap(e.KEY_UP)
                    elif ev.code == e.BTN_DPAD_DOWN:
                        tap(e.KEY_DOWN)
                elif ev.type == e.EV_ABS and ev.code in hat:
                    old, hat[ev.code] = hat[ev.code], ev.value
                    if ev.value == 0 or ev.value == old:
                        continue
                    if ev.code == e.ABS_HAT0X:
                        tap(e.KEY_TAB, shift=ev.value < 0)
                    else:
                        tap(e.KEY_UP if ev.value < 0 else e.KEY_DOWN)
    try:
        ui.close()
    except Exception:
        pass


if __name__ == "__main__":
    main()
PY

# Hotkey + Start closes the game
cat > "$BASE/hotkey.py" <<'PY'
import os, sys, select, signal, time
pid = int(sys.argv[1])
try:
    from evdev import InputDevice, list_devices, ecodes as e
except Exception:
    sys.exit(0)

def alive():
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False

def stop():
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(pid, sig)
        except OSError:
            return
        for _ in range(30):
            if not alive():
                return
            time.sleep(0.1)

HOTKEYS = {e.BTN_SELECT, e.BTN_MODE}
devs = {}
for p in list_devices():
    try:
        d = InputDevice(p)
        keys = set(d.capabilities().get(e.EV_KEY, []))
        if e.BTN_START in keys and keys & HOTKEYS:
            devs[d.fd] = (d, set())
        else:
            d.close()
    except Exception:
        pass

while alive() and devs:
    r, _, _ = select.select(list(devs), [], [], 0.5)
    for fd in r:
        d, held = devs[fd]
        try:
            for ev in d.read():
                if ev.type != e.EV_KEY:
                    continue
                if ev.value == 1:
                    held.add(ev.code)
                elif ev.value == 0:
                    held.discard(ev.code)
                if e.BTN_START in held and held & HOTKEYS:
                    stop()
                    sys.exit(0)
        except OSError:
            devs.pop(fd, None)
PY

# Start Eglantine without a game (open from the F1 file manager to change settings)
cat > "$BASE/Eglantine.sh" <<'SH'
#!/bin/bash
BASE="/userdata/system/eglantine"
cd "$BASE" || exit 1
V="$(head -n1 "$BASE/variant.txt" 2>/dev/null)"
[[ "$V" == "normal" ]] || V="pgo"
exec "$BASE/bin/$V/AppRun" "$@"
SH
chmod +x "$BASE/launch.sh" "$BASE/Eglantine.sh"

# Entry under "Applications" in the F1 file manager
ICON=""
for f in "$BIN/$VARIANT"/*.png "$BIN/$VARIANT/.DirIcon"; do
    if [[ -f "$f" ]]; then ICON="$f"; break; fi
done
mkdir -p "$ASSETS" /userdata/system/.local/share/applications
[[ -n "$ICON" ]] && cp -fL "$ICON" "$ASSETS/eglantine.png"
cat > /userdata/system/.local/share/applications/eglantine.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Eglantine
Comment=Switch 2 emulator
Exec=/userdata/system/eglantine/Eglantine.sh
Path=/userdata/system/eglantine
Icon=/userdata/system/eglantine/assets/eglantine.png
Terminal=false
Categories=Game;batocera.linux;
DESKTOP
chmod +x /userdata/system/.local/share/applications/eglantine.desktop

# System "Switch 2" for EmulationStation
cat > "$ES_CFG" <<'XML'
<?xml version="1.0"?>
<systemList>
  <system>
    <name>switch2</name>
    <fullname>Switch 2</fullname>
    <path>/userdata/roms/switch2</path>
    <extension>.s2 .S2 .nsp .NSP .nsz .NSZ .nup .NUP .xci .XCI .xcz .XCZ .nca .NCA .nro .NRO .nso .NSO .kip .KIP</extension>
    <command>/userdata/system/eglantine/launch.sh "%ROM_RAW%"</command>
    <platform>ignore</platform>
    <theme>switch2</theme>
  </system>
</systemList>
XML

# Cover for this Ports entry
mkdir -p "$SELF_DIR/images"
extract_payload POSTER "$SELF_DIR/images/$SELF_STEM.jpg"

echo "Done."
echo
echo "======================================================================"
echo " Eglantine $TAG ($VARIANT_LABEL)"
echo
echo " Place your keys in:      $KEYS_DIR"
echo " Place your firmware in:  $FW_DIR"
echo " Place your games in:     $ROM_DIR"
echo "   Switch 2: game folder name.s2   Files: .nsp .nsz .nup .xci .xcz .nca .nro .nso .kip"
echo " Settings: F1 file manager -> Applications -> Eglantine"
echo "======================================================================"
echo

# Cover for this Ports entry: write it into the Ports gamelist
update_gamelist() {
python3 - "$SELF_DIR/gamelist.xml" "./$SELF_NAME" "./images/$SELF_STEM.jpg" "$SELF_STEM" <<'PY'
import os, sys
import xml.etree.ElementTree as ET
gl, path, image, name = sys.argv[1:5]
if os.path.exists(gl):
    tree = ET.parse(gl); root = tree.getroot()
else:
    root = ET.Element("gameList"); tree = ET.ElementTree(root)
game = None
for g in root.findall("game"):
    p = g.findtext("path") or ""
    if os.path.basename(p) == os.path.basename(path):
        game = g; break
if game is None:
    game = ET.SubElement(root, "game")
    ET.SubElement(game, "path").text = path
for tag, val in (("name", name), ("image", image), ("thumbnail", image)):
    el = game.find(tag)
    if el is None:
        el = ET.SubElement(game, tag)
    el.text = val
tree.write(gl, encoding="utf-8", xml_declaration=True)
print("gamelist updated")
PY
}

if (( FRESH == 0 )); then
    update_gamelist >> "$LOG" 2>&1
    echo "Update complete"
    echo
    wait_key
    exit 0
fi

echo "Installation complete"
echo
if ! ask_yes_no "Reboot now?"; then
    update_gamelist >> "$LOG" 2>&1
    echo
    echo "No reboot. The system \"Switch 2\" appears after the next reboot."
    echo
    wait_key
    exit 0
fi

# Reboot: stop EmulationStation first so it can't overwrite the Ports gamelist.
# Runs detached, because stopping EmulationStation also closes this window.
echo "Rebooting..."
declare -f update_gamelist > /tmp/eglantine-gamelist.sh
FINISH="/tmp/eglantine-finish.sh"
cat > "$FINISH" <<SH
#!/bin/bash
LOG="$LOG"
sleep 1
if [[ -x /etc/init.d/S31emulationstation ]]; then
    /etc/init.d/S31emulationstation stop >> "\$LOG" 2>&1
else
    killall -TERM emulationstation >> "\$LOG" 2>&1
fi
for i in \$(seq 1 30); do pgrep -x emulationstation >/dev/null || break; sleep 1; done
SELF_DIR="$SELF_DIR"; SELF_NAME="$SELF_NAME"; SELF_STEM="$SELF_STEM"
source /tmp/eglantine-gamelist.sh
update_gamelist >> "\$LOG" 2>&1
sync
reboot
SH
chmod +x "$FINISH"
setsid nohup /bin/bash "$FINISH" >/dev/null 2>&1 < /dev/null &
sleep 1
exit 0

__POSTER_BEGIN__
@@POSTER@@
__POSTER_END__
