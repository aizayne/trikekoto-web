import QRCode from "qrcode";
import { writeFileSync } from "fs";

const URL = "https://trikekoto.web.app";

// Generate SVG QR code
const svg = await QRCode.toString(URL, {
  type: "svg",
  width: 300,
  margin: 2,
  color: { dark: "#0f172a", light: "#ffffff" },
});

// Wrap in a styled HTML page
const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>TrikeKoTo — Install QR Code</title>
<style>
  body {
    margin: 0; min-height: 100vh;
    display: flex; flex-direction: column;
    align-items: center; justify-content: center;
    background: #0f172a; color: #f8fafc;
    font-family: 'Segoe UI', system-ui, sans-serif;
    gap: 1.5rem; padding: 2rem; box-sizing: border-box;
  }
  h1 { font-size: 2.2rem; font-weight: 900; color: #f59e0b; margin: 0; }
  p  { color: #94a3b8; font-size: 0.95rem; margin: 0; }
  .qr {
    background: #fff; border-radius: 1.25rem;
    padding: 1.5rem; box-shadow: 0 8px 32px rgba(0,0,0,0.5);
  }
  .url {
    background: #1e293b; border-radius: 0.75rem;
    padding: 0.6rem 1.2rem; font-size: 0.9rem;
    color: #60a5fa; font-weight: 600; letter-spacing: 0.02em;
  }
  .hint { font-size: 0.78rem; color: #475569; text-align: center; max-width: 320px; line-height: 1.6; }
</style>
</head>
<body>
  <h1>TrikeKoTo</h1>
  <p>Scan to install the app</p>
  <div class="qr">${svg}</div>
  <div class="url">${URL}</div>
  <p class="hint">Open the link on your phone, then tap "Add to Home Screen" to install TrikeKoTo as an app.</p>
</body>
</html>`;

writeFileSync("public/qr.html", html);
console.log("QR code page created → public/qr.html");
console.log("Also available at: https://trikekoto.web.app/qr.html (after next deploy)");
