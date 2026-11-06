BreakBar assets
===============
Tomato #E5432B  Cream #FFF4E6  Ink #1F1A17  Rest pink #FFC9BB

HOW TO USE IN XCODE
1. Open Assets.xcassets.
2. Delete the default AppIcon, then drag AppIcon.appiconset into the asset catalog.
   (Target > General > App Icons Source should be "AppIcon".)
   - If you use Xcode 26 / Icon Composer, use icon-1024-fullbleed.png instead:
     it is a plain square with no rounding or shadow, because the system applies the mask.
3. Drag MenuBarIcon.imageset in as well. It is a vector PDF set as a Template Image,
   so macOS tints it for light/dark menu bars automatically.
   SwiftUI:  Image("MenuBarIcon")   (e.g. in MenuBarExtra)
   AppKit:   NSImage(named: "MenuBarIcon") with isTemplate = true

FILES
 AppIcon.appiconset/     macOS icon set, 16-512pt @1x/@2x (rounded, padded, shadowed)
 MenuBarIcon.imageset/   template glyph (PDF)
 icon-1024-macos.png     1024 master, macOS style
 icon-1024-fullbleed.png 1024 master, square, no mask
 menubar-glyph@1x/@2x.png  PNG fallbacks for the glyph
 source/                 editable SVGs
