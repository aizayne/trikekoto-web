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

/**
 * The address the phone can actually reach.
 *
 * "First non-internal IPv4" is not good enough. A laptop running a VPN or a
 * hypervisor has several, and the first one is often a virtual adapter —
 * CloudflareWARP hands out 172.16.x, which is a private range and passes every
 * naive check, but no phone on the Wi-Fi can route to it. The QR then encodes a
 * URL that simply times out, and it looks like the server is broken.
 *
 * So: skip adapters whose names give them away, prefer the ranges home and
 * office Wi-Fi actually use, and let `HOST` override when the guess is wrong.
 */
const VIRTUAL_ADAPTER =
  /warp|vpn|virtual|vethernet|hyper-v|wsl|docker|tailscale|zerotier|loopback|bluetooth/i;

/**
 * Windows Mobile Hotspot / Internet Connection Sharing.
 *
 * Windows always gives this adapter 192.168.137.1, and always names it
 * "Local Area Connection* N". It is a 192.168 address on a real, enabled
 * adapter, so it passes every check above and outranks the actual Wi-Fi —
 * but it is a *different network*. A phone joined to the house Wi-Fi cannot
 * route to it unless it is tethered to this laptop specifically, which is
 * not what "same Wi-Fi" means to anyone reading the instructions.
 *
 * This is the second adapter to produce a dead QR here; CloudflareWARP's
 * 172.16.x was the first. The pattern is the same both times: a plausible
 * private address on an interface nothing else is on.
 */
const HOTSPOT_ADAPTER = /local area connection\*/i;
const ICS_SUBNET = '192.168.137.';

function lanAddress() {
  if (process.env.HOST) return process.env.HOST;

  const candidates = [];
  for (const [name, addresses] of Object.entries(networkInterfaces())) {
    if (VIRTUAL_ADAPTER.test(name) || HOTSPOT_ADAPTER.test(name)) continue;
    for (const address of addresses ?? []) {
      if (address.family !== 'IPv4' || address.internal) continue;
      // 169.254.x is a link-local address assigned when DHCP failed. The
      // interface is up but not on a network anyone else is on.
      if (address.address.startsWith('169.254.')) continue;
      // Belt and braces: skip the ICS subnet even if the adapter was
      // renamed, since that address is never the one to hand out.
      if (address.address.startsWith(ICS_SUBNET)) continue;
      candidates.push({ name, ip: address.address });
    }
  }

  if (candidates.length === 0) return null;

  // 192.168.x and 10.x are what home and office Wi-Fi hand out. 172.16-31.x is
  // also private, but it is where VPN and container networks tend to live, so
  // it is the last resort rather than the first match.
  const rank = (ip) =>
    ip.startsWith('192.168.') ? 0 : ip.startsWith('10.') ? 1 : 2;
  candidates.sort((a, b) => rank(a.ip) - rank(b.ip));

  if (candidates.length > 1) {
    console.log(
      `  Using ${candidates[0].ip} (${candidates[0].name}). Others seen: ` +
        candidates.slice(1).map((c) => `${c.ip} (${c.name})`).join(', ') +
        '\n  Override with:  HOST=<ip> node scripts/serve_apk.mjs\n',
    );
  }
  return candidates[0].ip;
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
