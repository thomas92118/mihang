import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const blake3Wasm = require("C:\\Users\\feimaojia\\AppData\\Local\\npm-cache\\_npx\\32026684e21afda6\\node_modules\\blake3-wasm");
const WRANGLER_BIN = "C:\\Users\\feimaojia\\AppData\\Local\\npm-cache\\_npx\\32026684e21afda6\\node_modules\\wrangler\\bin\\wrangler.js";

const WEB_DIR = path.resolve("build/web");
const SCRIPT_NAME = "abyssal-echo";
const CONCURRENCY = 6;

function getTempTomlPath() {
	return path.join(
		process.env.APPDATA || "",
		"xdg.config",
		".wrangler",
		"wrangler-temporary-account.toml"
	);
}

function bootstrapTemporaryAccount() {
	console.log("[upload_assets] Bootstrapping fresh Cloudflare temporary preview account...");
	const tomlPath = getTempTomlPath();
	if (fs.existsSync(tomlPath)) {
		fs.unlinkSync(tomlPath);
	}
	const assetsIgnorePath = path.join(WEB_DIR, ".assetsignore");
	fs.writeFileSync(assetsIgnorePath, "*.part*\n", "utf8");
	try {
		const res = spawnSync(
			process.execPath,
			[WRANGLER_BIN, "deploy", "--temporary"],
			{
				stdio: "inherit",
				env: { ...process.env, WRANGLER_SEND_METRICS: "false" },
			}
		);
		if (res.status !== 0) {
			throw new Error(`wrangler deploy --temporary failed with code ${res.status}`);
		}
	} finally {
		if (fs.existsSync(assetsIgnorePath)) {
			fs.unlinkSync(assetsIgnorePath);
		}
	}
}

function loadTemporaryAccount() {
	const tomlPath = getTempTomlPath();
	if (!fs.existsSync(tomlPath)) {
		bootstrapTemporaryAccount();
	}
	const toml = fs.readFileSync(tomlPath, "utf8");
	const accountId = toml.match(/^id\s*=\s*"([^"]+)"/m)?.[1];
	const apiToken = toml.match(/^apiToken\s*=\s*"([^"]+)"/m)?.[1];
	if (!accountId || !apiToken) {
		throw new Error("Missing id or apiToken in wrangler-temporary-account.toml");
	}
	return { accountId, apiToken };
}

