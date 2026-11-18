"""End-to-end mobile Web verification for build/web using Playwright mobile emulation."""
from __future__ import annotations

import contextlib
import functools
import http.server
import io
import json
from pathlib import Path
import re
import threading
import time

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
WEB_DIR = ROOT / "build" / "web"

CHROME_ARGS = [
    "--enable-webgl",
    "--ignore-gpu-blocklist",
    "--disable-background-timer-throttling",
    "--disable-renderer-backgrounding",
    "--disable-backgrounding-occluded-windows",
    "--autoplay-policy=no-user-gesture-required",
    "--mute-audio",
]


class HeadersHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *_args):
        pass


class QuietHTTPServer(http.server.ThreadingHTTPServer):
    def handle_error(self, request, client_address):
        pass


@contextlib.contextmanager
def local_server(directory: Path):
    if not (directory / "index.html").is_file():
        raise FileNotFoundError(f"Missing index.html in {directory}")
    handler = functools.partial(HeadersHandler, directory=str(directory))
    server = QuietHTTPServer(("127.0.0.1", 0), handler)
    server.daemon_threads = True
    worker = threading.Thread(target=server.serve_forever, name="mobile-web-qa", daemon=True)
    worker.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}/index.html"
    finally:
        server.shutdown()
        server.server_close()
        worker.join(timeout=5)


def verify_pwa_artifacts() -> None:
    manifest_path = WEB_DIR / "index.manifest.json"
    sw_path = WEB_DIR / "index.service.worker.js"
    chunks_path = WEB_DIR / "chunks.json"
    html_path = WEB_DIR / "index.html"
    assert manifest_path.is_file(), "Missing index.manifest.json"
    assert sw_path.is_file(), "Missing index.service.worker.js"
    assert chunks_path.is_file(), "Missing chunks.json"
    assert html_path.is_file(), "Missing index.html"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert manifest.get("display") in ("standalone", "fullscreen"), f"Unexpected PWA display: {manifest.get('display')}"
    assert manifest.get("orientation") == "any", f"Unexpected PWA orientation: {manifest.get('orientation')}"
    icons = manifest.get("icons") or []
    assert isinstance(icons, list) and len(icons) >= 2, f"PWA manifest must include icons: {icons}"
    icon_sizes = {str(item.get("sizes", "")) for item in icons if isinstance(item, dict)}
    assert "144x144" in icon_sizes and "512x512" in icon_sizes, f"PWA manifest missing expected icon sizes: {icon_sizes}"
    for item in icons:
        src = str(item.get("src", "")).lstrip("/")
        assert src and (WEB_DIR / src).is_file(), f"Missing exported PWA icon file: {src}"
    if (WEB_DIR / "index.apple-touch-icon.png").is_file():
        html_text = html_path.read_text(encoding="utf-8")
        assert 'rel="apple-touch-icon"' in html_text, "index.html must link apple-touch-icon when exported"

    chunks = json.loads(chunks_path.read_text(encoding="utf-8"))
    wasm_parts = (chunks.get("index.wasm") or {}).get("parts") or []
    pck_parts = (chunks.get("index.pck") or {}).get("parts") or []
    assert wasm_parts and re.match(r"^index\.wasm\.gz\.part0\.[0-9a-f]{8}$", wasm_parts[0]), (
        f"Expected content-hashed index.wasm.gz.part0.<hash8>, got: {wasm_parts[:1]}"
    )
    assert pck_parts and re.match(r"^index\.pck\.gz\.part0\.[0-9a-f]{8}$", pck_parts[0]), (
        f"Expected content-hashed index.pck.gz.part0.<hash8>, got: {pck_parts[:1]}"
    )
    assert (WEB_DIR / wasm_parts[0]).is_file() and (WEB_DIR / pck_parts[0]).is_file(), (
        "Hashed .gz.part0.* chunk files missing on disk"
    )
    sw_text = sw_path.read_text(encoding="utf-8")
    assert "index.wasm.gz.part0." in sw_text and "index.pck.gz.part0." in sw_text, (
        "Service worker CACHEABLE_FILES must include content-hashed .gz.part0.<hash> files"
    )
    assert wasm_parts[0] in sw_text and pck_parts[0] in sw_text, (
        "Service worker CACHEABLE_FILES out of sync with chunks.json hashes"
    )
    print("[verify_mobile_web] PWA manifest, icons & content-hashed chunked service worker verified.")


