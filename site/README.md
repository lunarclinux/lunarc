# Website

`worker.js` is the placeholder page served at https://lunarclinux.com by a
Cloudflare Worker named `lunarc-site` (custom domain lunarclinux.com).

Also configured in Cloudflare (2026-10-10):
- `www.lunarclinux.com` and `lunarclinux.org` / `www.lunarclinux.org` redirect
  (301, path and query kept) to https://lunarclinux.com. These are proxied AAAA
  `100::` records plus a Single Redirect rule per zone.
- Both domains publish "no email": null MX (`0 .`), SPF `v=spf1 -all`, DMARC
  `p=reject`.
- `pkgs.lunarclinux.com` is reserved for the package repository (layer 7).

Deploy a new version (needs an API token with Workers Scripts edit):

    curl -X PUT -H "Authorization: Bearer $TOKEN" \
      -F 'metadata={"main_module":"worker.js","compatibility_date":"2026-10-01"};type=application/json' \
      -F 'worker.js=@site/worker.js;filename=worker.js;type=application/javascript+module' \
      https://api.cloudflare.com/client/v4/accounts/<account id>/workers/scripts/lunarc-site
