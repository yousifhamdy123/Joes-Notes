"""Copies the Arabic fonts out of a (sparse) clone of github.com/google/fonts
into assets/fonts and registers them in pubspec.yaml.

Usage: python3 tool/setup_fonts.py <path-to-google-fonts-clone>
Run it BEFORE `flutter pub get`.
"""
import glob
import os
import shutil
import sys

src = sys.argv[1]
FAMILIES = [
    ("Cairo", "cairo"),
    ("Tajawal", "tajawal"),
    ("Amiri", "amiri"),
    ("Aref Ruqaa", "arefruqaa"),
    ("Reem Kufi", "reemkufi"),
]

os.makedirs("assets/fonts", exist_ok=True)
blocks = []

for family, folder in FAMILIES:
    files = glob.glob(os.path.join(src, "ofl", folder, "*.ttf"))
    files = [f for f in files if "Italic" not in os.path.basename(f)]
    static = [f for f in files if "[" not in os.path.basename(f)]
    variable = [f for f in files if "[" in os.path.basename(f)]

    def pick(suffix):
        for f in static:
            if os.path.basename(f).endswith("-" + suffix + ".ttf"):
                return f
        return None

    entries = []
    regular, bold = pick("Regular"), pick("Bold")
    if regular:
        dest = f"assets/fonts/{folder}-regular.ttf"
        shutil.copy(regular, dest)
        entries.append((dest, 400))
        if bold:
            dest = f"assets/fonts/{folder}-bold.ttf"
            shutil.copy(bold, dest)
            entries.append((dest, 700))
    elif variable:
        dest = f"assets/fonts/{folder}-var.ttf"
        shutil.copy(variable[0], dest)
        entries.append((dest, None))

    if not entries:
        print(f"WARNING: no font files found for {family}")
        continue

    lines = [f"    - family: {family}", "      fonts:"]
    for asset, weight in entries:
        lines.append(f"        - asset: {asset}")
        if weight:
            lines.append(f"          weight: {weight}")
    blocks.append("\n".join(lines))
    print("font ok:", family, [e[0] for e in entries])

if blocks:
    text = open("pubspec.yaml", encoding="utf-8").read().rstrip("\n")
    if "\n  fonts:" not in text:
        text += "\n\n  fonts:\n" + "\n".join(blocks) + "\n"
        open("pubspec.yaml", "w", encoding="utf-8").write(text)