def verify_shell_matrix(browser, base_url: str) -> None:
    cases = [
        ("compact_portrait", 360, 740, 2, {"top": 24, "right": 0, "bottom": 16, "left": 0}),
        ("iphone14pro_portrait", 390, 844, 3, {"top": 59, "right": 0, "bottom": 34, "left": 0}),
        ("compact_landscape", 640, 360, 2, {"top": 0, "right": 24, "bottom": 12, "left": 24}),
        ("iphone14pro_landscape", 844, 390, 3, {"top": 0, "right": 59, "bottom": 21, "left": 59}),
    ]
    for label, w, h, dpr, insets in cases:
        ctx = browser.new_context(
            viewport={"width": w, "height": h},
            device_scale_factor=dpr,
            is_mobile=True,
            has_touch=True,
            user_agent="Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1",
        )
        # Pause chunk fetching briefly so we inspect the live loading screen deterministically.
        ctx.add_init_script(
            f"""
            window.__abyssalMockSafeInsets = {json.dumps(insets)};
            document.addEventListener('DOMContentLoaded', () => {{
                const r = document.documentElement.style;
                r.setProperty('--safe-top', '{insets["top"]}px');
                r.setProperty('--safe-right', '{insets["right"]}px');
                r.setProperty('--safe-bottom', '{insets["bottom"]}px');
                r.setProperty('--safe-left', '{insets["left"]}px');
            }});
            """
        )
        page = ctx.new_page()
        errors = []
        page.on("pageerror", lambda exc: errors.append(str(exc)))
        # Route .part0 with small delay only until we snapshot loading shell metrics
        hold = threading.Event()

        def slow_part(route):
            hold.wait(timeout=2.0)
            route.continue_()

        page.route("**/index.pck.gz.part0*", slow_part)
        page.goto(base_url, wait_until="domcontentloaded")
        page.wait_for_selector("#status", timeout=5000)
        metrics = page.evaluate(
            """() => {
                const safe = JSON.parse(window.__abyssalGetSafeInsetsJson());
                const status = document.getElementById('status');
                const fsBtn = document.getElementById('abyssal-fullscreen-btn');
                const fsRect = fsBtn ? fsBtn.getBoundingClientRect() : null;
                const statusHtml = status ? status.innerText : '';
                const selectors = ['.astrolabe-stage, .astrolabe-wrap, .astrolabe', '.title-cn, h1', '.progress-track, .bar-track', '.horizon-ruler'];
                const boxes = [];
                for (const sel of selectors) {
                    const el = document.querySelector(sel);
                    if (el) {
                        const r = el.getBoundingClientRect();
                        boxes.push({ sel, left: r.left, top: r.top, right: r.right, bottom: r.bottom, width: r.width, height: r.height });
                    }
                }
                const canvas = document.getElementById('canvas');
                const ctxLostOverlay = document.getElementById('abyssal-context-lost');
                let ctxLostPrevented = false;
                let ctxLostShown = false;
                let ctxLostRestored = false;
                if (canvas && ctxLostOverlay) {
                    const lostEv = new Event('webglcontextlost', { cancelable: true });
                    canvas.dispatchEvent(lostEv);
                    ctxLostPrevented = lostEv.defaultPrevented;
                    ctxLostShown = ctxLostOverlay.classList.contains('is-visible');
                    canvas.dispatchEvent(new Event('webglcontextrestored'));
                    ctxLostRestored = !ctxLostOverlay.classList.contains('is-visible');
                }
                return {
                    safe,
                    fsRect,
                    statusHtml,
                    boxes,
                    vw: window.innerWidth,
                    vh: window.innerHeight,
                    ctxLostPrevented,
                    ctxLostShown,
                    ctxLostRestored,
                };
            }"""
        )
        hold.set()
        assert not errors, f"[{label}] JS page errors during shell boot: {errors}"
        safe = metrics["safe"]
        assert safe["coarsePointer"] is True, f"[{label}] coarsePointer should be True"
        assert safe["top"] == insets["top"] and safe["left"] == insets["left"], f"[{label}] Safe insets mismatch: {safe}"
        assert isinstance(safe.get("canvasWidth"), (int, float)) and safe["canvasWidth"] > 0, (
            f"[{label}] __abyssalGetSafeInsetsJson missing valid canvasWidth: {safe}"
        )
        assert isinstance(safe.get("canvasHeight"), (int, float)) and safe["canvasHeight"] > 0, (
            f"[{label}] __abyssalGetSafeInsetsJson missing valid canvasHeight: {safe}"
        )
        assert metrics["ctxLostPrevented"] is True and metrics["ctxLostShown"] is True and metrics["ctxLostRestored"] is True, (
            f"[{label}] #canvas webglcontextlost recovery overlay check failed: {metrics}"
        )
        assert "N 键" not in metrics["statusHtml"], f"[{label}] Keyboard-only N-key copy leaked onto touch loading screen"
        if metrics["fsRect"] and metrics["fsRect"]["width"] > 0:
            assert metrics["fsRect"]["width"] >= 43.5 and metrics["fsRect"]["height"] >= 43.5, (
                f"[{label}] Fullscreen button < 44px: {metrics['fsRect']}"
            )
        for box in metrics["boxes"]:
            assert box["left"] >= -1.5 and box["top"] >= -1.5, f"[{label}] Element {box['sel']} clipped top/left: {box}"
            assert box["right"] <= w + 1.5 and box["bottom"] <= h + 1.5, (
                f"[{label}] Element {box['sel']} overflows {w}x{h}: {box}"
            )
        ctx.close()
        print(f"[verify_mobile_web] Shell layout & safe bridge PASS: {label} ({w}x{h} @{dpr}x)")


