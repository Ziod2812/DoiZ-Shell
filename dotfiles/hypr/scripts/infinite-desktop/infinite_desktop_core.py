import sys, struct, threading, time, subprocess, json, os
import fcntl
import select
import math
from evdev import InputDevice, list_devices, ecodes

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hypr_ipc import move_window_exact_lua, resize_window_exact_lua, batch_async

speed = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0

DEBUG = os.environ.get('DOIZ_DEBUG') == '1'
def _log(*args, **kwargs):
    if DEBUG:
        print(*args, **kwargs)

DEVICE_RESCAN_INTERVAL = 3.0

EVENT_SIZE = struct.calcsize('llHHi')
EV_KEY=1; EV_REL=2; REL_X=0; REL_Y=1
KEY_LEFTMETA=125; KEY_RIGHTMETA=126
KEY_LEFTALT=56; KEY_RIGHTALT=100
KEY_LEFTCTRL=29; KEY_RIGHTCTRL=97
KEY_LEFTSHIFT=42; KEY_RIGHTSHIFT=54
KEY_LEFT=105; KEY_RIGHT=106
KEY_UP=103; KEY_DOWN=108
KEY_A=30
BTN_LEFT=272
REL_WHEEL=8; REL_WHEEL_HI_RES=11

ZOOM_STEP = 1.12
ZOOM_MIN = 0.3
ZOOM_MAX = 3.0
ZOOM_MIN_WIDTH = 120
ZOOM_MIN_HEIGHT = 80
ZOOM_SYNC_TOLERANCE = 2

STATE_FILE = "/tmp/infinite-desktop-state"
PROTECTED_APPS = ['helium', 'helium-browser', 'brave-browser', 'chromium', 'chromium-browser', 'google-chrome',
                  'firefox', 'firefoxdeveloperedition', 'librewolf', 'vivaldi',
                  'opera', 'microsoft-edge']

lock = threading.Lock()
super_pressed=False; alt_pressed=False; ctrl_pressed=False; shift_pressed=False; btn_left=False
acc_x=0.0; acc_y=0.0
zoom_steps=0.0
zoom_reset_pending=False
zoom_levels={}
zoom_state={}
frame_held_hidden=False

window_drag_active = False
last_window_pos = None
last_window_bounds = None
mouse_rel_x = 0
mouse_rel_y = 0

KEY_MOVE_STEP = 20

def read_inverted():
    try:
        with open(STATE_FILE) as f:
            return f.read().strip() == 'inverse'
    except:
        return False

def notify_quickshell_hold(state):
    try:
        subprocess.run(
            ['qs', 'ipc', 'call', 'frame', 'setHeldHidden', 'true' if state else 'false'],
            capture_output=True, timeout=1.0
        )
    except Exception:
        pass

def get_monitor_bounds():
    try:
        r = subprocess.run(['hyprctl', 'monitors', '-j'], capture_output=True, text=True, timeout=0.1)
        monitors = json.loads(r.stdout)
        if monitors:
            for m in monitors:
                if m.get('focused', False):
                    return {
                        'left': m['x'],
                        'right': m['x'] + m['width'],
                        'top': m['y'],
                        'bottom': m['y'] + m['height'],
                        'width': m['width'],
                        'height': m['height']
                    }
            m = monitors[0]
            return {
                'left': m['x'],
                'right': m['x'] + m['width'],
                'top': m['y'],
                'bottom': m['y'] + m['height'],
                'width': m['width'],
                'height': m['height']
            }
    except:
        pass
    return {'left': 0, 'right': 1920, 'top': 0, 'bottom': 1080, 'width': 1920, 'height': 1080}

def get_floating_windows(workspace_id):
    try:
        r = subprocess.run(['hyprctl', 'clients', '-j'], capture_output=True, text=True, timeout=0.1)
        clients = json.loads(r.stdout)
        floating = []
        for w in clients:
            if w.get('floating') and w.get('workspace', {}).get('id') == workspace_id:
                floating.append(w)
        return floating
    except:
        return []

def get_focused_window():
    try:
        r = subprocess.run(['hyprctl', 'activewindow', '-j'], capture_output=True, text=True, timeout=0.1)
        return json.loads(r.stdout)
    except:
        return None

