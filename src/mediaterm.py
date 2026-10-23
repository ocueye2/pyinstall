#!/usr/bin/env python3
import curses
import subprocess
import time
import sys


COLORS = {
    "black": curses.COLOR_BLACK,
    "red": curses.COLOR_RED,
    "green": curses.COLOR_GREEN,
    "yellow": curses.COLOR_YELLOW,
    "blue": curses.COLOR_BLUE,
    "magenta": curses.COLOR_MAGENTA,
    "cyan": curses.COLOR_CYAN,
    "white": curses.COLOR_WHITE,
}


def help():
    print("args:")
    for option, description in (
        ("-h, -help, help, ?", "show this help page"),
        ("-k, -keybinds, k, keybinds", "show keybinds in the player"),
        ("-c, --color COLOR", "set UI color (black, red, green, yellow, blue, magenta, cyan, white)"),
    ):
        print(f"{option}: {description}")
    sys.exit()


user_help = False
ui_color = curses.COLOR_CYAN
args = iter(sys.argv[1:])
for item in args:
    match item:
        case "-h" | "--help" | "-help" | "help" | "?": help()
        case "-k" | "--keybinds" | "-keybinds" | "k" | "keybinds": user_help = True
        case "-c" | "--color":
            try:
                color_name = next(args).lower()
            except StopIteration:
                print(f"{item} requires a color name. Use --help for available colors.", file=sys.stderr)
                sys.exit(2)
            if color_name not in COLORS:
                print(f"Unknown color: {color_name}. Use --help for available colors.", file=sys.stderr)
                sys.exit(2)
            ui_color = COLORS[color_name]
        case _ if item.startswith("--color="):
            color_name = item.split("=", 1)[1].lower()
            if color_name not in COLORS:
                print(f"Unknown color: {color_name}. Use --help for available colors.", file=sys.stderr)
                sys.exit(2)
            ui_color = COLORS[color_name]



def playerctl(*args):
    try:
        r = subprocess.run(
            ["playerctl", *args],
            capture_output=True, text=True, timeout=1
        )
        return r.stdout.strip()
    except (subprocess.SubprocessError, OSError):
        return ""


def get_title():
    return playerctl("metadata", "--format", "{{title}}") or "Nothing playing"


def get_author():
    return playerctl("metadata", "--format", "{{artist}}") or "Unknown artist"


def get_progress():
    try:
        pos = float(playerctl("position") or 0)
        length = int(playerctl("metadata", "mpris:length") or 0) / 1_000_000
        return pos, length
    except ValueError:
        return 0, 0


def fmt(seconds):
    seconds = max(0, int(seconds))
    return f"{seconds // 60:02}:{seconds % 60:02}"


def run(stdscr):
    curses.curs_set(0)
    curses.start_color()
    curses.use_default_colors()
    curses.init_pair(1, ui_color, -1)
    curses.init_pair(2, ui_color, -1)
    curses.init_pair(3, ui_color, -1)
    stdscr.nodelay(True)

    paused = False

    while True:
        stdscr.erase()
        h, w = stdscr.getmaxyx()
        center = w // 2

        title = get_title()
        artist = get_author()
        pos, length = get_progress()
        progress = min(1.0, pos / length) if length > 0 else 0

        def draw(y, text, color=2, attr=0):
            if 0 <= y < h:
                x = max(0, (w - len(text)) // 2)
                stdscr.addnstr(y, x, text, max(0, w - x - 1),
                               curses.color_pair(color) | attr)

        draw(1, "NOW PLAYING", 1, curses.A_BOLD)
        draw(3, title[:max(1, w - 4)], 2, curses.A_BOLD)
        draw(4, artist[:max(1, w - 4)], 1)

        # Playback bar
        bar_width = max(10, min(60, w - 12))
        filled = int(progress * bar_width)
        bar = "=" * filled + "-" * (bar_width - filled)
        draw(6, bar, 1)
        draw(7, f"{fmt(pos)} / {fmt(length)}", 3)
        if user_help:
            draw(9, "!Help Mode Enabled!", 2)
            draw(10, "[←]/[→] Move through Playlist  [Space] Play/Pause", 2)
        stdscr.refresh()

        key = stdscr.getch()
        if key in (ord("q"), ord("Q"), 27):
            break
        elif key == ord(" "):
            playerctl("play-pause")
        elif key in (ord("n"), ord("N"), curses.KEY_RIGHT):
            playerctl("next")
        elif key in (ord("b"), ord("B"), curses.KEY_LEFT):
            playerctl("previous")

        time.sleep(0.2)


if __name__ == "__main__":
    try:
        curses.wrapper(run)
    except KeyboardInterrupt:
        pass
