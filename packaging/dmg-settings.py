# Layout for the BreakBar installer DMG, used by dmgbuild (https://dmgbuild.readthedocs.io).
#   dmgbuild -s packaging/dmg-settings.py -D app=BreakBar.app [-D background=bg.png] BreakBar out.dmg
# `defines` is provided by dmgbuild. Everything is measured in points (not pixels).
import os
import subprocess

app = defines["app"]                      # path to the built BreakBar.app
background = defines.get("background")    # optional background image (PNG or multi-resolution TIFF)
app_name = os.path.basename(app)

# --- Window: as big as the background image, so the artwork fills it exactly. -----------------
# Design/dmg-background.png is 660x400 points; dmg-background@2x.png is the same art at 1320x800.
WINDOW_W, WINDOW_H = 660, 400             # used when there is no background image
size_from = defines.get("size_from", background)   # the 1x image, even when `background` is a 2-in-1 TIFF
if size_from:
    def sips(key):
        out = subprocess.check_output(["sips", "-g", key, size_from]).decode().split()
        return int(out[-1])
    WINDOW_W, WINDOW_H = sips("pixelWidth"), sips("pixelHeight")

# --- Icon positions (centres, in points) -------------------------------------------------------
# The background draws an arrow at y=200 from x~219 to x~441, so the app sits to its left and the
# Applications shortcut to its right, both on the arrow's centre line.
ICON_SIZE = 128
ICON_Y = int(defines.get("icon_y", WINDOW_H * 0.5))        # 200 for a 400pt window
APP_X = int(defines.get("app_x", WINDOW_W * 0.182))        # 120 for a 660pt window
APPS_X = int(defines.get("apps_x", WINDOW_W * 0.818))      # 540 for a 660pt window

# --- dmgbuild settings ------------------------------------------------------------------------
format = "UDZO"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
icon_locations = {app_name: (APP_X, ICON_Y), "Applications": (APPS_X, ICON_Y)}

# `background` (set near the top) is either a path or None; dmgbuild reads it as is.

window_rect = ((200, 140), (WINDOW_W, WINDOW_H))
default_view = "icon-view"
icon_size = ICON_SIZE
text_size = 13
arrange_by = None
show_icon_preview = False
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
