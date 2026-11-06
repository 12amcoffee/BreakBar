#!/usr/bin/env python3
"""Fails if a language is missing a key, or if the code uses a key no file defines.
Usage: python3 scripts/check-strings.py   (from the repo root)"""
import re, sys, pathlib

root = pathlib.Path(__file__).resolve().parent.parent / "App"
pair = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$')
langs = {}
for d in sorted(root.glob("*.lproj")):
    keys = {}
    for line in (d / "Localizable.strings").read_text(encoding="utf-8").splitlines():
        m = pair.match(line)
        if m: keys[m.group(1)] = m.group(2)
    langs[d.name.removesuffix(".lproj")] = keys

bad = False
base = set(langs["en"])
for name, keys in langs.items():
    for k in sorted(base - set(keys)): print(f"{name}: missing {k!r}"); bad = True
    for k in sorted(set(keys) - base): print(f"{name}: extra   {k!r}"); bad = True
    for k, v in keys.items():                       # same number of %lld placeholders as English
        if v.count("%lld") != k.count("%lld"): print(f"{name}: placeholder mismatch in {k!r}"); bad = True

# Literal keys used in views: Text("..."), Button("..."), Toggle("..."), Section("..."), etc.
used = set()
call = re.compile(r'\b(?:Text|Button|Toggle|Picker|Section|Label|Stepper|String\(localized:)\(?\s*"((?:[^"\\]|\\.)*)"')
for f in root.glob("*.swift"):
    for k in call.findall(f.read_text(encoding="utf-8")):
        k = re.sub(r'\\\(.*?\)', '%lld', k)           # \(value) -> %lld
        used.add(k)
for k in sorted(used - base - {'%lld'}):          # a bare number needs no translation
    print(f"code uses {k!r} but no strings file defines it"); bad = True

print("strings OK" if not bad else "strings have problems")
sys.exit(1 if bad else 0)
