// ============================================================
// Serve the built APK over your LAN and print a QR code
// ============================================================
//   cd trikekoto_app
//   flutter build apk --release
//   node scripts/serve_apk.mjs
//
// Scan the QR with the phone's camera, tap the link, install.
//
// The APK never leaves your network — this starts a plain HTTP
// server bound to your LAN address and encodes that URL. The phone
// must be on the same Wi-Fi. Ctrl+C stops the server and the link
// dies with it.
//
// On the phone you will have to allow "install unknown apps" for
// whichever browser opens the link. That prompt is Android asking
// whether to trust a sideloaded package; it is expected here.
// ============================================================

import { createReadStream, existsSync, statSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { networkInterfaces } from 'node:os';
import { basename, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import QRCode from 'qrcode';

const here = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(here, '..');
const PORT = Number(process.env.PORT ?? 8787);

const apkPath =
  process.argv[2] ??
  resolve(projectRoot, 'build/app/outputs/flutter-apk/app-release.apk');

if (!existsSync(apkPath)) {
  console.error(
    `\n  APK not found at:\n    ${apkPath}\n\n` +
      '  Build it first:\n    flutter build apk --release\n\n' +
      '  Or pass a path:\n    node scripts/serve_apk.mjs <path-to.apk>\n',
  );
  process.exit(1);
}

/** First non-internal IPv4 address — the one the phone can reach. */
function lanAddress() {
  for (const addresses of Object.values(networkInterfaces())) {
    for (const address of addresses ?? []) {
      if (address.family === 'IPv4' && !address.internal) return address.address;
    }
  }
  return null;
}

const host = lanAddress();
if (!host) {
  console.error('\n  No LAN address found. Are you connected to Wi-Fi?\n');
  process.exit(1);
}

const fileName = basename(apkPath);
const sizeMb = (statSync(apkPath).size / 1024 / 1024).toFixed(1);
const url = `http://${host}:${PORT}/${fileName}`;

const server = createServer((req, res) => {
  if (req.url === '/' || req.url === `/${fileName}`) {
    res.writeHead(200, {
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Disposition': `attachment; filename="${fileName}"`,
      'Content-Length': statSync(apkPath).size,
    });
    createReadStream(apkPath).pipe(res);
    console.log(`  ↓ download started from ${req.socket.remoteAddress}`);
    return;
  }
  res.writeHead(404).end('Not found');
});

server.listen(PORT, '0.0.0.0', async () => {
  const ascii = await QRCode.toString(url, { type: 'terminal', small: true });
  const pngPath = resolve(projectRoot, 'build/install-qr.png');
  await QRCode.toFile(pngPath, url, { width: 512, margin: 2 });

  console.log(ascii);
  console.log(`  ${fileName}  (${sizeMb} MB)`);
  console.log(`  ${url}`);
  console.log(`  QR image saved to ${pngPath}`);
  console.log('\n  Phone must be on the same Wi-Fi. Ctrl+C to stop.\n');
});

process.on('SIGINT', () => {
  console.log('\n  Server stopped — the link is now dead.');
  server.close(() => process.exit(0));
});
