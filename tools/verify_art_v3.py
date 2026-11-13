"""Run focused Godot regressions and reject script errors even with exit code 0.

Usage: rtk proxy python tools/verify_art_v3.py [--visual]
The durable report includes actual source/model hashes and execution logs.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--visual', action='store_true')
    parser.add_argument('--godot')
    args = parser.parse_args()
    godot = args.godot or next((shutil.which(name) for name in ('godot', 'godot4', 'Godot_v4.7.2-stable_win64_console.exe') if shutil.which(name)), None)
    if not godot:
        raise RuntimeError('Pass the local Godot console executable with --godot')
    out = ROOT / 'assets/source/art-v3/verification'
    out.mkdir(parents=True, exist_ok=True)
    logs = ROOT / '.tools/art-v3-verification'
    logs.mkdir(parents=True, exist_ok=True)
    jobs = [(name, ['--headless', '--path', '.', '-s', 'tests/'+name+'.gd'], 95) for name in (
        'asset_pipeline', 'character_art', 'art_v3_pipeline', 'art_regression',
        'art_composition', 'seabed_ecology', 'submarines_and_booster',
        'mount_tame_mothertree_schools', 'smoke')]
    if args.visual:
        for name, script, location, extra in (
            ('character_visual', 'art_character_visual', 'character', []),
            ('nine_regions', 'art_review', 'regions', ['--samples', '20', '--warmup', '20']),
            ('water_visual', 'water_visual', 'water', [])):
            jobs.append((name, ['--path', '.', '--position', '-3000,-3000', '-s', 'tests/'+script+'.gd', '--',
                                'res://assets/source/art-v3/verification/'+location] + extra, 180))
    results = []
    for name, command, timeout in jobs:
        logfile = logs / (name+'.log')
        start = time.monotonic()
        timed_out = False
        with logfile.open('w', encoding='utf-8') as handle:
            try:
                process = subprocess.run([godot]+command, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT, timeout=timeout)
                code = process.returncode
            except subprocess.TimeoutExpired:
                timed_out = True
                code = -1
        text = logfile.read_text(encoding='utf-8', errors='replace')
        errors = [line for line in text.splitlines() if 'SCRIPT ERROR:' in line or line.startswith(('ERROR:', 'SHADER ERROR:', 'FAIL:'))]
        passed = code == 0 and not errors and 'PASS' in text and not timed_out
        results.append({'test':name, 'passed':passed, 'exit_code':code, 'timeout':timed_out,
                        'seconds':round(time.monotonic()-start, 2), 'errors':errors,
                        'log':str(logfile.relative_to(ROOT)).replace('\\','/')})
        print(('PASS ' if passed else 'FAIL ')+name+' '+str(results[-1]['seconds'])+'s', flush=True)
        if not passed:
            print(text[-5000:], flush=True)
            break
    hashes = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'assets/models').glob('*.glb')}
    scripts = {str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest()
               for folder,pattern in [('scripts','*.gd'),('shaders','*.gdshader'),('tools','art_v3_*.py')]
               for p in (ROOT/folder).rglob(pattern)}
    record = {'godot':subprocess.check_output([godot,'--version'],text=True).strip(), 'results':results,
              'all_passed':len(results)==len(jobs) and all(r['passed'] for r in results),
              'model_sha256':hashes,'implementation_sha256':scripts,
              'scope':'Local Godot Compatibility; visual captures use the real OpenGL renderer. No browser or deployment claims.'}
    (out/'results.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    raise SystemExit(0 if record['all_passed'] else 1)


if __name__ == '__main__':
    main()
