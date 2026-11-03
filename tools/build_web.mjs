import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import zlib from "node:zlib";

const ROOT = process.cwd();
const WEB_DIR = path.join(ROOT, "build", "web");
const CHUNK_SIZE_BYTES = 512 * 1024; // 512 KiB chunks for fast parallel upload & download
const MAX_CF_ASSET_BYTES = 5 * 1024 * 1024;

function findGodotBinary() {
	const candidates = [];
	const localAppData = process.env.LOCALAPPDATA || "";
	const wingetRoot = path.join(localAppData, "Microsoft", "WinGet", "Packages");
	if (fs.existsSync(wingetRoot)) {
		for (const dir of fs.readdirSync(wingetRoot)) {
			if (dir.startsWith("GodotEngine.GodotEngine")) {
				const fullDir = path.join(wingetRoot, dir);
				for (const file of fs.readdirSync(fullDir)) {
					if (/^Godot.*console\.exe$/i.test(file)) {
						candidates.unshift(path.join(fullDir, file));
					} else if (/^Godot.*\.exe$/i.test(file)) {
						candidates.push(path.join(fullDir, file));
					}
				}
			}
		}
	}
	if (candidates.length > 0) {
		return candidates[0];
	}
	return "godot";
}

function ensureLossyModelTextures() {
	const modelsDir = path.join(ROOT, "assets", "models");
	if (!fs.existsSync(modelsDir)) return;
	let updated = 0;
	for (const name of fs.readdirSync(modelsDir)) {
		if (!name.endsWith(".png.import")) continue;
		const fullPath = path.join(modelsDir, name);
		let content = fs.readFileSync(fullPath, "utf8");
		const next = content
			.replace("compress/mode=0", "compress/mode=1")
			.replace("mipmaps/generate=true", "mipmaps/generate=false")
			.replace("process/size_limit=0", "process/size_limit=512");
		if (next !== content) {
			fs.writeFileSync(fullPath, next, "utf8");
			updated++;
		}
	}
	if (updated > 0) {
		console.log(`[build_web] Optimized ${updated} model texture imports (lossy WebP, 512px)`);
	}
}

function exportGodotWeb(godotBin) {
	fs.mkdirSync(WEB_DIR, { recursive: true });
	fs.writeFileSync(path.join(ROOT, "build", ".gdignore"), "");

	console.log(`[build_web] Exporting Godot Web build using: ${godotBin}`);
	const res = spawnSync(
		godotBin,
		["--headless", "--path", ".", "--export-release", "Web", "build/web/index.html"],
		{ cwd: ROOT, stdio: "inherit" }
	);
	if (res.status !== 0) {
		throw new Error(`Godot Web export failed with code ${res.status}`);
	}
}

function compressAndChunkFile(fileName) {
	const filePath = path.join(WEB_DIR, fileName);
	if (!fs.existsSync(filePath)) {
		throw new Error(`Expected file missing: ${filePath}`);
	}
	const raw = fs.readFileSync(filePath);
	console.log(`[build_web] Gzipping ${fileName} (${(raw.length / 1048576).toFixed(2)} MB)...`);
	const gz = zlib.gzipSync(raw, { level: 9 });
	fs.unlinkSync(filePath);

	const parts = [];
	for (let offset = 0, idx = 0; offset < gz.length; offset += CHUNK_SIZE_BYTES, idx++) {
		const chunk = gz.subarray(offset, Math.min(offset + CHUNK_SIZE_BYTES, gz.length));
		const partName = `${fileName}.gz.part${idx}`;
		fs.writeFileSync(path.join(WEB_DIR, partName), chunk);
		parts.push(partName);
	}
	console.log(
		`[build_web] Split ${fileName}.gz (${(gz.length / 1048576).toFixed(2)} MB) into ${parts.length} chunks (<= 512 KiB each)`
	);
	return {
		rawSize: raw.length,
		gzSize: gz.length,
		parts,
	};
}