def verify_live_engine_mobile(browser, base_url: str) -> None:
    for label, w, h, insets in [
        ("live_portrait_390x844", 390, 844, {"top": 59, "right": 0, "bottom": 34, "left": 0}),
        ("live_landscape_844x390", 844, 390, {"top": 0, "right": 59, "bottom": 21, "left": 59}),
    ]:
        ctx = browser.new_context(
            viewport={"width": w, "height": h},
            device_scale_factor=3,
            is_mobile=True,
            has_touch=True,
        )
        ctx.add_init_script(f"window.__abyssalMockSafeInsets = {json.dumps(insets)};")
        page = ctx.new_page()
        errors = []
        page.on("pageerror", lambda exc: errors.append(str(exc)))
        page.goto(base_url, wait_until="domcontentloaded")
        page.wait_for_function("() => window.__abyssalGameReady === true", timeout=60000)
        time.sleep(0.8)

        state = page.evaluate(
            """() => ({
                gameReady: Boolean(window.__abyssalGameReady),
                hasPageHiddenHook: typeof window.__abyssalOnPageHidden === 'function',
                canvasW: document.getElementById('canvas').width,
                canvasH: document.getElementById('canvas').height,
            })"""
        )
        assert not errors, f"[{label}] Runtime WebGL/WASM errors: {errors}"
        assert state["gameReady"] is True, f"[{label}] Game did not reach ready state"
        assert state["hasPageHiddenHook"] is True, f"[{label}] Godot did not register __abyssalOnPageHidden auto-save hook"
        assert state["canvasW"] > 0 and state["canvasH"] > 0, f"[{label}] Invalid canvas dimensions: {state}"

        # Verify live rendered pixels are non-blank
        png_bytes = page.screenshot(type="png")
        img = Image.open(io.BytesIO(png_bytes)).convert("RGB")
        stddev = max(ImageStat.Stat(img).stddev)
        assert stddev > 5.0, f"[{label}] Rendered canvas appears blank (stddev={stddev:.2f})"

        # Simulate touch tap & drag on 3D title showcase + pagehidden hook invocation
        page.touchscreen.tap(w * 0.5, h * 0.45)
        time.sleep(0.2)
        page.evaluate("() => { if (window.__abyssalOnPageHidden) window.__abyssalOnPageHidden(); }")
        assert not errors, f"[{label}] Errors after touch interaction & pagehide auto-save hook: {errors}"
        ctx.close()
        print(f"[verify_mobile_web] Live WebGL2 engine + touch + auto-save hook PASS: {label} (canvas={state['canvasW']}x{state['canvasH']}, stddev={stddev:.1f})")


def main() -> None:
    verify_pwa_artifacts()
    with local_server(WEB_DIR) as url, sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=CHROME_ARGS)
        try:
            verify_shell_matrix(browser, url)
            verify_live_engine_mobile(browser, url)
        finally:
            browser.close()
    print("MOBILE_WEB_E2E_OK")


if __name__ == "__main__":
    main()
