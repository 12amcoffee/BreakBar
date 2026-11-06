# Layout for the BreakBar installer DMG, used by dmgbuild (https://dmgbuild.readthedocs.io).
#   dmgbuild -s packaging/dmg-settings.py -D app=BreakBar.app [-D background=bg.png] BreakBar out.dmg
# `defines` is provided by dmgbuild. Everything is measured in points (not pixels).
import os
import subprocess

app = defines["app"]                      # path to the built BreakBar.app
background = defines.get("background")    # optional background image (PNG or multi-resolution TIFF)
app_name = os.path.basename(app)

# --- Window: as big as the background image, so the artwork fills it exactly. -----------------
WINDOW_W, WINDOW_H = 660, 400             # used when there is no background image
if background:
    def sips(key):
        out = subprocess.check_output(["sips", "-g", key, background]).decode().split()
        return int(out[-1])
    WINDOW_W, WINDOW_H = sips("pixelWidth"), sips("pixelHeight")
    if defines.get("retina"):             # a 2x background: pixels are twice the points
        WINDOW_W, WINDOW_H = WINDOW_W // 2, WINDOW_H // 2

# --- Icon positions: the app on the left, the Applications shortcut on the right. -------------
# These are the centres of the icons. Tune ICON_Y / the X fractions to line up with arrows or
# drop zones drawn in the background artwork.
ICON_SIZE = 128
ICON_Y = int(defines.get("icon_y", WINDOW_H * 0.5))
APP_X = int(defines.get("app_x", WINDOW_W * 0.27))
APPS_X = int(defines.get("apps_x", WINDOW_W * 0.73))

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
