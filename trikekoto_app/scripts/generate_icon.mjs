// ============================================================
// Rasterises the app icon from its SVG source
// ============================================================
//   node scripts/generate_icon.mjs
//
// Produces three PNGs that flutter_launcher_icons then expands into every
// Android density:
//
//   icon.png            full-bleed square, used for the legacy launcher icon
//   icon_foreground.png transparent, mark only, for the adaptive foreground
//   icon_monochrome.png white-on-transparent, for Android 13 themed icons
//
// The adaptive foreground is inset deliberately. Android masks adaptive icons
// to a circle, squircle, or rounded square depending on the launcher, and
// only the centre 66% is guaranteed visible — a mark drawn to the edges gets
// its wheels clipped on exactly the devices most drivers use.
// ============================================================

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';

const here = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(here, '..');
const sourcePath = resolve(projectRoot, 'assets/icon/icon_source.svg');
const outDir = resolve(projectRoot, 'assets/icon');

mkdirSync(outDir, { recursive: true });
const svg = readFileSync(sourcePath, 'utf8');

// The wordmark is set in Poppins, which the app bundles. resvg has no system
// font access, so the exact files are handed to it — otherwise it silently
// substitutes a default face and the icon ships in the wrong typeface.
const fontFiles = [
  'Poppins-Bold.ttf',
  'Poppins-SemiBold.ttf',
  'Poppins-Medium.ttf',
  'Poppins-Regular.ttf',
].map((f) => resolve(projectRoot, 'assets/fonts', f));

function render(markup, size, file) {
  const png = new Resvg(markup, {
    fitTo: { mode: 'width', value: size },
    background: 'rgba(0,0,0,0)',
    font: { fontFiles, loadSystemFonts: false, defaultFontFamily: 'Poppins' },
  })
    .render()
    .asPng();
  writeFileSync(resolve(outDir, file), png);
  console.log(`  ${file.padEnd(24)} ${size}x${size}  ${(png.length / 1024).toFixed(0)} KB`);
}

// 1. Full-bleed square.
render(svg, 1024, 'icon.png');

/// Everything between the outer <svg> tags, with the full-bleed background
/// rect dropped. Structural rather than pattern-matched on a particular fill,
/// so redesigning the artwork does not silently break the foreground.
function markOnly(source) {
  const inner = source
    .replace(/^[\s\S]*?<svg[^>]*>/, '')
    .replace(/<\/svg>\s*$/, '');
  return inner.replace(
    /<rect\s+width="1024"\s+height="1024"[^>]*\/>/,
    '',
  );
}

// 2. Adaptive foreground: the mark alone, inset to ~62% of the canvas so no
//    launcher mask can clip it.
const inset = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <g transform="translate(512,512) scale(0.62) translate(-512,-512)">
    ${markOnly(svg)}
  </g>
</svg>`;

render(inset, 1024, 'icon_foreground.png');

// 3. Themed icon for Android 13+. The system tints this to the wallpaper, so
//    it must be a single flat colour — the amber is flattened to white and
//    the wheel's stroke recoloured to match.
render(
  inset.replace(/#F5A623/g, '#FFFFFF'),
  1024,
  'icon_monochrome.png',
);

console.log('\nDone. Now run:  dart run flutter_launcher_icons\n');
