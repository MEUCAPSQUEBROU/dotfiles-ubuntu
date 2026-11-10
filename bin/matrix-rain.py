#!/usr/bin/env python3
"""Matrix-style digital rain rendered as Pango markup.

Runs in the background and rewrites $XDG_RUNTIME_DIR/matrix-rain/frame
about 25 times per second; the desktop widget just reads that file.
Exits on its own when the "Matrix" desktop widget is removed or disabled."""
import fcntl, os, random, signal, subprocess, sys, time

COLS = int(sys.argv[1]) if len(sys.argv) > 1 else 36
ROWS = int(sys.argv[2]) if len(sys.argv) > 2 else 12
FPS = 25
WIDGET_ID = '10d1d7c9-ccd3-4e19-907c-74f3b632956c'

# Half-width katakana plus digits, like the film
GLYPHS = [chr(c) for c in range(0xFF66, 0xFF9E)] + list('0123456789') + list('ZTE:."=*+-<>')

HEAD = '#EFFFEF'
SHADES = [(1, '#A8FFA8'), (3, '#4CFF4C'), (6, '#22CC22'), (10, '#178C17'), (99, '#0D530D')]

DIR = os.path.join(os.environ.get('XDG_RUNTIME_DIR', '/tmp'), 'matrix-rain')
FRAME = os.path.join(DIR, 'frame')
os.makedirs(DIR, exist_ok=True)

lock = open(os.path.join(DIR, 'lock'), 'w')
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except OSError:
    sys.exit(0)  # already running


def cleanup(*_):
    try:
        os.remove(FRAME)
    except OSError:
        pass
    sys.exit(0)


signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGHUP, cleanup)


def widget_enabled():
    try:
        out = subprocess.run(['dconf', 'read', '/org/gnome/shell/extensions/azclock/widgets'],
                             capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return True
    i = out.find(WIDGET_ID)
    return i >= 0 and 'true' in out[i:i + 60]


def new_drop(start=False):
    # speed in rows per frame; fractional so columns fall at different rates
    return {'y': random.uniform(-ROWS * 1.5, ROWS if start else 0),
            'len': random.randint(5, ROWS + 4),
            'speed': random.uniform(0.06, 0.16)}


drops = [new_drop(start=True) for _ in range(COLS)]
chars = [[random.choice(GLYPHS) for _ in range(COLS)] for _ in range(ROWS)]
ESC = {'&': '&amp;', '<': '&lt;', '>': '&gt;'}


def color_for(dist, length):
    if dist == 0:
        return HEAD
    if dist >= length:
        return None
    for limit, c in SHADES:
        if dist <= limit:
            return c
    return SHADES[-1][1]


def render():
    lines = []
    for y in range(ROWS):
        parts, cur, buf = [], None, ''
        for x in range(COLS):
            d = drops[x]
            dist = int(d['y']) - y
            c = color_for(dist, d['len']) if dist >= 0 else None
            ch = (chars[y][x] if dist else random.choice(GLYPHS)) if c else ' '
            if c != cur:
                if buf:
                    parts.append(f'<span foreground="{cur}">{buf}</span>' if cur else buf)
                cur, buf = c, ''
            buf += ESC.get(ch, ch)
        if buf:
            parts.append(f'<span foreground="{cur}">{buf}</span>' if cur else buf)
        lines.append(''.join(parts))
    # Wrapping span keeps leading spaces from being trimmed by the widget
    return '<span>' + '\n'.join(lines) + '</span>\n'


tmp = FRAME + '.tmp'
frame, last_check = 0, time.monotonic()
while True:
    t0 = time.monotonic()
    for d in drops:
        d['y'] += d['speed']
        if d['y'] - d['len'] > ROWS:
            d.update(new_drop())
    for _ in range(COLS * ROWS // 100):
        chars[random.randrange(ROWS)][random.randrange(COLS)] = random.choice(GLYPHS)

    with open(tmp, 'w') as f:
        f.write(render())
    os.replace(tmp, FRAME)

    if t0 - last_check > 10:
        last_check = t0
        if not widget_enabled():
            cleanup()

    time.sleep(max(0.0, 1 / FPS - (time.monotonic() - t0)))
