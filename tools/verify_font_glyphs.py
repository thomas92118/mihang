"""Verify that all characters used in runtime GDScript and scene string literals
are covered by the bundled font subsets.

Usage:
    python tools/verify_font_glyphs.py
"""
from __future__ import annotations

import sys
from collections import defaultdict
from pathlib import Path
from typing import Iterator

from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]

FONT_PATHS = [
    ROOT / "assets" / "fonts" / "NotoSansSC-Subset.otf",
    ROOT / "assets" / "fonts" / "Controls-CJK-Subset.otf",
    ROOT / "assets" / "fonts" / "Symbols-Subset.ttf",
]

IGNORED_CONTROL_CHARS = {"\n", "\r", "\t"}

SIMPLE_ESCAPES = {
    "n": "\n",
    "r": "\r",
    "t": "\t",
    "\\": "\\",
    '"': '"',
    "'": "'",
    "a": "\a",
    "b": "\b",
    "f": "\f",
    "v": "\v",
    "0": "\0",
}


def _is_hex(text: str) -> bool:
    return bool(text) and all(ch in "0123456789abcdefABCDEF" for ch in text)


def iter_string_literal_chars(source: str, is_tscn: bool = False) -> Iterator[tuple[int, str]]:
    """Yield (line_number, char) for every character inside string literals."""
    n = len(source)
    i = 0
    line = 1
    at_line_start = True

    while i < n:
        ch = source[i]

        if ch == "\n":
            line += 1
            at_line_start = True
            i += 1
            continue

        # Skip comments outside string literals
        if ch == "#" or (is_tscn and at_line_start and ch == ";"):
            while i < n and source[i] != "\n":
                i += 1
            continue

        # Detect raw string prefix r"..." / r'...' (not preceded by identifier char)
        is_raw = False
        if ch == "r" and i + 1 < n and source[i + 1] in ('"', "'"):
            prev_ch = source[i - 1] if i > 0 else ""
            if not (prev_ch.isalnum() or prev_ch == "_"):
                is_raw = True
                i += 1
                ch = source[i]

        if ch in ('"', "'"):
            if ch not in (" ", "\t", "\r"):
                at_line_start = False
            quote = ch
            if source[i : i + 3] == quote * 3:
                delim = quote * 3
                i += 3
            else:
                delim = quote
                i += 1

            delim_len = len(delim)
            while i < n:
                if source[i : i + delim_len] == delim:
                    i += delim_len
                    break
                c = source[i]
                if c == "\n":
                    yield (line, c)
                    line += 1
                    i += 1
                    continue
                if c == "\\" and i + 1 < n:
                    nxt = source[i + 1]
                    if is_raw:
                        if nxt in (quote, "\\"):
                            yield (line, nxt)
                            i += 2
                        else:
                            yield (line, c)
                            i += 1
                        continue
                    if nxt == "\n":
                        line += 1
                        i += 2
                        continue
                    if nxt in SIMPLE_ESCAPES:
                        yield (line, SIMPLE_ESCAPES[nxt])
                        i += 2
                        continue
                    if nxt == "u" and _is_hex(source[i + 2 : i + 6]) and len(source[i + 2 : i + 6]) == 4:
                        yield (line, chr(int(source[i + 2 : i + 6], 16)))
                        i += 6
                        continue
                    if nxt == "U":
                        # GDScript uses 6 hex digits (\UXXXXXX); C/TSCN may use 6 or 8.
                        hex8 = source[i + 2 : i + 10]
                        hex6 = source[i + 2 : i + 8]
                        if len(hex8) == 8 and _is_hex(hex8) and int(hex8, 16) <= 0x10FFFF:
                            yield (line, chr(int(hex8, 16)))
                            i += 10
                            continue
                        if len(hex6) == 6 and _is_hex(hex6) and int(hex6, 16) <= 0x10FFFF:
                            yield (line, chr(int(hex6, 16)))
                            i += 8
                            continue
                    yield (line, nxt)
                    i += 2
                    continue

                yield (line, c)
                i += 1
            continue

        if ch not in (" ", "\t", "\r"):
            at_line_start = False
        i += 1


def load_covered_codepoints() -> tuple[set[int], dict[str, int]]:
    covered: set[int] = set()
    per_font_counts: dict[str, int] = {}
    for font_path in FONT_PATHS:
        if not font_path.exists():
            raise FileNotFoundError(f"Font file not found: {font_path}")
        font = TTFont(str(font_path))
        cmap = font.getBestCmap() or {}
        keys = set(cmap.keys())
        per_font_counts[font_path.name] = len(keys)
        covered |= keys
    return covered, per_font_counts


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    covered, per_font_counts = load_covered_codepoints()

    scan_files = sorted((ROOT / "scripts").rglob("*.gd")) + sorted((ROOT / "scenes").rglob("*.tscn"))
    seen_chars: set[int] = set()
    missing_locations: dict[int, list[str]] = defaultdict(list)

    for file_path in scan_files:
        rel_path = file_path.relative_to(ROOT).as_posix()
        content = file_path.read_text(encoding="utf-8")
        is_tscn = file_path.suffix.lower() == ".tscn"
        seen_in_line: set[tuple[int, int]] = set()
        for line_no, ch in iter_string_literal_chars(content, is_tscn=is_tscn):
            if ch in IGNORED_CONTROL_CHARS:
                continue
            cp = ord(ch)
            if cp < 0x20:
                continue
            seen_chars.add(cp)
            if cp not in covered:
                key = (cp, line_no)
                if key not in seen_in_line:
                    seen_in_line.add(key)
                    missing_locations[cp].append(f"{rel_path}:{line_no}")

    font_summary = ", ".join(f"{name}={count}" for name, count in per_font_counts.items())
    print(f"[verify_font_glyphs] Loaded font cmaps ({font_summary}; union={len(covered)} glyphs)")
    print(f"[verify_font_glyphs] Scanned {len(scan_files)} files ({len(seen_chars)} unique runtime characters)")

    if not missing_locations:
        print("[verify_font_glyphs] OK: 100% of runtime string literal characters are covered.")
        return 0

    print(f"[verify_font_glyphs] FAIL: {len(missing_locations)} missing character(s) detected:")
    for cp in sorted(missing_locations):
        ch = chr(cp)
        locs = ", ".join(missing_locations[cp])
        print(f"  - U+{cp:04X} ({ch}): {locs}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
