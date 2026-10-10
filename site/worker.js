const page = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lunarc</title>
<meta name="description" content="Lunarc is an Arch-based Linux desktop. Coming soon.">
<meta name="theme-color" content="#0B1020">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 80 100'%3E%3Cpath fill='%23EBC77A' d='M 75.4 11.7 A 46 46 0 1 0 75.4 88.3 A 40 40 0 1 1 75.4 11.7 Z'/%3E%3C/svg%3E">
<style>
  :root { color-scheme: dark; }
  html, body { height: 100%; margin: 0; }
  body {
    background: #0B1020; color: #E6E2D6;
    font-family: "Sora", ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif;
    display: flex; align-items: center; justify-content: center; text-align: center;
    padding: 0 16px;
  }
  main { display: flex; flex-direction: column; align-items: center; gap: 18px; }
  svg { width: 72px; height: 90px; }
  h1 { margin: 8px 0 0; font-weight: 300; font-size: 56px; letter-spacing: 2px; }
  p { margin: 0; font-size: 18px; line-height: 1.5; }
  .muted { color: #A3ABC4; font-size: 15px; }
</style>
</head>
<body>
<main>
  <svg viewBox="0 0 80 100" role="img" aria-label="Lunarc crescent mark"><path fill="#EBC77A" d="M 75.4 11.7 A 46 46 0 1 0 75.4 88.3 A 40 40 0 1 1 75.4 11.7 Z"/></svg>
  <h1>Lunarc</h1>
  <p>An Arch-based Linux desktop.</p>
  <p class="muted">Coming soon.</p>
</main>
</body>
</html>`;

export default {
  async fetch() {
    return new Response(page, {
      headers: {
        "content-type": "text/html; charset=utf-8",
        "cache-control": "public, max-age=300",
        "x-content-type-options": "nosniff",
        "referrer-policy": "no-referrer",
        "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'; img-src data:",
      },
    });
  },
};
