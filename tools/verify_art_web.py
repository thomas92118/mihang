"""Verify isolated Web art probes and the ordinary game in local Chrome.

The probe exports are built by build_art_web_probe.mjs. Baseline and candidate
use the same browser process, viewport, device scale, camera sequence and sample
settings. A temporary loopback server supplies COOP/COEP; everything is closed
on success or failure. No deployment or production-project edits occur.
"""
from __future__ import annotations

import argparse
import contextlib
import functools
import hashlib
import http.server
import json
import math
from pathlib import Path
import statistics
import threading
import time
import traceback
from urllib.parse import urlencode

from PIL import Image, ImageChops, ImageStat
from playwright.sync_api import sync_playwright


REGIONS = ("core", "atoll", "kelp", "ridge", "citadel", "wreck", "bones", "caldera", "hadal")
CHROME_ARGS = [
    "--enable-webgl", "--ignore-gpu-blocklist",
    "--disable-background-timer-throttling", "--disable-renderer-backgrounding",
    "--disable-backgrounding-occluded-windows",
    "--autoplay-policy=no-user-gesture-required", "--mute-audio",
]


class HeadersHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".wasm": "application/wasm", ".pck": "application/octet-stream"}

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *_args):
        pass


@contextlib.contextmanager
def local_server(directory: Path):
    if not (directory / "index.html").is_file():
        raise FileNotFoundError(f"No index.html in {directory}")
    handler = functools.partial(HeadersHandler, directory=str(directory))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    server.daemon_threads = True
    worker = threading.Thread(target=server.serve_forever, name="art-web-qa", daemon=True)
    worker.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}/index.html"
    finally:
        server.shutdown()
        server.server_close()
        worker.join(timeout=5)


