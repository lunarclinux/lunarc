# Website

The public website, https://lunarclinux.com, served by a Cloudflare Worker named
`lunarc-site` (custom domain lunarclinux.com). Static pages, no framework, no
cookies, no analytics, no third-party requests.

## Layout

| Path | What |
|---|---|
| `releases.json` | The current ISO: channel, version, date, file, size, SHA-256, signature. The only file to change when a new ISO is published. |
| `src/layout.html` | The page frame (top bar, footer) shared by every page |
| `src/pages/` | Home, Download, About and 404 as HTML fragments; `pages.json` gives each one its address, title and description |
| `src/docs.json` | The docs pages: which parts of `docs/manual/*.md` make up each page, in order |
| `src/style.css` | The stylesheet: Frosted Terminal (`docs/design/frosted-terminal`) in Moonlit's dark and light colours |
| `src/site.js` | The only script: copy buttons on code blocks and the checksum |
| `src/fonts/` | Geist and Geist Mono (WOFF2) and their licence; `SOURCE.txt` records where they came from |
| `src/img/` | Screenshots (WebP, from the test VM) and the touch icon |
| `worker.js` | The Worker: routing, clean addresses, redirects, security headers |
| `serve.mjs` | Local preview through the built Worker (Node.js) |

Also used, straight from the repository: the hero backdrop is
`themes/moonlit/wallpapers/1-*.svg`, the icons come from `default/branding/`, and the
signing key and fingerprint from `pkg/keyring/`.

## Building and previewing

    tools/make-site                 # builds site/dist/
    tools/make-site --serve 8080    # builds, then serves it on http://localhost:8080

`tools/make-site` needs only Python 3 (standard library). It renders the manual's
Markdown itself (there's no Markdown package on a plain Arch install; the manual uses a
small subset), fills in the release details, gives CSS, JS, fonts and images
content-hashed names under `/a/` (cached for a year), and writes:

- `site/dist/`: every file as served, plus
- `site/dist/worker.js`: one Worker module with every file inside it.

`--serve` runs `serve.mjs` with Node.js, which answers through `dist/worker.js`, so
addresses, redirects and headers are the ones Cloudflare will send. Without Node it
falls back to `python -m http.server` (no headers; `/download` redirects to
`/download/`).

The build stops if a `##` section of a manual file used by sections, or any file in
`docs/manual/`, isn't on a docs page, so new manual text can't be left off the site:
add it to `src/docs.json`.

`site/dist/` is build output and isn't committed (`.gitignore`); build it right before
deploying.

## Publishing a new ISO

1. Sign it with the signing key (a detached binary signature next to the ISO):

       gpg --homedir ~/.local/share/lunarc-signing/gnupg \
           --local-user 798A81A89261BC4E49D0784BFD4EE07A81DE46AE \
           --detach-sign lunarc-YYYY.MM.DD-x86_64.iso

2. Upload `lunarc-YYYY.MM.DD-x86_64.iso` and its `.sig` to the R2 bucket behind
   `downloads.lunarclinux.com`.
3. `tools/make-site --set-release path/to/lunarc-YYYY.MM.DD-x86_64.iso` rewrites
   `releases.json` (size, SHA-256, date from the name; the channel stays). Commit it.
4. Build and deploy the site (below).

## Deploying

Everything is in one Worker script, `site/dist/worker.js`; the build prints its size
and stops above the Free plan's 3 MB (gzipped). Deploying is the same single upload as
for the old placeholder, with the built file:

    tools/make-site
    curl -X PUT -H "Authorization: Bearer $TOKEN" \
      -F 'metadata={"main_module":"worker.js","compatibility_date":"2026-10-01"};type=application/json' \
      -F 'worker.js=@site/dist/worker.js;filename=worker.js;type=application/javascript+module' \
      https://api.cloudflare.com/client/v4/accounts/<account id>/workers/scripts/lunarc-site

The token needs Workers Scripts edit. The custom domain stays attached; no bindings are
needed.

Why one script rather than Workers Static Assets: the whole site is small, a deploy is
one request that replaces everything at once (no half-uploaded state), the Worker sets
every header itself, and the local preview runs exactly the code that's deployed. If it
ever outgrows the size limit (mostly images), move the files to Static Assets:

1. `POST /accounts/<id>/workers/scripts/lunarc-site/assets-upload-session` with
   `{"manifest": {"/path": {"hash": "<32 hex chars, e.g. the start of its SHA-256>", "size": <bytes>}, ...}}`
   for every file in `site/dist/` except `worker.js` and `package.json`. The answer has
   a `jwt` and `buckets` (lists of hashes still to upload; empty means the `jwt` is
   already the completion token).
2. For each bucket: `POST /accounts/<id>/workers/assets/upload?base64=true` with
   `Authorization: Bearer <that jwt>`, multipart, one field per file named by its hash,
   holding the base64 content, with the file's content type. The last answer (201) has
   the completion `jwt`.
3. `PUT /accounts/<id>/workers/scripts/lunarc-site` as above, with
   `"assets": {"jwt": "<completion jwt>", "config": {"run_worker_first": true}}` and
   `"bindings": [{"type": "assets", "name": "ASSETS"}]` in the metadata; `worker.js`
   would then answer from `env.ASSETS.fetch(...)` instead of its built-in table and
   keep adding the headers.

## What the Worker does

- Pages at clean addresses: `/`, `/download`, `/docs`, `/docs/<page>`, `/about`.
  `/download/`, `/download.html` and `/download/index.html` redirect (301) to
  `/download`; a few likely addresses redirect too (`/privacy`, `/manual`,
  `/downloads`, `/docs/getting-started`). Anything else gets the 404 page with status 404.
- `http://` redirects to `https://`. Only GET and HEAD. ETags with 304 answers; hashed
  files under `/a/` are cached for a year, pages for 5 minutes.
- Headers on every answer: `Content-Security-Policy: default-src 'self'; script-src 'self';
  style-src 'self'; img-src 'self'; font-src 'self'; connect-src 'none'; object-src 'none';
  base-uri 'none'; form-action 'none'; frame-ancestors 'none'` (no inline script or
  style anywhere), `Strict-Transport-Security: max-age=63072000; includeSubDomains`
  (not `preload`, which is a separate commitment), `X-Content-Type-Options: nosniff`,
  `Referrer-Policy: no-referrer`, a `Permissions-Policy` turning off camera,
  microphone, location, payment, USB, sensors and topics, `X-Frame-Options: DENY`,
  `Cross-Origin-Opener-Policy` and `Cross-Origin-Resource-Policy: same-origin`.

## Domains (configured in Cloudflare, 2026-10-10)

- `www.lunarclinux.com` and `lunarclinux.org` / `www.lunarclinux.org` redirect
  (301, path and query kept) to https://lunarclinux.com. These are proxied AAAA
  `100::` records plus a Single Redirect rule per zone.
- Both domains publish "no email": null MX (`0 .`), SPF `v=spf1 -all`, DMARC
  `p=reject`.
- `pkgs.lunarclinux.com` is a proxied AAAA `100::` record plus a Single Redirect rule
  (302) to `https://github.com/lunarclinux/lunarc-packages/releases/download/packages/<file>`.
  Publish with `pkg/build --chroot && tools/publish` on the machine holding the
  signing key (a clean-chroot build; decision record 0044).
- `downloads.lunarclinux.com`: the R2 bucket for ISOs (being set up). The site links
  there; no page loads anything from it.
