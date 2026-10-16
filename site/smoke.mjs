// Checks the built site through dist/worker.js, as Cloudflare will run it:
// every page answers, redirects go where they should, an unknown address is
// a 404, and every response carries the security headers. Run by the site
// workflow after tools/make-site (needs Node.js 18 or newer).
import { pathToFileURL } from "node:url";
import path from "node:path";
import fs from "node:fs";

const dist = path.resolve(path.dirname(new URL(import.meta.url).pathname), "dist");
const worker = (await import(pathToFileURL(path.join(dist, "worker.js")).href)).default;
const docs = JSON.parse(fs.readFileSync(path.join(dist, "..", "src", "docs.json"), "utf8"));
const docPages = docs.pages.map((p) => `/docs/${p.slug}`);

let failed = 0;
const fail = (msg) => { console.log(`FAIL  ${msg}`); failed++; };
const get = (p, base = "https://example.test") => worker.fetch(new Request(base + p, { redirect: "manual" }));
const headers = ["content-security-policy", "strict-transport-security", "x-content-type-options", "referrer-policy"];

for (const p of ["/", "/download", "/docs", "/about", ...docPages]) {
  const r = await get(p);
  if (r.status !== 200) { fail(`${p} answered ${r.status}`); continue; }
  for (const h of headers) if (!r.headers.get(h)) fail(`${p} has no ${h}`);
  const body = await r.text();
  if (/https?:\/\/(?!lunarclinux\.com|downloads\.lunarclinux\.com|pkgs\.lunarclinux\.com|github\.com|archlinux\.org|www\.ventoy\.net|[a-z.]*fedoraproject\.org|gpg4win\.org)[a-z0-9.-]+\.[a-z]{2,}[^"'\s<]*\.(js|css|woff2?|png|jpg|webp|svg)/i.test(body))
    fail(`${p} loads something from another server`);
  console.log(`ok    ${p}`);
}
for (const [from, to] of [["/download/", "/download"], ["/download.html", "/download"], ["/index.html", "/"]]) {
  const r = await get(from);
  const loc = r.headers.get("location") || "";
  if (r.status !== 301 || !loc.endsWith(to)) fail(`${from} should redirect to ${to} (got ${r.status} ${loc})`);
  else console.log(`ok    ${from} → ${to}`);
}
const missing = await get("/no-such-page");
if (missing.status !== 404) fail(`an unknown page answered ${missing.status}`); else console.log("ok    404 for an unknown page");
const plain = await get("/", "http://example.test");
if (plain.status !== 301 || !(plain.headers.get("location") || "").startsWith("https://")) fail("http isn't redirected to https");
else console.log("ok    http → https");

if (failed) { console.log(`${failed} check(s) failed`); process.exit(1); }
console.log("all site checks passed");