function getContentType(filePath) {
	if (filePath.endsWith(".html")) return "text/html";
	if (filePath.endsWith(".js")) return "application/javascript";
	if (filePath.endsWith(".json")) return "application/json";
	if (filePath.endsWith(".png")) return "image/png";
	if (filePath.endsWith(".wasm")) return "application/wasm";
	return "application/octet-stream";
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function uploadSingleFile(accountId, apiToken, entry, index, total) {
	for (let attempt = 1; attempt <= 5; attempt++) {
		const t0 = Date.now();
		try {
			const sessRes = await fetch(
				`https://api.cloudflare.com/client/v4/accounts/${accountId}/workers/scripts/${SCRIPT_NAME}/assets-upload-session`,
				{
					method: "POST",
					headers: {
						Authorization: `Bearer ${apiToken}`,
						"Content-Type": "application/json",
					},
					body: JSON.stringify({
						manifest: {
							[entry.key]: { hash: entry.hash, size: entry.size },
						},
					}),
				}
			);
			const sessJson = await sessRes.json();
			if (!sessJson.success) {
				throw new Error(`session API error: ${JSON.stringify(sessJson.errors)}`);
			}
			const buckets = sessJson.result.buckets.flat();
			if (buckets.length === 0) {
				console.log(`[${index}/${total}] [skip] ${entry.file} (already uploaded)`);
				return;
			}
			const jwt = sessJson.result.jwt;
			const form = new FormData();
			form.append(
				entry.hash,
				new File([entry.base64], entry.hash, { type: entry.contentType }),
				entry.hash
			);

			const upRes = await fetch(
				`https://api.cloudflare.com/client/v4/accounts/${accountId}/workers/assets/upload?base64=true`,
				{
					method: "POST",
					headers: {
						Authorization: `Bearer ${jwt}`,
					},
					body: form,
				}
			);
			const upJson = await upRes.json();
			if (!upJson.success) {
				throw new Error(`upload API error: ${JSON.stringify(upJson.errors)}`);
			}
			const dt = ((Date.now() - t0) / 1000).toFixed(1);
			console.log(
				`[${index}/${total}] [ok] ${entry.file} (${(entry.size / 1024).toFixed(0)} KiB) in ${dt}s`
			);
			return;
		} catch (err) {
			console.log(
				`[${index}/${total}] [retry ${attempt}/5] ${entry.file}: ${err.message}`
			);
			if (attempt === 5) throw err;
			await sleep(2000 * attempt);
		}
	}
}

async function main() {
	let { accountId, apiToken } = loadTemporaryAccount();
	const assetsIgnorePath = path.join(WEB_DIR, ".assetsignore");
	if (fs.existsSync(assetsIgnorePath)) {
		fs.unlinkSync(assetsIgnorePath);
	}

	const files = fs
		.readdirSync(WEB_DIR)
		.filter((f) => f !== "_headers" && f !== "_redirects" && !f.startsWith("."));

	const entries = [];
	const fullManifest = {};
	for (const file of files) {
		const fullPath = path.join(WEB_DIR, file);
		const stat = fs.statSync(fullPath);
		if (!stat.isFile()) continue;
		const contents = fs.readFileSync(fullPath);
		const base64 = contents.toString("base64");
		const ext = path.extname(fullPath).substring(1);
		const hash = blake3Wasm.hash(base64 + ext).toString("hex").slice(0, 32);
		const key = "/" + file;
		fullManifest[key] = { hash, size: stat.size };
		entries.push({
			key,
			file,
			size: stat.size,
			hash,
			base64,
			contentType: getContentType(file),
		});
	}

	let initRes = await fetch(
		`https://api.cloudflare.com/client/v4/accounts/${accountId}/workers/scripts/${SCRIPT_NAME}/assets-upload-session`,
		{
			method: "POST",
			headers: {
				Authorization: `Bearer ${apiToken}`,
				"Content-Type": "application/json",
			},
			body: JSON.stringify({ manifest: fullManifest }),
		}
	);
	let initJson = await initRes.json();
	if (!initJson.success && initJson.errors?.some((e) => e.code === 10000)) {
		bootstrapTemporaryAccount();
		({ accountId, apiToken } = loadTemporaryAccount());
		initRes = await fetch(
			`https://api.cloudflare.com/client/v4/accounts/${accountId}/workers/scripts/${SCRIPT_NAME}/assets-upload-session`,
			{
				method: "POST",
				headers: {
					Authorization: `Bearer ${apiToken}`,
					"Content-Type": "application/json",
				},
				body: JSON.stringify({ manifest: fullManifest }),
			}
		);
		initJson = await initRes.json();
	}
	if (!initJson.success) {
		throw new Error(`Initial session error: ${JSON.stringify(initJson.errors)}`);
	}
	const neededHashes = new Set(initJson.result.buckets.flat());
	const todo = entries.filter((e) => neededHashes.has(e.hash));
	console.log(
		`[upload_assets] Total assets: ${entries.length}, already uploaded: ${
			entries.length - todo.length
		}, remaining: ${todo.length}`
	);

	let cursor = 0;
	async function worker(workerId) {
		await sleep(workerId * 600);
		while (cursor < todo.length) {
			const idx = cursor++;
			const item = todo[idx];
			await uploadSingleFile(accountId, apiToken, item, idx + 1, todo.length);
		}
	}

	await Promise.all(
		Array.from({ length: Math.min(CONCURRENCY, todo.length) }, (_, i) => worker(i))
	);
	console.log("[upload_assets] All static assets uploaded successfully!");
}

main().catch((err) => {
	console.error("[upload_assets] Fatal:", err);
	process.exit(1);
});
