"""Build the real-renderer art gallery and compare identical-camera performance.

python tools/art_report.py .tools/abzu-review/before .tools/abzu-review/after
Requires Pillow. Screenshot production: tests/art_review.gd.
"""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
REGIONS = [('core','中央浅礁'),('atoll','北境珊瑚环礁'),('kelp','翡翠巨藻海峡'),
           ('ridge','极光晶柱海岭'),('citadel','沉没星象古都'),('wreck','幽灵沉船海滩'),
           ('bones','巨兽龙骨荒原'),('caldera','黑曜石火山口'),('hadal','极渊星辉圣域')]

def font(size):
    return ImageFont.truetype(str(ROOT/'assets/fonts/NotoSansSC-Subset.otf'),size)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('before',type=Path)
    parser.add_argument('after',type=Path)
    args=parser.parse_args()
    docs=ROOT/'docs'
    gallery=Image.new('RGB',(1920,3*444),(7,29,47))
    details=Image.new('RGB',gallery.size,(7,29,47))
    comparison=Image.new('RGB',(1280,9*440+52),(7,29,47))
    ImageDraw.Draw(comparison).text((22,12),'改造前  /  BEFORE                                    改造后  /  AFTER',(237,206,122),font=font(20))
    for i,(key,label) in enumerate(REGIONS):
        for sheet,view in [(gallery,'arrival'),(details,'detail')]:
            x,y=(i%3)*640,(i//3)*444
            picture=Image.open(args.after/f'{key}-{view}.png').convert('RGB').resize((640,400),Image.Resampling.LANCZOS)
            sheet.paste(picture,(x,y))
            ImageDraw.Draw(sheet).text((x+16,y+410),f'{i+1:02}  {label}',(237,230,207),font=font(19))
        y=52+i*440
        for col,directory in enumerate((args.before,args.after)):
            picture=Image.open(directory/f'{key}-arrival.png').convert('RGB').resize((640,400),Image.Resampling.LANCZOS)
            comparison.paste(picture,(col*640,y))
        ImageDraw.Draw(comparison).text((20,y+407),label,(237,230,207),font=font(19))
    gallery.save(docs/'art-nine-seas.png',optimize=True)
    details.save(docs/'art-details.png',optimize=True)
    comparison.save(docs/'art-comparison.png',optimize=True)
    before={row['region']:row for row in json.loads((args.before/'performance.json').read_text())}
    after=json.loads((args.after/'performance.json').read_text())
    results=[]
    for row in after:
        old=before[row['region']]
        results.append({'region':row['region'],'before':old,'after':row,
                        'p95_change_percent':round((row['p95_ms']/old['p95_ms']-1)*100,1),
                        'draw_call_change_percent':round((row['draw_calls']/old['draw_calls']-1)*100,1)})
    report={'renderer':'Godot 4.7.2 Compatibility / AMD Radeon Graphics','resolution':[1280,800],
            'camera_script':'tests/art_review.gd','samples_per_region':80,'regions':results,
            'p95_gate_passed':all(row['p95_change_percent']<=15 for row in results)}
    (docs/'art-performance.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'p95_gate_passed':report['p95_gate_passed'],'regions':[
        {key:row[key] for key in ('region','p95_change_percent','draw_call_change_percent')} for row in results]},indent=2))

if __name__=='__main__':
    main()
