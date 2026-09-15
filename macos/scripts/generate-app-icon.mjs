#!/usr/bin/env node
// One-off generator for AppIcon.appiconset. Run from repo root after npm install:
// node macos/scripts/generate-app-icon.mjs

import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const outDir = path.join(root, "macos/MinifyImages/Assets.xcassets/AppIcon.appiconset");

function hex(rgb) {
  return { r: rgb[0], g: rgb[1], b: rgb[2], alpha: rgb[3] ?? 1 };
}

async function disc(size, fill, { inner = 0 } = {}) {
  const buf = Buffer.alloc(size * size * 4);
  const cx = (size - 1) / 2;
  const cy = (size - 1) / 2;
  const outer = size / 2 - 0.5;
  const hole = inner;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const dx = x - cx;
      const dy = y - cy;
      const d = Math.hypot(dx, dy);
      let a = Math.max(0, Math.min(1, outer - d + 0.5));
      if (hole > 0) {
        const innerA = Math.max(0, Math.min(1, hole - d + 0.5));
        a *= 1 - innerA;
      }
      const i = (y * size + x) * 4;
      buf[i] = fill[0];
      buf[i + 1] = fill[1];
      buf[i + 2] = fill[2];
      buf[i + 3] = Math.round(a * 255);
    }
  }
  return sharp(buf, { raw: { width: size, height: size, channels: 4 } }).png().toBuffer();
}

const size = 1024;
const paper = await sharp({
  create: { width: size, height: size, channels: 3, background: hex([244, 239, 230]) },
}).png().toBuffer();

const terracotta = await disc(640, [194, 65, 12]);
const ring = await disc(420, [255, 252, 247], { inner: 168 });
const core = await disc(188, [194, 65, 12]);

const icon = await sharp(paper)
  .composite([
    { input: terracotta, left: 192, top: 192 },
    { input: ring, left: 302, top: 302 },
    { input: core, left: 418, top: 418 },
  ])
  .png()
  .toBuffer();

const sizes = [16, 32, 64, 128, 256, 512, 1024];
for (const s of sizes) {
  await sharp(icon).resize(s, s).png().toFile(path.join(outDir, `icon_${s}.png`));
}

console.log("Wrote app icons to", outDir);
