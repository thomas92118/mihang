"""Record technical checks independently of reference likeness acceptance."""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/source/reference-fidelity'


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--godot')
    args=parser.parse_args()
    godot=args.godot or shutil.which('Godot_v4.7.2-stable_win64_console.exe') or shutil.which('godot')
    if not godot:raise RuntimeError('Godot executable missing')
    logs=ROOT/'.tools/reference-verification';logs.mkdir(parents=True,exist_ok=True)
    tests=[(name,['--headless','--path','.','-s','tests/'+name+'.gd'],80) for name in (
        'reference_diver','character_art','art_regression','smoke','submarines_and_booster','mount_tame_mothertree_schools')]
    tests.append(('character_visual',['--path','.','--position','-3000,-3000','-s','tests/art_character_visual.gd',
                                     '--','res://assets/source/reference-fidelity/gameplay'],180))
    results=[]
    for name,args,timeout in tests:
        path=logs/(name+'.log');code=-1
        with path.open('w',encoding='utf-8') as handle:
            try:code=subprocess.run([godot]+args,cwd=ROOT,stdout=handle,stderr=subprocess.STDOUT,timeout=timeout).returncode
            except subprocess.TimeoutExpired:pass
        text=path.read_text(encoding='utf-8',errors='replace')
        errors=[s for s in text.splitlines() if any(k in s for k in ('SCRIPT ERROR:','SHADER ERROR:')) or s.startswith(('ERROR:','FAIL:'))]
        passed=code==0 and not errors and 'PASS' in text
        results.append({'test':name,'passed':passed,'exit_code':code,'errors':errors,'log':str(path.relative_to(ROOT)).replace('\\','/')})
        print(('PASS ' if passed else 'FAIL ')+name,flush=True)
        if not passed:print(text[-3000:],flush=True);break
    model=ROOT/'assets/models/reference_diver.glb'
    report={'technical_checks_passed':len(results)==len(tests) and all(x['passed'] for x in results),'results':results,
            'model_sha256':hashlib.sha256(model.read_bytes()).hexdigest(),'visual_fidelity_accepted':False,
            'scope':'Technical checks do not certify likeness or 100 percent reconstruction.'}
    (OUT/'technical-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    raise SystemExit(0 if report['technical_checks_passed'] else 1)


if __name__=='__main__':main()
