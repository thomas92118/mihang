import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

function resolveWranglerDeps() {
	try {
		const pkgPath = require.resolve("wrangler/package.json");
		const wranglerReq = createRequire(pkgPath);
		return {
			wranglerBin: path.join(path.dirname(pkgPath), "bin", "wrangler.js"),
			blake3Wasm: wranglerReq("blake3-wasm"),
		};
	} catch {
		throw new Error(
			'Cannot find local "wrangler" package. Please run "npm install" first.'
		);
	}
}

const { wranglerBin: WRANGLER_BIN, blake3Wasm } = resolveWranglerDeps();

const WEB_DIR = path.resolve("build/web");
const WRANGLER_TOML_PATH = path.resolve("wrangler.toml");
const CONCURRENCY = 6;
const USE_TEMPORARY = process.argv.includes("--temporary");

function readWranglerToml() {
	if (!fs.existsSync(WRANGLER_TOML_PATH)) return "";
	return fs.readFileSync(WRANGLER_TOML_PATH, "utf8");
}

function resolveScriptName() {
	const toml = readWranglerToml();
	return toml.match(/^name\s*=\s*"([^"]+)"/m)?.[1] || "abyssal-echo";
}

const SCRIPT_NAME = resolveScriptName();

function getWranglerConfigDir() {
	const legacyDir = path.join(os.homedir(), ".wrangler");
	if (fs.existsSync(legacyDir) && fs.statSync(legacyDir).isDirectory()) {
		return legacyDir;
	}
	if (process.env.XDG_CONFIG_HOME) {
		return path.join(process.env.XDG_CONFIG_HOME, ".wrangler");
	}
	if (process.platform === "win32") {
		return path.join(
			process.env.APPDATA || path.join(os.homedir(), "AppData", "Roaming"),
			"xdg.config",
			".wrangler"
		);
	}
	if (process.platform === "darwin") {
		return path.join(os.homedir(), "Library", "Preferences", ".wrangler");
	}
	return path.join(os.homedir(), ".config", ".wrangler");
}

function getTempTomlPath() {
	return path.join(getWranglerConfigDir(), "wrangler-temporary-account.toml");
}

function bootstrapWorker(extraArgs = [], resetTempAccount = false) {
	if (resetTempAccount) {
		console.log("[upload_assets] Bootstrapping fresh Cloudflare temporary preview account...");
		const tomlPath = getTempTomlPath();
		if (fs.existsSync(tomlPath)) {
			fs.unlinkSync(tomlPath);
		}
	} else {
		console.log(`[upload_assets] Bootstrapping Worker "${SCRIPT_NAME}" before chunk upload...`);
	}
	const assetsIgnorePath = path.join(WEB_DIR, ".assetsignore");
	fs.writeFileSync(assetsIgnorePath, "*.part*\n", "utf8");
	try {
		const res = spawnSync(
			process.execPath,
			[WRANGLER_BIN, "deploy", ...extraArgs],
			{
				stdio: "inherit",
				env: { ...process.env, WRANGLER_SEND_METRICS: "false" },
			}
		);
		if (res.status !== 0) {
			throw new Error(`wrangler deploy ${extraArgs.join(" ")} failed with code ${res.status}`);
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
		bootstrapWorker(["--temporary"], true);
	}
	const toml = fs.readFileSync(tomlPath, "utf8");
	const accountId = toml.match(/^id\s*=\s*"([^"]+)"/m)?.[1];
	const apiToken = toml.match(/^apiToken\s*=\s*"([^"]+)"/m)?.[1];
	if (!accountId || !apiToken) {
		throw new Error("Missing id or apiToken in wrangler-temporary-account.toml");
	}
	return { accountId, apiToken };
}

async function loadPermanentAccount() {
	let apiToken = process.env.CLOUDFLARE_API_TOKEN || "";
	if (!apiToken) {
		const defaultTomlPath = path.join(getWranglerConfigDir(), "config", "default.toml");
		if (!fs.existsSync(defaultTomlPath)) {
			throw new Error(
				'Not authenticated with Cloudflare. Run "npx wrangler login" first, or use "npm run deploy:preview" for temporary preview deployment.'
			);
		}
		let toml = fs.readFileSync(defaultTomlPath, "utf8");
		const expStr = toml.match(/^expiration_time\s*=\s*"([^"]+)"/m)?.[1];
		if (expStr && Date.parse(expStr) - Date.now() < 120_000) {
			spawnSync(process.execPath, [WRANGLER_BIN, "whoami"], {
				stdio: "inherit",
				env: { ...process.env, WRANGLER_SEND_METRICS: "false" },
			});
			toml = fs.readFileSync(defaultTomlPath, "utf8");
		}
		apiToken =
			toml.match(/^oauth_token\s*=\s*"([^"]+)"/m)?.[1] ||
			toml.match(/^api_token\s*=\s*"([^"]+)"/m)?.[1] ||
			"";
	}
	if (!apiToken) {
		throw new Error("Missing Cloudflare API/OAuth token. Please run `npx wrangler login`.");
	}

	const wranglerToml = readWranglerToml();
	let accountId =
		process.env.CLOUDFLARE_ACCOUNT_ID ||
		wranglerToml.match(/^account_id\s*=\s*"([^"]+)"/m)?.[1] ||
		"";

	if (!accountId) {
		const cachedAccountPath = path.resolve("node_modules/.cache/wrangler/wrangler-account.json");
		if (fs.existsSync(cachedAccountPath)) {
			try {
				const cached = JSON.parse(fs.readFileSync(cachedAccountPath, "utf8"));
				if (cached?.account?.id) {
					accountId = cached.account.id;
					console.log(
						`[upload_assets] Using cached Wrangler Cloudflare account: ${cached.account.name || "default"} (${accountId})`
					);
				}
			} catch {
				// Fall back to Cloudflare accounts API below.
			}
		}
	}

	if (!accountId) {
		const accRes = await fetch("https://api.cloudflare.com/client/v4/accounts", {
			headers: { Authorization: `Bearer ${apiToken}` },
		});
		const accJson = await accRes.json();
		if (!accJson.success || !Array.isArray(accJson.result) || accJson.result.length === 0) {
			throw new Error(`Unable to resolve Cloudflare account ID: ${JSON.stringify(accJson.errors)}`);
		}
		accountId = accJson.result[0].id;
		console.log(`[upload_assets] Using Cloudflare account: ${accJson.result[0].name} (${accountId})`);
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
	let { accountId, apiToken } = USE_TEMPORARY
		? loadTemporaryAccount()
		: await loadPermanentAccount();
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
	if (!initJson.success && initJson.errors?.some((e) => e.code === 10000 || e.code === 10007)) {
		if (USE_TEMPORARY) {
			bootstrapWorker(["--temporary"], true);
			({ accountId, apiToken } = loadTemporaryAccount());
		} else {
			bootstrapWorker([], false);
			({ accountId, apiToken } = await loadPermanentAccount());
		}
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
