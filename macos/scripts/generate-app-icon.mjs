#!/usr/bin/env node
// Generate AppIcon.appiconset from the 1024 master.
//   node macos/scripts/generate-app-icon.mjs
//
// Optional: rebuild the master from a full-canvas render (white corners → alpha):
//   ICON_SOURCE=/path/to/render.png node macos/scripts/generate-app-icon.mjs

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const masterPath = path.join(scriptDir, "icon-master.png");
const outDir = path.join(root, "macos/MinifyImages/Assets.xcassets/AppIcon.appiconset");
const sizes = [16, 32, 64, 128, 256, 512, 1024];

function isCornerWhite(r, g, b) {
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  return min >= 228 && max - min <= 22 && b >= 228;
}

async function masterFromSource(sourcePath) {
  const { data, info } = await sharp(sourcePath)
    .ensureAlpha()
    .resize(1024, 1024, { fit: "fill" })
    .raw()
    .toBuffer({ resolveWithObject: true });

  const w = info.width;
  const h = info.height;
  const pixels = new Uint8Array(data);
  const seen = new Uint8Array(w * h);
  const stack = [];

  const push = (x, y) => {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    const idx = y * w + x;
    if (seen[idx]) return;
    const o = idx * 4;
    if (!isCornerWhite(pixels[o], pixels[o + 1], pixels[o + 2])) return;
    seen[idx] = 1;
    stack.push(idx);
  };

  push(0, 0);
  push(w - 1, 0);
  push(0, h - 1);
  push(w - 1, h - 1);
  push(2, 2);
  push(w - 3, 2);
  push(2, h - 3);
  push(w - 3, h - 3);

  while (stack.length) {
    const idx = stack.pop();
    const o = idx * 4;
    pixels[o + 3] = 0;
    const x = idx % w;
    const y = (idx / w) | 0;
    push(x - 1, y);
    push(x + 1, y);
    push(x, y - 1);
    push(x, y + 1);
  }

  // Soften the squircle silhouette where JPEG fringing left near-white pixels.
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      const idx = y * w + x;
      const o = idx * 4;
      if (pixels[o + 3] === 0) continue;
      let transparentNeighbors = 0;
      if (pixels[((y - 1) * w + x) * 4 + 3] === 0) transparentNeighbors += 1;
      if (pixels[((y + 1) * w + x) * 4 + 3] === 0) transparentNeighbors += 1;
      if (pixels[(y * w + x - 1) * 4 + 3] === 0) transparentNeighbors += 1;
      if (pixels[(y * w + x + 1) * 4 + 3] === 0) transparentNeighbors += 1;
      if (transparentNeighbors === 0) continue;
      const r = pixels[o];
      const g = pixels[o + 1];
      const b = pixels[o + 2];
      const min = Math.min(r, g, b);
      const max = Math.max(r, g, b);
      if (min > 200 && max - min < 40) {
        pixels[o + 3] = Math.max(0, 255 - transparentNeighbors * 70);
      }
    }
  }

  await sharp(Buffer.from(pixels), { raw: { width: w, height: h, channels: 4 } })
    .png()
    .toFile(masterPath);
}

if (process.env.ICON_SOURCE) {
  await masterFromSource(process.env.ICON_SOURCE);
  console.log("Wrote master", masterPath);
}

if (!fs.existsSync(masterPath)) {
  console.error("Missing icon master:", masterPath);
  process.exit(1);
}

const master = await sharp(masterPath).png().toBuffer();
for (const size of sizes) {
  await sharp(master)
    .resize(size, size, { kernel: "lanczos3" })
    .png()
    .toFile(path.join(outDir, `icon_${size}.png`));
}

console.log("Wrote app icons to", outDir);