function postProcessWebBuild() {
	for (const file of fs.readdirSync(WEB_DIR)) {
		if (file.endsWith(".import") || file.includes(".gz")) {
			fs.unlinkSync(path.join(WEB_DIR, file));
		}
	}

	const manifest = {
		"index.wasm": compressAndChunkFile("index.wasm"),
		"index.pck": compressAndChunkFile("index.pck"),
	};
	fs.writeFileSync(path.join(WEB_DIR, "chunks.json"), JSON.stringify(manifest, null, 2), "utf8");

	const htmlPath = path.join(WEB_DIR, "index.html");
	let html = fs.readFileSync(htmlPath, "utf8");
	const fetchShim = `<script>
(function () {
	const CHUNK_MANIFEST = ${JSON.stringify(manifest)};
	const origFetch = window.fetch.bind(window);

	function createChunkedGzStream(parts, init) {
		let nextFetch = 0;
		let nextEmit = 0;
		const CONCURRENCY = 6;
		const inflight = new Map();

		function pump() {
			while (nextFetch < parts.length && inflight.size < CONCURRENCY) {
				const idx = nextFetch++;
				const partUrl = parts[idx];
				const p = origFetch(partUrl, init).then(async function (res) {
					if (!res.ok) {
						throw new Error('Failed loading chunk ' + partUrl + ' (' + res.status + ')');
					}
					return new Uint8Array(await res.arrayBuffer());
				});
				inflight.set(idx, p);
			}
		}

		return new ReadableStream({
			async pull(controller) {
				if (nextEmit >= parts.length) {
					controller.close();
					return;
				}
				pump();
				const promise = inflight.get(nextEmit);
				inflight.delete(nextEmit);
				nextEmit++;
				pump();
				const buf = await promise;
				controller.enqueue(buf);
			}
		});
	}

	window.fetch = async function (input, init) {
		const url = typeof input === 'string' ? input : (input && input.url) || '';
		for (const key of Object.keys(CHUNK_MANIFEST)) {
			if (url === key || url.endsWith('/' + key)) {
				const prefix = url.slice(0, url.length - key.length);
				const parts = CHUNK_MANIFEST[key].parts.map(p => prefix + p);
				const gzStream = createChunkedGzStream(parts, init);
				const stream = gzStream.pipeThrough(new DecompressionStream('gzip'));
				const contentType = key.endsWith('.wasm') ? 'application/wasm' : 'application/octet-stream';
				return new Response(stream, {
					status: 200,
					headers: {
						'Content-Type': contentType,
						'Content-Length': String(CHUNK_MANIFEST[key].rawSize),
					},
				});
			}
		}
		return origFetch(input, init);
	};
})();
</script>`;

	if (!html.includes("CHUNK_MANIFEST")) {
		html = html.replace('<script src="index.js"></script>', `${fetchShim}\n\t\t<script src="index.js"></script>`);
		fs.writeFileSync(htmlPath, html, "utf8");
	}

	const headersContent = [
		"/*",
		"  Cross-Origin-Opener-Policy: same-origin",
		"  Cross-Origin-Embedder-Policy: require-corp",
		"  Cross-Origin-Resource-Policy: same-origin",
		"",
		"/*.wasm",
		"  Content-Type: application/wasm",
		"  Cache-Control: public, max-age=31536000, immutable",
		"",
		"/*.part*",
		"  Content-Type: application/octet-stream",
		"  Cache-Control: public, max-age=31536000, immutable",
		"",
		"/*.pck",
		"  Content-Type: application/octet-stream",
		"  Cache-Control: public, max-age=31536000, immutable",
		"",
	].join("\n");
	fs.writeFileSync(path.join(WEB_DIR, "_headers"), headersContent, "utf8");

	console.log("\n[build_web] Final build/web assets:");
	for (const file of fs.readdirSync(WEB_DIR)) {
		const fullPath = path.join(WEB_DIR, file);
		const stat = fs.statSync(fullPath);
		if (!stat.isFile()) continue;
		const mb = (stat.size / 1048576).toFixed(2);
		console.log(`  - ${file}: ${mb} MB (${stat.size} bytes)`);
		if (stat.size > MAX_CF_ASSET_BYTES) {
			throw new Error(`Asset ${file} (${mb} MB) exceeds Cloudflare Workers 25 MiB limit!`);
		}
	}
}

const godotBin = findGodotBinary();
ensureLossyModelTextures();
exportGodotWeb(godotBin);
postProcessWebBuild();
