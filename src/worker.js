const ISOLATION_HEADERS = {
	"Cross-Origin-Opener-Policy": "same-origin",
	"Cross-Origin-Embedder-Policy": "require-corp",
	"Cross-Origin-Resource-Policy": "same-origin",
};

function withIsolationHeaders(response, extraHeaders = {}) {
	const headers = new Headers(response.headers);
	for (const [k, v] of Object.entries(ISOLATION_HEADERS)) {
		headers.set(k, v);
	}
	for (const [k, v] of Object.entries(extraHeaders)) {
		headers.set(k, v);
	}
	return new Response(response.body, {
		status: response.status,
		statusText: response.statusText,
		headers,
	});
}

function streamPartsFromAssets(parts, request, env) {
	const origin = new URL(request.url).origin;
	let idx = 0;
	return new ReadableStream({
		async pull(controller) {
			if (idx >= parts.length) {
				controller.close();
				return;
			}
			const partUrl = new URL("/" + parts[idx++], origin);
			let res = null;
			for (let attempt = 0; attempt < 3; attempt++) {
				res = await env.ASSETS.fetch(
					new Request(partUrl.toString(), {
						method: "GET",
						headers: { "Accept-Encoding": "identity" },
					})
				);
				if (res.ok) break;
			}
			if (!res || !res.ok) {
				controller.error(new Error(`Missing asset chunk: ${partUrl.pathname}`));
				return;
			}
			const buf = new Uint8Array(await res.arrayBuffer());
			controller.enqueue(buf);
		},
	});
}

const NO_CACHE_SUFFIXES = [
	"/",
	"/index.html",
	"/index.js",
	"/chunks.json",
	"/index.service.worker.js",
	"/index.manifest.json",
];

export default {
	async fetch(request, env) {
		const url = new URL(request.url);

		if (url.pathname.endsWith("/index.wasm") || url.pathname.endsWith("/index.pck")) {
			const key = url.pathname.endsWith("/index.wasm") ? "index.wasm" : "index.pck";
			const manifestRes = await env.ASSETS.fetch(new Request(new URL("/chunks.json", url.origin).toString()));
			if (manifestRes.ok) {
				const manifest = await manifestRes.json();
				const entry = manifest[key];
				if (entry && Array.isArray(entry.parts)) {
					const etag = entry.hash ? `"${entry.hash}"` : null;
					if (etag && request.headers.get("If-None-Match") === etag) {
						const notModHeaders = new Headers(ISOLATION_HEADERS);
						notModHeaders.set("ETag", etag);
						notModHeaders.set("Cache-Control", "public, max-age=0, must-revalidate");
						return new Response(null, { status: 304, headers: notModHeaders });
					}
					const body = streamPartsFromAssets(entry.parts, request, env);
					const headers = new Headers(ISOLATION_HEADERS);
					headers.set("Content-Type", key.endsWith(".wasm") ? "application/wasm" : "application/octet-stream");
					headers.set("Content-Encoding", "gzip");
					headers.set("Cache-Control", "public, max-age=0, must-revalidate");
					if (etag) {
						headers.set("ETag", etag);
					}
					return new Response(body, {
						status: 200,
						headers,
						encodeBody: "manual",
					});
				}
			}
		}

		const assetRes = await env.ASSETS.fetch(request);
		const extraHeaders = {};
		if (url.pathname.includes(".part")) {
			extraHeaders["Cache-Control"] = "public, max-age=31536000, immutable";
		} else if (NO_CACHE_SUFFIXES.some((suffix) => url.pathname === suffix || url.pathname.endsWith(suffix))) {
			extraHeaders["Cache-Control"] = "no-cache";
		}
		return withIsolationHeaders(assetRes, extraHeaders);
	},
};
