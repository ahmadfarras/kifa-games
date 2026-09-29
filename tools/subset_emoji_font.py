"""Builds the small emoji font the game ships (Web exports have no system emoji font).

Scans src/ for emoji and keeps only those glyphs from Noto Color Emoji (SIL OFL 1.1).
Re-run whenever an emoji is added or removed in the UI.

Usage (needs `pip install fonttools`):
    python3 tools/subset_emoji_font.py path/to/NotoColorEmoji.ttf
Get the source font from https://github.com/googlefonts/noto-emoji (2D/fonts/NotoColorEmoji.ttf).
"""

import pathlib
import sys

from fontTools import subset

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "assets/shared/fonts/noto_color_emoji_subset.ttf"
SCANNED = ("*.gd", "*.tscn", "*.tres")
# Emoji live above U+2000; skip general punctuation (dashes, quotes) that the default font already has.
PUNCTUATION = range(0x2010, 0x2070)
# Always keep: variation selector-16 (emoji style) and zero-width joiner (combined emoji).
ALWAYS = {0xFE0F, 0x200D}


def used_codepoints() -> set[int]:
    codepoints = set(ALWAYS)
    for pattern in SCANNED:
        for path in (ROOT / "src").rglob(pattern):
            for char in path.read_text(encoding="utf-8"):
                code = ord(char)
                if code >= 0x2000 and code not in PUNCTUATION:
                    codepoints.add(code)
    return codepoints


def main() -> None:
    source = sys.argv[1]
    codepoints = used_codepoints()
    options = subset.Options()
    options.layout_features = ["*"]
    options.notdef_outline = True
    font = subset.load_font(source, options)
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=codepoints)
    subsetter.subset(font)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    subset.save_font(font, str(OUTPUT), options)
    print(f"{len(codepoints)} code points -> {OUTPUT.relative_to(ROOT)} ({OUTPUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
