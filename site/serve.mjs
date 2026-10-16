// Local preview: serves site/dist through the built worker.js, so the routes,
// redirects and headers are the ones Cloudflare will send. Run by
// `tools/make-site --serve [port]` (needs Node.js 18 or newer). Listens on 127.0.0.1 only.
import http from "node:http";
import { pathToFileURL } from "node:url";
import path from "node:path";

const port = Number(process.argv[2] || 8080);
const dist = path.resolve(path.dirname(new URL(import.meta.url).pathname), "dist");
const worker = (await import(pathToFileURL(path.join(dist, "worker.js")).href)).default;

http.createServer(async (req, res) => {
  const request = new Request(`http://localhost:${port}${req.url}`, { method: req.method, headers: req.headers });
  const response = await worker.fetch(request);
  res.writeHead(response.status, Object.fromEntries(response.headers));
  res.end(response.body ? Buffer.from(await response.arrayBuffer()) : undefined);
  console.log(response.status, req.method, req.url);
}).listen(port, "127.0.0.1", () => console.log(`http://localhost:${port}`));
