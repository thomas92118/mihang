"""Rebuild the bundled OFL font from the glyphs used by runtime scripts.

Usage: python tools/subset_font.py .tools/NotoSansCJKsc-Regular.otf
Source: https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/SimplifiedChinese
"""
import argparse
from pathlib import Path
from fontTools import subset

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    sources = (
        list((ROOT / 'scripts').rglob('*.gd'))
        + list((ROOT / 'scenes').rglob('*.tscn'))
        + [ROOT / 'tools' / 'art_report.py']
    )
    text = ''.join(path.read_text(encoding='utf-8') for path in sources if path.exists())
    options = subset.Options()
    options.name_IDs = ['*']
    options.name_legacy = True
    options.name_languages = ['*']
    font = subset.load_font(str(args.source), options)
    worker = subset.Subsetter(options=options)
    worker.populate(unicodes=set(map(ord, text)) | set(range(32, 127)))
    worker.subset(font)
    subset.save_font(font, str(ROOT/'assets/fonts/NotoSansSC-Subset.otf'), options)
    print('Updated bundled Chinese glyph subset')

if __name__ == '__main__':
    main()