def is_protected_app(window):
    if not window:
        return False
    window_class = window.get('class', '').lower()
    return any(app in window_class for app in PROTECTED_APPS)

def get_window_center(window):
    return (window['at'][0] + window['size'][0] // 2,
            window['at'][1] + window['size'][1] // 2)

def get_window_bounds(window):
    x, y = window['at'][0], window['at'][1]
    w, h = window['size'][0], window['size'][1]
    return {
        'left': x,
        'right': x + w,
        'top': y,
        'bottom': y + h,
        'center_x': x + w // 2,
        'center_y': y + h // 2
    }

def windows_overlap_horizontally(bounds1, bounds2):
    return not (bounds1['right'] <= bounds2['left'] or bounds1['left'] >= bounds2['right'])

def windows_overlap_vertically(bounds1, bounds2):
    return not (bounds1['bottom'] <= bounds2['top'] or bounds1['top'] >= bounds2['bottom'])

def pan_other_windows(excluded_addr, dx, dy, workspace_id):
    if dx == 0 and dy == 0:
        return
    try:
        floating_windows = get_floating_windows(workspace_id)
        exprs = []
        for w in floating_windows:
            if w['address'] != excluded_addr:
                nx = int(w['at'][0] + dx)
                ny = int(w['at'][1] + dy)
                exprs.append(move_window_exact_lua(nx, ny, w['address']))
        batch_async(exprs)
    except:
        pass

def get_monitor_center():
    try:
        r = subprocess.run(['hyprctl', 'monitors', '-j'], capture_output=True, text=True, timeout=0.1)
        monitors = json.loads(r.stdout)
        for m in monitors:
            if m.get('focused', False):
                return m['x'] + m['width'] // 2, m['y'] + m['height'] // 2
    except:
        pass
    return 960, 540

def monitor_window_drag():
    global window_drag_active, last_window_bounds, mouse_rel_x, mouse_rel_y

    dragged_window_addr = None

    while True:
        try:
            with lock:
                is_dragging = super_pressed and btn_left and not alt_pressed and not ctrl_pressed
                mouse_dx = mouse_rel_x
                mouse_dy = mouse_rel_y
                mouse_rel_x = 0
                mouse_rel_y = 0

            if is_dragging and not window_drag_active:
                focused = get_focused_window()
                if focused and focused.get('address'):
                    dragged_window_addr = focused['address']
                    window_drag_active = True
                    last_window_bounds = get_window_bounds(focused)

            elif not is_dragging and window_drag_active:
                window_drag_active = False
                dragged_window_addr = None
                last_window_bounds = None

            if window_drag_active and dragged_window_addr:
                window = get_focused_window()
                if window and window.get('address') == dragged_window_addr:
                    current_bounds = get_window_bounds(window)
                    monitor = get_monitor_bounds()
                    MARGIN = 10

                    touch_left   = current_bounds['left']   <= monitor['left']   + MARGIN
                    touch_right  = current_bounds['right']  >= monitor['right']  - MARGIN
                    touch_top    = current_bounds['top']    <= monitor['top']    + MARGIN
                    touch_bottom = current_bounds['bottom'] >= monitor['bottom'] - MARGIN

                    if (touch_left or touch_right or touch_top or touch_bottom) and (mouse_dx != 0 or mouse_dy != 0):
                        pan_dx = 0
                        pan_dy = 0

                        if touch_right and mouse_dx > 0:
                            pan_dx = -mouse_dx
                        elif touch_left and mouse_dx < 0:
                            pan_dx = -mouse_dx

                        if touch_bottom and mouse_dy > 0:
                            pan_dy = -mouse_dy
                        elif touch_top and mouse_dy < 0:
                            pan_dy = -mouse_dy

                        if pan_dx != 0 or pan_dy != 0:
                            r = subprocess.run(['hyprctl', 'activeworkspace', '-j'],
                                             capture_output=True, text=True, timeout=0.1)
                            ws = json.loads(r.stdout)
                            workspace_id = ws['id']
                            pan_other_windows(dragged_window_addr, int(pan_dx), int(pan_dy), workspace_id)

                    last_window_bounds = current_bounds
                else:
                    window_drag_active = False
                    dragged_window_addr = None

            time.sleep(0.016)
        except Exception as e:
            time.sleep(0.1)

def move_active_window(direction):
    try:
        r = subprocess.run(['hyprctl', 'activeworkspace', '-j'], capture_output=True, text=True, timeout=0.1)
        ws = json.loads(r.stdout)
        workspace_id = ws['id']

        window = get_focused_window()
        if not window or not window.get('floating'):
            return

        monitor = get_monitor_bounds()
        bounds = get_window_bounds(window)
        addr = window['address']

        dx, dy = 0, 0
        if direction == 'left':
            dx = -KEY_MOVE_STEP
        elif direction == 'right':
            dx = KEY_MOVE_STEP
        elif direction == 'up':
            dy = -KEY_MOVE_STEP
        elif direction == 'down':
            dy = KEY_MOVE_STEP

        new_x = window['at'][0] + dx
        new_y = window['at'][1] + dy

        new_bounds_left   = new_x
        new_bounds_right  = new_x + window['size'][0]
        new_bounds_top    = new_y
        new_bounds_bottom = new_y + window['size'][1]

        hits_left   = new_bounds_left   <= monitor['left']
        hits_right  = new_bounds_right  >= monitor['right']
        hits_top    = new_bounds_top    <= monitor['top']
        hits_bottom = new_bounds_bottom >= monitor['bottom']

        hitting_edge = (dx < 0 and hits_left) or (dx > 0 and hits_right) or                        (dy < 0 and hits_top)  or (dy > 0 and hits_bottom)

        subprocess.run(['hyprctl', 'dispatch', move_window_exact_lua(new_x, new_y, addr)],
                       capture_output=True, timeout=0.2)

        if hitting_edge:
            pan_other_windows(addr, -dx, -dy, workspace_id)

    except Exception as e:
        _log(f"Error in move_active_window: {e}", flush=True)

def classify_device(path):
    try:
        dev = InputDevice(path)
        caps = dev.capabilities()
        dev.close()
    except Exception:
        return None

    keys = set(caps.get(ecodes.EV_KEY, []))
    rels = set(caps.get(ecodes.EV_REL, []))

    is_mouse = (ecodes.REL_X in rels and ecodes.REL_Y in rels and ecodes.BTN_LEFT in keys)
    if is_mouse:
        return 'mouse'

    is_keyboard = (
        ecodes.KEY_A in keys and ecodes.KEY_Z in keys and ecodes.KEY_LEFTSHIFT in keys
        and (ecodes.KEY_LEFTMETA in keys or ecodes.KEY_RIGHTMETA in keys)
    )
    if is_keyboard:
        return 'keyboard'

    return None

def scan_devices():
    keyboards, mice = [], []
    for path in list_devices():
        kind = classify_device(path)
        if kind == 'mouse':
            mice.append(path)
        elif kind == 'keyboard':
            keyboards.append(path)
    return keyboards, mice

def kbd_reader_device(path):
    global super_pressed, alt_pressed, ctrl_pressed, shift_pressed, frame_held_hidden, zoom_reset_pending
    try:
        fd = open(path, 'rb')
    except Exception:
        return

    while True:
        try:
            data = fd.read(EVENT_SIZE)
        except Exception:
            break
        if not data or len(data) < EVENT_SIZE:
            break
        _, _, etype, code, value = struct.unpack('llHHi', data)
        if etype != EV_KEY:
            continue
        if value == 2:
            continue

        notify_state = None
        with lock:
            if code in (KEY_LEFTMETA, KEY_RIGHTMETA):
                super_pressed = (value == 1)
            elif code in (KEY_LEFTALT, KEY_RIGHTALT):
                alt_pressed = (value == 1)
            elif code in (KEY_LEFTCTRL, KEY_RIGHTCTRL):
                ctrl_pressed = (value == 1)
            elif code in (KEY_LEFTSHIFT, KEY_RIGHTSHIFT):
                shift_pressed = (value == 1)
            elif code == KEY_A and value == 1:
                if super_pressed and alt_pressed and not ctrl_pressed and not shift_pressed:
                    zoom_reset_pending = True

            combo = super_pressed and alt_pressed
            if combo != frame_held_hidden:
                frame_held_hidden = combo
                notify_state = combo

        if notify_state is not None:
            threading.Thread(target=notify_quickshell_hold, args=(notify_state,), daemon=True).start()

    try:
        fd.close()
    except Exception:
        pass

def mouse_reader_device(path):
    global acc_x, acc_y, btn_left, mouse_rel_x, mouse_rel_y, zoom_steps
    seen_hires = False
    try:
        fd = open(path, 'rb')
    except Exception:
        return

    while True:
        try:
            data = fd.read(EVENT_SIZE)
        except Exception:
            break
        if not data or len(data) < EVENT_SIZE:
            break
        _, _, etype, code, value = struct.unpack('llHHi', data)

        with lock:
            if etype == EV_KEY and code == BTN_LEFT:
                btn_left = (value == 1)
            elif etype == EV_REL and code in (REL_WHEEL, REL_WHEEL_HI_RES):
                if code == REL_WHEEL_HI_RES:
                    seen_hires = True
                    step = value / 120.0
                elif not seen_hires:
                    step = float(value)
                else:
                    step = 0.0

                if super_pressed and alt_pressed and not ctrl_pressed and not shift_pressed:
                    zoom_steps += step
            elif etype == EV_REL:
                if code == REL_X:
                    mouse_rel_x += value
                elif code == REL_Y:
                    mouse_rel_y += value

                if super_pressed and shift_pressed and btn_left and not ctrl_pressed:
                    sign = -1 if read_inverted() else 1
                    if code == REL_X:
                        acc_x += value * speed * sign
                    elif code == REL_Y:
                        acc_y += value * speed * sign
                else:
                    acc_x = 0.0
                    acc_y = 0.0

    try:
        fd.close()
    except Exception:
        pass

_active_kbd_threads = {}
_active_mouse_threads = {}

def device_manager():
    WARMUP_DURATION = 20.0
    WARMUP_INTERVAL = 0.5
    start_time = time.time()

    while True:
        try:
            keyboards, mice = scan_devices()

            for path in keyboards:
                t = _active_kbd_threads.get(path)
                if t is None or not t.is_alive():
                    nt = threading.Thread(target=kbd_reader_device, args=(path,), daemon=True)
                    nt.start()
                    _active_kbd_threads[path] = nt
                    _log(f"[+] Keyboard detected: {path}", flush=True)

            for path in mice:
                t = _active_mouse_threads.get(path)
                if t is None or not t.is_alive():
                    nt = threading.Thread(target=mouse_reader_device, args=(path,), daemon=True)
                    nt.start()
                    _active_mouse_threads[path] = nt
                    _log(f"[+] Mouse detected: {path}", flush=True)
        except Exception as e:
            _log(f"Error in device_manager: {e}", flush=True)

        elapsed = time.time() - start_time
        interval = WARMUP_INTERVAL if elapsed < WARMUP_DURATION else DEVICE_RESCAN_INTERVAL
        time.sleep(interval)

_log("Preloading...", flush=True)
try:
    subprocess.run(['hyprctl', 'activeworkspace', '-j'], capture_output=True, text=True, timeout=0.5)
    subprocess.run(['hyprctl', 'clients', '-j'], capture_output=True, text=True, timeout=0.5)
except:
    pass

threading.Thread(target=device_manager, daemon=True).start()
_log("Infinite Desktop active (automatic device detection)", flush=True)
_log("Super+Shift+hold left mouse button: pan the whole desktop", flush=True)
_log("Super+Alt+scroll: zoom the whole desktop in and out around the cursor", flush=True)
_log("Super+Alt+A: reset the desktop zoom to the default size", flush=True)
_log("Super+hold left mouse button: drag a window via Hyprland bind", flush=True)
_log("Super+arrows: navigation via Hyprland bind", flush=True)
_log("Super+Shift+arrows: move the active window via Hyprland bind", flush=True)

_cached_workspace_id = None
_last_workspace_check = 0
WORKSPACE_CACHE_TTL = 2.0

def get_cached_workspace_id():
    global _cached_workspace_id, _last_workspace_check
    now = time.time()
    if _cached_workspace_id is None or (now - _last_workspace_check) > WORKSPACE_CACHE_TTL:
        try:
            r = subprocess.run(['hyprctl', 'activeworkspace', '-j'],
                               capture_output=True, text=True, timeout=0.1)
            ws = json.loads(r.stdout)
            _cached_workspace_id = ws['id']
            _last_workspace_check = now
        except:
            pass
    return _cached_workspace_id

def get_cursor_position():
    try:
        r = subprocess.run(['hyprctl', 'cursorpos', '-j'], capture_output=True, text=True, timeout=0.1)
        pos = json.loads(r.stdout)
        return float(pos['x']), float(pos['y'])
    except Exception:
        cx, cy = get_monitor_center()
        return float(cx), float(cy)

def apply_zoom(steps=0.0, target_level=None):
    global zoom_state

    workspace_id = get_cached_workspace_id()
    if workspace_id is None:
        return

    level = zoom_levels.get(workspace_id, 1.0)

    if target_level is None:
        target = max(ZOOM_MIN, min(ZOOM_MAX, level * ZOOM_STEP ** steps))
    else:
        target = target_level

    factor = target / level

    if abs(factor - 1.0) < 1e-4:
        return

    r = subprocess.run(['hyprctl', 'clients', '-j'], capture_output=True, text=True, timeout=0.2)
    clients = json.loads(r.stdout)
    px, py = get_cursor_position()

    resizes = []
    moves = []
    new_state = {}

    for w in clients:
        if not w.get('floating') or w.get('workspace', {}).get('id') != workspace_id:
            continue
        if w.get('fullscreen'):
            continue

        addr = w['address']
        ax, ay = w['at'][0], w['at'][1]
        aw, ah = w['size'][0], w['size'][1]
        prev = zoom_state.get(addr)

        if prev and all(abs(a - b) <= ZOOM_SYNC_TOLERANCE for a, b in zip((ax, ay, aw, ah), prev['applied'])):
            x, y, ww, hh = prev['virtual']
        else:
            x, y, ww, hh = float(ax), float(ay), float(aw), float(ah)

        nx = px + (x - px) * factor
        ny = py + (y - py) * factor
        nw = ww * factor
        nh = hh * factor

        applied = (int(round(nx)), int(round(ny)),
                   int(round(max(ZOOM_MIN_WIDTH, nw))), int(round(max(ZOOM_MIN_HEIGHT, nh))))
        new_state[addr] = {'virtual': (nx, ny, nw, nh), 'applied': applied}

        resizes.append(resize_window_exact_lua(applied[2], applied[3], addr))
        moves.append(move_window_exact_lua(applied[0], applied[1], addr))

    zoom_state.update(new_state)
    zoom_levels[workspace_id] = target
    batch_async(resizes + moves)

def reset_zoom():
    apply_zoom(target_level=1.0)

while True:
    time.sleep(0.016)

    with lock:
        active_drag = super_pressed and shift_pressed and btn_left and not ctrl_pressed
        dx = acc_x
        dy = acc_y
        acc_x = 0.0
        acc_y = 0.0
        pending_zoom = zoom_steps
        zoom_steps = 0.0
        pending_reset = zoom_reset_pending
        zoom_reset_pending = False

    if pending_reset:
        try:
            reset_zoom()
        except Exception:
            pass
    elif pending_zoom != 0.0:
        try:
            apply_zoom(pending_zoom)
        except Exception:
            pass

    if not active_drag:
        continue

    idx = int(round(dx))
    idy = int(round(dy))

    if idx == 0 and idy == 0:
        continue

    try:
        workspace_id = get_cached_workspace_id()
        if workspace_id is None:
            continue

        r = subprocess.run(['hyprctl', 'clients', '-j'], capture_output=True, text=True, timeout=0.1)
        clients = json.loads(r.stdout)

        exprs = []
        for w in clients:
            if w.get('floating') and w.get('workspace', {}).get('id') == workspace_id:
                nx = w['at'][0] + idx
                ny = w['at'][1] + idy
                exprs.append(move_window_exact_lua(nx, ny, w['address']))

        batch_async(exprs)
    except Exception as e:
        pass
