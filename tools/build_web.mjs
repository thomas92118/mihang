import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import zlib from "node:zlib";

const ROOT = process.cwd();
const TOOLS_DIR = path.join(ROOT, ".tools");
const STAGE_DIR = path.join(TOOLS_DIR, "web-build-stage");
const WEB_DIR = path.join(ROOT, "build", "web");
const CHUNK_SIZE_BYTES = 512 * 1024; // 512 KiB chunks for fast parallel upload & download
const MAX_CF_ASSET_BYTES = 5 * 1024 * 1024;

const STAGE_ROOT_FILES = [
	"project.godot",
	"export_presets.cfg",
	"icon.svg",
	"icon.svg.import",
];

const STAGE_DIRS = [
	"scenes",
	"scripts",
	"shaders",
	path.join("assets", "audio"),
	path.join("assets", "collision"),
	path.join("assets", "fonts"),
	path.join("assets", "models"),
];

function findGodotBinary() {
	if (process.env.GODOT_BIN && fs.existsSync(process.env.GODOT_BIN)) {
		return process.env.GODOT_BIN;
	}
	const macBundled = path.join(ROOT, ".tools", "Godot.app", "Contents", "MacOS", "Godot");
	if (fs.existsSync(macBundled)) {
		return macBundled;
	}
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

const SMALL_PROP_TEXTURE_PREFIXES = [
	"anemone_",
	"crab_",
	"fish_small_",
	"resource_copper_",
	"resource_kelp_",
	"resource_quartz_",
	"resource_titanium_",
	"sea_lily_",
	"starfish_urchin_",
	"tube_coral_",
	"tubeworms_",
];

function prepareStageProject(stageDir) {
	const resolvedTools = path.resolve(TOOLS_DIR);
	const resolvedStage = path.resolve(stageDir);
	if (!resolvedStage.startsWith(resolvedTools + path.sep)) {
		throw new Error(`Refusing to clean stage directory outside .tools: ${resolvedStage}`);
	}
	if (fs.existsSync(resolvedStage)) {
		fs.rmSync(resolvedStage, { recursive: true, force: true });
	}
	fs.mkdirSync(resolvedStage, { recursive: true });

	for (const relFile of STAGE_ROOT_FILES) {
		const src = path.join(ROOT, relFile);
		if (!fs.existsSync(src)) {
			if (relFile === "project.godot" || relFile === "export_presets.cfg") {
				throw new Error(`Required project file missing: ${src}`);
			}
			continue;
		}
		fs.copyFileSync(src, path.join(resolvedStage, relFile));
	}

	for (const relDir of STAGE_DIRS) {
		const src = path.join(ROOT, relDir);
		if (!fs.existsSync(src)) continue;
		const dst = path.join(resolvedStage, relDir);
		fs.mkdirSync(path.dirname(dst), { recursive: true });
		fs.cpSync(src, dst, { recursive: true });
	}
	const srcImported = path.join(ROOT, ".godot", "imported");
	if (fs.existsSync(srcImported)) {
		const dstImported = path.join(resolvedStage, ".godot", "imported");
		fs.mkdirSync(dstImported, { recursive: true });
		for (const entry of fs.readdirSync(srcImported)) {
			if (!entry.endsWith(".fontdata")) continue;
			fs.copyFileSync(path.join(srcImported, entry), path.join(dstImported, entry));
			const companionMd5 = `${entry.slice(0, -".fontdata".length)}.md5`;
			const srcMd5 = path.join(srcImported, companionMd5);
			if (fs.existsSync(srcMd5)) {
				fs.copyFileSync(srcMd5, path.join(dstImported, companionMd5));
			}
		}
	}
	console.log(`[build_web] Prepared isolated Web staging project at: ${resolvedStage}`);
}

function ensureExtractedGlbTextures(stageDir) {
	const modelsDir = path.join(stageDir, "assets", "models");
	if (!fs.existsSync(modelsDir)) return { glbImportsUpdated: 0, missingExtracts: false };

	const entries = fs.readdirSync(modelsDir);
	const allAssetIds = entries.filter((name) => name.endsWith(".glb")).map((name) => name.slice(0, -4));
	const pngImports = entries.filter((name) => name.endsWith(".png.import"));
	let glbImportsUpdated = 0;
	let missingExtracts = false;

	for (const name of entries) {
		if (name.endsWith(".glb")) {
			const assetId = name.slice(0, -4);
			const importName = `${name}.import`;
			if (!entries.includes(importName)) {
				missingExtracts = true;
			}
			const longerOverlaps = allAssetIds.filter(
				(otherId) => otherId.length > assetId.length && otherId.startsWith(`${assetId}_`)
			);
			const matchingPngImports = pngImports.filter((imp) => {
				if (!imp.startsWith(`${assetId}_`)) return false;
				return !longerOverlaps.some((otherId) => imp.startsWith(`${otherId}_`));
			});
			if (matchingPngImports.length < 4) {
				missingExtracts = true;
			}
		}
		if (!name.endsWith(".glb.import")) continue;
		const fullPath = path.join(modelsDir, name);
		const content = fs.readFileSync(fullPath, "utf8");
		let next = content;
		if (/^gltf\/embedded_image_handling=\d+/m.test(next)) {
			next = next.replace(/^gltf\/embedded_image_handling=\d+/m, "gltf/embedded_image_handling=1");
		} else if (next.includes("[params]")) {
			next = `${next.trimEnd()}\ngltf/embedded_image_handling=1\n`;
		}
		if (next !== content) {
			fs.writeFileSync(fullPath, next, "utf8");
			glbImportsUpdated++;
		}
	}
	return { glbImportsUpdated, missingExtracts };
}

function upsertImportParam(content, key, value) {
	const pattern = new RegExp(`^${key.replace(/[.*+?^${}()|[\\]\\\\]/g, "\\\\$&")}=.*$`, "m");
	if (pattern.test(content)) {
		return content.replace(pattern, `${key}=${value}`);
	}
	if (content.includes("[params]")) {
		return `${content.trimEnd()}\n${key}=${value}\n`;
	}
	return content;
}

function ensureLossyModelTextures(stageDir) {
	const modelsDir = path.join(stageDir, "assets", "models");
	if (!fs.existsSync(modelsDir)) return 0;
	let updated = 0;
	for (const name of fs.readdirSync(modelsDir)) {
		if (!name.endsWith(".png.import")) continue;
		const fullPath = path.join(modelsDir, name);
		let content = fs.readFileSync(fullPath, "utf8");
		const isSmallProp = SMALL_PROP_TEXTURE_PREFIXES.some((prefix) => name.startsWith(prefix));
		const targetLimit = isSmallProp ? "256" : "512";
		let next = content;
		next = upsertImportParam(next, "compress/mode", "1");
		next = upsertImportParam(next, "mipmaps/generate", "true");
		next = upsertImportParam(next, "process/size_limit", targetLimit);
		if (next !== content) {
			fs.writeFileSync(fullPath, next, "utf8");
			updated++;
		}
	}
	if (updated > 0) {
		console.log(
			`[build_web] Optimized ${updated} staged model texture imports in ${modelsDir} (lossy WebP + mipmaps, tiered 256/512px)`
		);
	}
	return updated;
}

function runGodotImport(godotBin, stageDir, reason) {
	console.log(`[build_web] Running Godot headless import in stage (${reason})...`);
	const res = spawnSync(godotBin, ["--headless", "--audio-driver", "Dummy", "--path", stageDir, "--import"], {
		cwd: stageDir,
		stdio: "inherit",
	});
	if (res.status !== 0) {
		throw new Error(`Godot headless import (${reason}) failed with code ${res.status}`);
	}
}

function exportGodotWeb(godotBin, stageDir) {
	fs.mkdirSync(WEB_DIR, { recursive: true });
	fs.writeFileSync(path.join(ROOT, "build", ".gdignore"), "");
	const outputHtml = path.join(WEB_DIR, "index.html");

	console.log(`[build_web] Exporting Godot Web build from stage using: ${godotBin}`);
	const res = spawnSync(
		godotBin,
		["--headless", "--audio-driver", "Dummy", "--path", stageDir, "--export-release", "Web", outputHtml],
		{ cwd: stageDir, stdio: "inherit" }
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
			throw new Error(`Asset ${file} (${mb} MB) exceeds Cloudflare Workers 5 MiB limit!`);
		}
	}
}

const godotBin = findGodotBinary();
prepareStageProject(STAGE_DIR);
ensureExtractedGlbTextures(STAGE_DIR);
ensureLossyModelTextures(STAGE_DIR);
runGodotImport(godotBin, STAGE_DIR, "baking 256/512px lossy Web textures");
if (ensureLossyModelTextures(STAGE_DIR) > 0) {
	runGodotImport(godotBin, STAGE_DIR, "re-baking newly extracted 256/512px Web textures");
}
exportGodotWeb(godotBin, STAGE_DIR);
postProcessWebBuild();
