"""Rebuild the bundled OFL font from the glyphs used by runtime scripts.

Usage: python tools/subset_font.py .tools/NotoSansCJKsc-Regular.otf
Source: https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/SimplifiedChinese
"""
import argparse
from pathlib import Path
from fontTools import subset

ROOT = Path(__file__).resolve().parents[1]
MOBILE_EXTRA_GLYPHS = (
    '窗口全屏横竖屏旋转双指捏合缩放拖拽滑动点击长按按住松开返回菜单暂停设置'
    '流畅画质性能超重追踪骑乘离舰引爆退镜连接恢复休眠桌面图标点按轻触滑屏'
    '双击上下左右内外远近快慢高低大小开关启停继续开始重新确认取消完成关闭'
    '打开展开收起安全区刘海灵动岛触控手柄键鼠视角镜头存档自动保存离线网络'
    '重试刷新加载渲染帧率省电标准高清极速'
)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    sources = (
        list((ROOT / 'scripts').rglob('*.gd'))
        + list((ROOT / 'scenes').rglob('*.tscn'))
        + [
            ROOT / 'assets' / 'web' / 'custom_shell.html',
            ROOT / 'tools' / 'art_report.py',
        ]
    )
    text = ''.join(path.read_text(encoding='utf-8') for path in sources if path.exists()) + MOBILE_EXTRA_GLYPHS
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
