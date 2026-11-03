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
			const res = await env.ASSETS.fetch(
				new Request(partUrl.toString(), {
					method: "GET",
					headers: { "Accept-Encoding": "identity" },
				})
			);
			if (!res.ok) {
				controller.error(new Error(`Missing asset chunk: ${partUrl.pathname}`));
				return;
			}
			const buf = new Uint8Array(await res.arrayBuffer());
			controller.enqueue(buf);
		},
	});
}

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
					const body = streamPartsFromAssets(entry.parts, request, env);
					const headers = new Headers(ISOLATION_HEADERS);
					headers.set("Content-Type", key.endsWith(".wasm") ? "application/wasm" : "application/octet-stream");
					headers.set("Content-Encoding", "gzip");
					headers.set("Cache-Control", "public, max-age=31536000, immutable");
					return new Response(body, {
						status: 200,
						headers,
						encodeBody: "manual",
					});
				}
			}
		}

		const assetRes = await env.ASSETS.fetch(request);
		return withIsolationHeaders(assetRes);
	},
};