def write_json(path: Path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def image_info(path: Path):
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        extrema = rgb.getextrema()
        return {"size": list(rgb.size), "channel_ranges": extrema,
                "nonblank": max(high - low for low, high in extrema) > 12,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def difference(first: Path, second: Path):
    with Image.open(first) as a, Image.open(second) as b:
        a = a.convert("RGB").resize((320, 200))
        b = b.convert("RGB").resize((320, 200))
        return sum(ImageStat.Stat(ImageChops.difference(a, b)).mean) / (255.0 * 3.0)


def attach_events(page):
    events = []
    errors = []

    def console(message):
        text = message.text
        if len(events) < 3000:
            events.append({"type": message.type, "text": text})
        if message.type == "error" or "SCRIPT ERROR:" in text or text.startswith("ERROR:"):
            errors.append(text)

    page.on("console", console)
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.on("requestfailed", lambda request: errors.append(f"Request failed: {request.url}: {request.failure}"))
    page.on("response", lambda response: errors.append(f"HTTP {response.status}: {response.url}")
            if response.status >= 400 and not response.url.endswith("favicon.ico") else None)
    return events, errors


def webgl_info(page):
    return page.evaluate("""() => {
      const canvas = document.querySelector('#canvas');
      const gl = canvas && canvas.getContext('webgl2');
      if (!gl) return {webgl2: false};
      const debug = gl.getExtension('WEBGL_debug_renderer_info');
      return {webgl2: true, renderer: gl.getParameter(gl.RENDERER), vendor: gl.getParameter(gl.VENDOR),
        version: gl.getParameter(gl.VERSION), shading_language: gl.getParameter(gl.SHADING_LANGUAGE_VERSION),
        unmasked_renderer: debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : null,
        unmasked_vendor: debug ? gl.getParameter(debug.UNMASKED_VENDOR_WEBGL) : null,
        canvas_size: [canvas.width, canvas.height], device_pixel_ratio: window.devicePixelRatio,
        cross_origin_isolated: window.crossOriginIsolated};
    }""")


def collect_probe(browser, directory: Path, output: Path, options):
    output.mkdir(parents=True, exist_ok=True)
    (output / "failure.png").unlink(missing_ok=True)
    context = browser.new_context(viewport={"width": options.width, "height": options.height}, device_scale_factor=1)
    page = context.new_page()
    events, errors = attach_events(page)
    result = {"source_directory": str(directory), "screenshots": {}, "errors": errors}
    metadata = directory.parents[2] / "build-metadata.json"
    if metadata.is_file():
        result["build_metadata"] = json.loads(metadata.read_text(encoding="utf-8"))
    started = time.monotonic()
    try:
        with local_server(directory) as url:
            query = urlencode({"samples": options.samples, "warmup": options.warmup,
                               "phase": options.phase, "width": options.width, "height": options.height})
            page.goto(url + "?" + query, wait_until="domcontentloaded", timeout=60000)
            while True:
                remaining = int((options.timeout - (time.monotonic() - started)) * 1000)
                if remaining <= 0:
                    raise TimeoutError("Web probe exceeded total timeout")
                handle = page.wait_for_function("""() => (window.artReview && (
                    window.artReview.status === 'done' || window.artReview.status === 'error' ||
                    (window.artReview.status === 'capture_ready' && window.artReview.capture !== window.artReviewAck))
                ) ? window.artReview : null""", timeout=remaining)
                state = handle.json_value()
                handle.dispose()
                if state["status"] == "error":
                    raise RuntimeError(state.get("message", "Web probe error"))
                if state["status"] == "done":
                    result["probe"] = state
                    break
                name = state["capture"]
                screenshot = output / f"{name}.png"
                page.locator("#canvas").screenshot(path=str(screenshot), timeout=30000)
                result["screenshots"][name] = image_info(screenshot)
                page.evaluate("capture => { window.artReviewAck = capture; }", name)
                print(f"WEB {output.name}: {name}", flush=True)
            result["webgl"] = webgl_info(page)
            result["duration_seconds"] = round(time.monotonic() - started, 3)
            rows = result["probe"]["regions"]
            result["passed"] = (not errors and result["webgl"].get("webgl2")
                                and {row["region"] for row in rows} == set(REGIONS)
                                and len(result["screenshots"]) == 18
                                and all(shot["nonblank"] for shot in result["screenshots"].values()))
    except Exception:
        result["exception"] = traceback.format_exc()
        result["passed"] = False
        try:
            page.screenshot(path=str(output / "failure.png"), timeout=10000)
            result["last_probe_state"] = page.evaluate("window.artReview || null")
        except Exception:
            pass
    finally:
        write_json(output / "console.json", events)
        write_json(output / "result.json", result)
        if "probe" in result:
            write_json(output / "performance.json", result["probe"]["regions"])
            write_json(output / "environment.json", result["probe"]["environment"])
        context.close()
    return result


def raf_frames(page, count):
    return page.evaluate("""count => new Promise(resolve => {
      const times = []; let last = performance.now();
      function sample(now) { times.push(now - last); last = now;
        if (times.length >= count) resolve(times); else requestAnimationFrame(sample); }
      requestAnimationFrame(sample);
    })""", count)


def gameplay_smoke(browser, directory: Path, output: Path, options):
    output.mkdir(parents=True, exist_ok=True)
    (output / "failure.png").unlink(missing_ok=True)
    context = browser.new_context(viewport={"width": options.width, "height": options.height}, device_scale_factor=1)
    context.set_default_timeout(120000)
    page = context.new_page()
    events, errors = attach_events(page)
    result = {"source_directory": str(directory), "errors": errors,
              "state_observation": "Ordinary uninstrumented game; real mouse/keyboard input, pointer-lock observation and screenshot comparison. Review screenshots to confirm canvas UI states."}
    try:
        with local_server(directory) as url:
            page.goto(url, wait_until="domcontentloaded", timeout=60000)
            page.wait_for_function("""() => {
              const status = document.querySelector('#status');
              const canvas = document.querySelector('#canvas');
              return Boolean(canvas && canvas.width >= 640 && !status);
            }""", timeout=options.timeout * 1000)
            raf_frames(page, 45)
            page.locator("#canvas").screenshot(path=str(output / "01-main.png"))
            print("WEB gameplay: 01-main", flush=True)
            box = page.locator("#canvas").bounding_box()
            if not box:
                raise RuntimeError("Game canvas has no clickable bounds")
            page.locator("#canvas").click(position={"x": options.explore_x * box["width"] / 1280,
                                                    "y": options.explore_y * box["height"] / 800})
            raf_frames(page, 30)
            result["pointer_locked_after_explore"] = page.evaluate("document.pointerLockElement === document.querySelector('#canvas')")
            page.locator("#canvas").screenshot(path=str(output / "02-explore.png"))
            print("WEB gameplay: 02-explore", flush=True)
            page.keyboard.down("w")
            try:
                intervals = raf_frames(page, 120)
            finally:
                page.keyboard.up("w")
            page.mouse.move(box["x"] + box["width"] * .55, box["y"] + box["height"] * .48, steps=8)
            page.keyboard.press("Space")
            raf_frames(page, 12)
            page.locator("#canvas").screenshot(path=str(output / "03-moved.png"))
            print("WEB gameplay: 03-moved", flush=True)
            page.keyboard.press("m")
            raf_frames(page, 12)
            page.locator("#canvas").screenshot(path=str(output / "04-map.png"))
            print("WEB gameplay: 04-map", flush=True)
            page.keyboard.press("m")
            raf_frames(page, 8)
            page.keyboard.press("Escape")
            raf_frames(page, 12)
            page.locator("#canvas").screenshot(path=str(output / "05-pause.png"))
            print("WEB gameplay: 05-pause", flush=True)
            page.keyboard.press("Escape")
            raf_frames(page, 12)
            page.locator("#canvas").screenshot(path=str(output / "06-resumed.png"))
            print("WEB gameplay: 06-resumed", flush=True)
            result["webgl"] = webgl_info(page)
            result["screenshots"] = {file.stem: image_info(file) for file in sorted(output.glob("0*.png"))}
            result["main_to_explore_difference"] = difference(output / "01-main.png", output / "02-explore.png")
            result["explore_to_moved_difference"] = difference(output / "02-explore.png", output / "03-moved.png")
            result["moved_to_map_difference"] = difference(output / "03-moved.png", output / "04-map.png")
            ordered = sorted(intervals[1:])
            result["moving_browser_raf"] = {"samples": len(ordered), "p50_ms": statistics.median(ordered),
                                             "p95_ms": ordered[max(0, math.ceil(len(ordered) * .95) - 1)]}
            result["passed"] = (not errors and result["webgl"].get("webgl2")
                                and result["main_to_explore_difference"] > .02
                                and result["moved_to_map_difference"] > .02
                                and all(shot["nonblank"] for shot in result["screenshots"].values()))
    except Exception:
        result["passed"] = False
        result["exception"] = traceback.format_exc()
        try:
            page.screenshot(path=str(output / "failure.png"), timeout=10000)
        except Exception:
            pass
    finally:
        write_json(output / "console.json", events)
        write_json(output / "result.json", result)
        context.close()
    return result


def comparison(baseline, candidate, limit):
    if "probe" not in baseline or "probe" not in candidate:
        return {"passed": False, "reason": "One or both probes did not finish"}
    before = {row["region"]: row for row in baseline["probe"]["regions"]}
    after = {row["region"]: row for row in candidate["probe"]["regions"]}
    a_env, b_env = baseline["probe"]["environment"], candidate["probe"]["environment"]
    same_settings = all(a_env.get(key) == b_env.get(key) for key in (
        "engine", "renderer", "resolution", "samples_per_region", "warmup_frames",
        "review_phase_seconds", "camera_fov", "camera_far", "vsync_mode", "max_fps"))
    same_probe = (baseline.get("build_metadata", {}).get("probe_sha256") ==
                  candidate.get("build_metadata", {}).get("probe_sha256"))
    rows = []
    for region in REGIONS:
        if region not in before or region not in after:
            return {"passed": False, "reason": f"Missing region {region}"}
        a, b = before[region], after[region]
        identical = all(abs(x - y) < .0001 for x, y in zip(a["camera_position"], b["camera_position"]))
        change = (b["p95_ms"] / max(a["p95_ms"], .000001) - 1) * 100
        rows.append({"region": region, "baseline_p95_ms": a["p95_ms"], "candidate_p95_ms": b["p95_ms"],
                     "p95_change_percent": round(change, 2), "same_camera": identical,
                     "baseline_draw_calls": a["draw_calls"], "candidate_draw_calls": b["draw_calls"],
                     "passed": identical and change <= limit})
    return {"limit_percent": limit, "same_settings": same_settings, "same_probe": same_probe, "regions": rows,
            "passed": same_settings and same_probe and baseline.get("passed", False)
                      and candidate.get("passed", False) and all(row["passed"] for row in rows)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--game", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--chrome", type=Path, default=Path("C:/Program Files/Google/Chrome/Application/chrome.exe"))
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=800)
    parser.add_argument("--samples", type=int, default=80)
    parser.add_argument("--warmup", type=int, default=60)
    parser.add_argument("--phase", type=float, default=12.0)
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--p95-limit", type=float, default=15)
    parser.add_argument("--explore-x", type=float, default=260)
    parser.add_argument("--explore-y", type=float, default=560)
    options = parser.parse_args()
    if bool(options.baseline) != bool(options.candidate) or not (options.baseline or options.game):
        parser.error("Provide both --baseline and --candidate, and/or --game")
    options.output = options.output.resolve()
    options.output.mkdir(parents=True, exist_ok=True)
    report = {"browser_executable": str(options.chrome.resolve()), "launch_args": CHROME_ARGS,
              "viewport": [options.width, options.height], "device_scale_factor": 1, "headless": True,
              "metric_scope": "Same-camera browser-paced WebGL2 frame intervals; separate from desktop and ordinary live-game measurements."}
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(executable_path=str(options.chrome), headless=True, args=CHROME_ARGS)
            try:
                report["browser_version"] = browser.version
                try:
                    cdp = browser.new_browser_cdp_session()
                    report["browser_system_info"] = cdp.send("SystemInfo.getInfo")
                    cdp.detach()
                except Exception as error:
                    report["system_info_unavailable"] = str(error)
                if options.baseline:
                    report["baseline"] = collect_probe(browser, options.baseline.resolve(), options.output / "baseline", options)
                    report["candidate"] = collect_probe(browser, options.candidate.resolve(), options.output / "candidate", options)
                    report["comparison"] = comparison(report["baseline"], report["candidate"], options.p95_limit)
                if options.game:
                    report["gameplay"] = gameplay_smoke(browser, options.game.resolve(), options.output / "gameplay", options)
                report["passed"] = all(report[key]["passed"] for key in ("comparison", "gameplay") if key in report)
            finally:
                browser.close()
    except Exception:
        report["passed"] = False
        report["exception"] = traceback.format_exc()
    write_json(options.output / "web-verification.json", report)
    print(json.dumps({"passed": report["passed"], "browser": report.get("browser_version"),
                      "regions": report.get("comparison", {}).get("regions"),
                      "gameplay_passed": report.get("gameplay", {}).get("passed"),
                      "report": str(options.output / "web-verification.json")}, ensure_ascii=False, indent=2), flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
