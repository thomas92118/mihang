"""Build an art gallery and compare captures from the same review harness.

Legacy usage writes to docs/: python tools/art_report.py BEFORE AFTER
Use --output-dir for a new review without overwriting the published gallery.
"""
import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
REGIONS = [
    ("core", "中央浅礁"), ("atoll", "北境珊瑚环礁"), ("kelp", "翡翠巨藻海峡"),
    ("ridge", "极光晶柱海岭"), ("citadel", "沉没星象古都"), ("wreck", "幽灵沉船海滩"),
    ("bones", "巨兽龙骨荒原"), ("caldera", "黑曜石火山口"), ("hadal", "极渊星辉圣域"),
]


def font(size):
    return ImageFont.truetype(str(ROOT / "assets/fonts/NotoSansSC-Subset.otf"), size)


def read_capture(directory):
    raw = json.loads((directory / "performance.json").read_text(encoding="utf-8"))
    rows = raw["regions"] if isinstance(raw, dict) else raw
    if not rows:
        raise ValueError(f"No performance samples in {directory}")
    keys = [row["region"] for row in rows]
    if len(set(keys)) != len(keys):
        raise ValueError(f"Duplicate region samples in {directory}")
    metadata_file = directory / "environment.json"
    metadata = json.loads(metadata_file.read_text(encoding="utf-8")) if metadata_file.exists() else {}
    return {row["region"]: row for row in rows}, metadata


def compare_captures(before, after, before_env, after_env, maximum_regression=15.0):
    if set(before) != set(after):
        raise ValueError("Before/after region selections must match exactly")
    environment_changes = {}
    for key in ("platform", "renderer", "rendering_driver", "adapter", "adapter_vendor",
                "resolution", "vsync_mode", "max_fps", "capture_mode", "review_phase_seconds",
                "samples_per_region", "warmup_frames"):
        if key in before_env and key in after_env and before_env[key] != after_env[key]:
            environment_changes[key] = {"before": before_env[key], "after": after_env[key]}
    before_version = before_env.get("engine", {}).get("string")
    after_version = after_env.get("engine", {}).get("string")
    if before_version and after_version and before_version != after_version:
        environment_changes["engine"] = {"before": before_version, "after": after_version}
    results = []
    for key, _label in REGIONS:
        if key not in after:
            continue
        old, current = before[key], after[key]
        metrics = (old["p95_ms"], old["draw_calls"], current["p95_ms"], current["draw_calls"])
        if any(not math.isfinite(value) or value <= 0 for value in metrics):
            raise ValueError(f"Captures must contain finite positive timings/draw calls: {key}")
        change = (current["p95_ms"] / old["p95_ms"] - 1.0) * 100.0
        results.append({
            "region": key, "before": old, "after": current,
            "p95_change_percent": round(change, 2),
            "p95_gate_passed": change <= maximum_regression,
            "draw_call_change_percent": round((current["draw_calls"] / old["draw_calls"] - 1.0) * 100.0, 2),
        })
    if len(results) != len(after):
        raise ValueError("Capture contains an unknown region")
    required_metadata = ("engine", "platform", "renderer", "adapter", "resolution", "vsync_mode",
                         "max_fps", "capture_mode", "review_phase_seconds", "samples_per_region", "warmup_frames")
    metadata_complete = bool(before_version and after_version) and all(
        key in before_env and key in after_env for key in required_metadata
    )
    renderer = " / ".join((after_version or "unrecorded engine", after_env.get("renderer", "unrecorded renderer"), after_env.get("adapter", "unrecorded adapter")))
    return {
        "renderer": renderer,
        "resolution": after_env.get("resolution"),
        "camera_script": after_env.get("camera_script", "tests/art_review.gd"),
        "samples_per_region": after_env.get("samples_per_region"),
        "capture_mode": after_env.get("capture_mode", "legacy_unrecorded"),
        "before_environment": before_env,
        "after_environment": after_env,
        "environment_verified": metadata_complete and not environment_changes,
        "environment_changes": environment_changes,
        "environment_warning": "" if metadata_complete else "Legacy capture: runtime environment was not recorded; timing comparability is unverified.",
        "maximum_p95_regression_percent": maximum_regression,
        "regions": results,
        "p95_gate_passed": all(row["p95_gate_passed"] for row in results) and not environment_changes,
        "scope_note": "Static fixed-camera timings do not validate live gameplay, streaming or browser performance.",
    }


def build_gallery(before_dir, after_dir, output_dir, regions):
    output_dir.mkdir(parents=True, exist_ok=True)
    row_count = math.ceil(len(regions) / 3)
    gallery = Image.new("RGB", (1920, row_count * 444), (7, 29, 47))
    details = Image.new("RGB", gallery.size, (7, 29, 47))
    comparison = Image.new("RGB", (1280, len(regions) * 440 + 52), (7, 29, 47))
    ImageDraw.Draw(comparison).text((22, 12), "改造前  /  BEFORE                                    改造后  /  AFTER", (237, 206, 122), font=font(20))
    for index, (key, label) in enumerate(regions):
        for sheet, view in ((gallery, "arrival"), (details, "detail")):
            x, y = (index % 3) * 640, (index // 3) * 444
            with Image.open(after_dir / f"{key}-{view}.png") as source:
                picture = source.convert("RGB").resize((640, 400), Image.Resampling.LANCZOS)
            sheet.paste(picture, (x, y))
            ImageDraw.Draw(sheet).text((x + 16, y + 410), f"{index + 1:02}  {label}", (237, 230, 207), font=font(19))
        y = 52 + index * 440
        for column, directory in enumerate((before_dir, after_dir)):
            with Image.open(directory / f"{key}-arrival.png") as source:
                picture = source.convert("RGB").resize((640, 400), Image.Resampling.LANCZOS)
            comparison.paste(picture, (column * 640, y))
        ImageDraw.Draw(comparison).text((20, y + 407), label, (237, 230, 207), font=font(19))
    gallery.save(output_dir / "art-nine-seas.png", optimize=True)
    details.save(output_dir / "art-details.png", optimize=True)
    comparison.save(output_dir / "art-comparison.png", optimize=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "docs")
    parser.add_argument("--max-p95-regression", type=float, default=15.0)
    parser.add_argument("--fail-on-regression", action="store_true")
    args = parser.parse_args()
    before, before_env = read_capture(args.before)
    after, after_env = read_capture(args.after)
    report = compare_captures(before, after, before_env, after_env, args.max_p95_regression)
    regions = [(key, label) for key, label in REGIONS if key in after]
    build_gallery(args.before, args.after, args.output_dir, regions)
    (args.output_dir / "art-performance.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "output_directory": str(args.output_dir),
        "environment_verified": report["environment_verified"],
        "environment_changes": report["environment_changes"],
        "p95_gate_passed": report["p95_gate_passed"],
        "regions": [{"region": row["region"], "before_p95_ms": row["before"]["p95_ms"],
                     "after_p95_ms": row["after"]["p95_ms"], "p95_change_percent": row["p95_change_percent"],
                     "draw_call_change_percent": row["draw_call_change_percent"]} for row in report["regions"]],
    }, ensure_ascii=False, indent=2))
    if args.fail_on_regression and (not report["p95_gate_passed"] or not report["environment_verified"]):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
