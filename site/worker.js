// The website's Cloudflare Worker (lunarc-site). tools/make-site replaces the
// import below with the built files and writes the result to site/dist/worker.js,
// one self-contained module: deploy that file, not this one (site/README.md).
import { FILES, ROUTES } from "./files.js";

const SECURITY_HEADERS = {
  "content-security-policy":
    "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; font-src 'self'; " +
    "connect-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
  "strict-transport-security": "max-age=63072000; includeSubDomains",
  "x-content-type-options": "nosniff",
  "referrer-policy": "no-referrer",
  "permissions-policy":
    "accelerometer=(), browsing-topics=(), camera=(), display-capture=(), geolocation=(), gyroscope=(), " +
    "magnetometer=(), microphone=(), midi=(), payment=(), usb=()",
  "x-frame-options": "DENY",
  "cross-origin-opener-policy": "same-origin",
  "cross-origin-resource-policy": "same-origin",
};

// Old or alternative addresses.
const REDIRECTS = {
  "/index": "/",
  "/downloads": "/download",
  "/manual": "/docs",
  "/privacy": "/docs/privacy",
  "/docs/getting-started": "/docs/installing",
};

const decoded = new Map();

function body(path, file) {
  if (file.s !== undefined) return file.s;
  let bytes = decoded.get(path);
  if (!bytes) {
    const bin = atob(file.b);
    bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    decoded.set(path, bytes);
  }
  return bytes;
}

function redirect(location, status = 301) {
  return new Response(null, { status, headers: { location, ...SECURITY_HEADERS } });
}

function serve(request, path, status = 200) {
  const file = FILES[path];
  const headers = {
    "content-type": file.t,
    "cache-control": status === 200 ? file.c : "public, max-age=60",
    etag: file.e,
    ...SECURITY_HEADERS,
  };
  if (status === 200 && request.headers.get("if-none-match") === file.e) {
    return new Response(null, { status: 304, headers });
  }
  return new Response(request.method === "HEAD" ? null : body(path, file), { status, headers });
}

// One anonymous count per page view, in Cloudflare's Analytics Engine (the
// PAGEVIEWS binding; absent in the local preview, then nothing is counted):
// the page, the visitor's country (which Cloudflare already knows) and the
// referring site's domain. No address, no identifier, nothing in the browser.
function count(env, request, page) {
  if (!env || !env.PAGEVIEWS || request.method !== "GET") return;
  let from = "";
  try {
    const ref = new URL(request.headers.get("referer") || "");
    if (ref.hostname !== new URL(request.url).hostname) from = ref.hostname;
  } catch {}
  try {
    env.PAGEVIEWS.writeDataPoint({ indexes: [page], blobs: [page, (request.cf && request.cf.country) || "", from] });
  } catch {}
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.protocol === "http:" && url.hostname !== "localhost" && url.hostname !== "127.0.0.1") {
      url.protocol = "https:";
      return redirect(url.toString());
    }
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method not allowed\n", {
        status: 405,
        headers: { allow: "GET, HEAD", "content-type": "text/plain; charset=utf-8", ...SECURITY_HEADERS },
      });
    }

    let path = url.pathname;
    try {
      path = decodeURIComponent(path);
    } catch {
      return serve(request, ROUTES["/404"], 404);
    }
    // One address per page: no trailing slash, no .html, no index.html.
    let clean = path.replace(/\/index\.html$/, "/").replace(/\.html$/, "");
    if (clean.length > 1) clean = clean.replace(/\/+$/, "");
    if (REDIRECTS[clean]) return redirect(REDIRECTS[clean] + url.search);
    if (clean !== path && ROUTES[clean]) return redirect(clean + url.search);

    if (ROUTES[path] && path !== "/404") {
      count(env, request, path);
      return serve(request, ROUTES[path]);
    }
    if (FILES[path] && !path.endsWith(".html")) return serve(request, path);
    count(env, request, "/404");
    return serve(request, ROUTES["/404"], 404);
  },
};
