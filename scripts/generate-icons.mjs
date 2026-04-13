// ============================================================
// generate-icons.mjs — TrikeKoTo PWA icon pipeline
// ============================================================
// Reads scripts/icon-source.svg and rasterizes it into every
// size the manifest + index.html needs. Run with:
//
//     npm run icons
//
// Output goes to public/icons/. Commit the resulting PNGs so
// deployments don't need to re-run this script.
// ============================================================

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Resvg } from "@resvg/resvg-js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT      = resolve(__dirname, "..");
const SOURCE    = resolve(ROOT, "scripts/icon-source.svg");
const OUT_DIR   = resolve(ROOT, "public/icons");

// ─── Icon targets ────────────────────────────────────────────
// sizes cover: standard PWA (192, 512), iOS home screen (180),
// favicon (32, 16), and maskable variants (192, 512) that will
// be rendered with the 80% safe zone the source SVG already
// respects.
const TARGETS = [
  { name: "icon-192.png",          size: 192 },
  { name: "icon-512.png",          size: 512 },
  { name: "icon-192-maskable.png", size: 192, maskable: true },
  { name: "icon-512-maskable.png", size: 512, maskable: true },
  { name: "apple-touch-icon.png",  size: 180 },
  { name: "favicon-32.png",        size: 32  },
  { name: "favicon-16.png",        size: 16  },
];

// ─── Generate ────────────────────────────────────────────────
if (!existsSync(SOURCE)) {
  console.error(`Source SVG not found at ${SOURCE}`);
  process.exit(1);
}

if (!existsSync(OUT_DIR)) {
  mkdirSync(OUT_DIR, { recursive: true });
}

const svg = readFileSync(SOURCE, "utf8");

for (const { name, size } of TARGETS) {
  const resvg = new Resvg(svg, {
    fitTo: { mode: "width", value: size },
    background: "#f59e0b",
    shapeRendering: 2,   // geometric precision
    textRendering:  2,   // optimize legibility (unused — no text)
    imageRendering: 0,   // optimize quality
  });
  const png = resvg.render().asPng();
  const outPath = resolve(OUT_DIR, name);
  writeFileSync(outPath, png);
  console.log(`  → ${name.padEnd(26)} ${size}x${size}  (${(png.length / 1024).toFixed(1)} KB)`);
}

console.log(`\nDone. ${TARGETS.length} icons written to public/icons/`);
