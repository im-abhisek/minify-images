#!/usr/bin/env node

import { mkdir, mkdtemp, rm } from "node:fs/promises";
import { existsSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import sharp from "sharp";
import { convertImage, outputPathFor, parseArgs, run } from "./cli.mjs";

let failed = 0;

function assert(condition, message) {
  if (!condition) {
    failed += 1;
    console.error(`  fail  ${message}`);
  } else {
    console.log(`  ok    ${message}`);
  }
}

async function withTemp(fn) {
  const dir = await mkdtemp(path.join(os.tmpdir(), "minify-images-"));
  try {
    return await fn(dir);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

async function makeJpeg(file) {
  // Soft photographic field so lossy WebP can actually shrink it.
  await sharp({
    create: {
      width: 1200,
      height: 800,
      channels: 3,
      noise: { type: "gaussian", mean: 140, sigma: 28 },
    },
  })
    .jpeg({ quality: 95, mozjpeg: true })
    .toFile(file);
}

async function makePngWithAlpha(file) {
  const size = 400;
  const buf = Buffer.alloc(size * size * 4);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const i = (y * size + x) * 4;
      const dx = x - size / 2;
      const dy = y - size / 2;
      const inside = dx * dx + dy * dy < 140 * 140;
      buf[i] = 220;
      buf[i + 1] = 40;
      buf[i + 2] = 80;
      buf[i + 3] = inside ? 255 : 0;
    }
  }
  await sharp(buf, { raw: { width: size, height: size, channels: 4 } })
    .png()
    .toFile(file);
}

async function makeOpaquePng(file) {
  await sharp({
    create: {
      width: 320,
      height: 240,
      channels: 3,
      background: { r: 32, g: 120, b: 90 },
    },
  })
    .png()
    .toFile(file);
}

console.log("minify-images tests\n");

await withTemp(async (dir) => {
  const jpeg = path.join(dir, "hero.jpg");
  const dest = path.join(dir, "hero.webp");
  await makeJpeg(jpeg);
  const result = await convertImage(jpeg, dest, {
    quality: 90,
    max: null,
    lossless: false,
    photo: false,
  });
  assert(existsSync(dest), "JPEG produces a .webp file");
  assert(result.destBytes > 0, "JPEG WebP is non-empty");
  assert(result.destBytes < result.sourceBytes, "JPEG WebP is smaller than the source JPEG");
  assert(!result.hasAlpha, "JPEG WebP has no alpha");
});

await withTemp(async (dir) => {
  const png = path.join(dir, "logo.png");
  const dest = path.join(dir, "logo.webp");
  await makePngWithAlpha(png);
  const result = await convertImage(png, dest, {
    quality: 90,
    max: null,
    lossless: false,
    photo: false,
  });
  assert(existsSync(dest), "transparent PNG produces a .webp file");
  assert(result.hasAlpha, "transparent PNG keeps alpha in WebP");
  assert(result.destBytes < result.sourceBytes, "transparent PNG WebP is smaller than the source PNG");
});

await withTemp(async (dir) => {
  const png = path.join(dir, "flat.png");
  const dest = path.join(dir, "flat.webp");
  await makeOpaquePng(png);
  const result = await convertImage(png, dest, {
    quality: 90,
    max: null,
    lossless: false,
    photo: false,
  });
  assert(existsSync(dest), "opaque PNG produces a .webp file");
  assert(!result.hasAlpha, "opaque PNG WebP has no alpha channel");
});

await withTemp(async (dir) => {
  const jpeg = path.join(dir, "wide.jpg");
  const dest = path.join(dir, "wide.webp");
  await makeJpeg(jpeg);
  const result = await convertImage(jpeg, dest, {
    quality: 90,
    max: 400,
    lossless: false,
    photo: false,
  });
  assert(result.width === 400, `--max 400 resizes width to 400 (got ${result.width})`);
  assert(result.height === 267, `--max 400 keeps aspect ratio (got ${result.height})`);
});

{
  const opts = parseArgs(["node", "cli", "--quality", "80", "--max", "2400", "-r", "a.png"]);
  assert(opts.quality === 80, "parses --quality");
  assert(opts.max === 2400, "parses --max");
  assert(opts.recursive === true, "parses -r");
  assert(opts.inputs[0] === "a.png", "collects positional inputs");
}

{
  const dest = outputPathFor("/blog/drafts/hero.jpg", "/blog/drafts", null);
  assert(dest === "/blog/drafts/hero.webp", "default output sits next to the original");
}

{
  const dest = outputPathFor("/blog/drafts/nested/hero.jpg", "/blog/drafts", "/tmp/out");
  assert(dest === "/tmp/out/nested/hero.webp", "--out preserves relative folders");
}

await withTemp(async (dir) => {
  const folder = path.join(dir, "batch");
  await mkdir(folder);
  await makeJpeg(path.join(folder, "a.jpg"));
  await makePngWithAlpha(path.join(folder, "b.png"));
  const logs = [];
  const code = await run(["node", "cli", folder], {
    log: (msg) => logs.push(String(msg)),
    error: (msg) => logs.push(String(msg)),
  });
  assert(code === 0, "folder batch exits 0");
  assert(existsSync(path.join(folder, "a.webp")), "folder batch writes JPEG WebP next to original");
  assert(existsSync(path.join(folder, "b.webp")), "folder batch writes PNG WebP next to original");
});

await withTemp(async (dir) => {
  const src = path.join(dir, "in.jpg");
  const out = path.join(dir, "output");
  await makeJpeg(src);
  const code = await run(["node", "cli", "--out", out, src], {
    log: () => {},
    error: console.error,
  });
  assert(code === 0, "--out exits 0");
  assert(existsSync(path.join(out, "in.webp")), "--out writes into the given folder");
  assert(!existsSync(path.join(dir, "in.webp")), "--out does not also write next to the original");
});

await withTemp(async (dir) => {
  const src = path.join(dir, "dry.png");
  await makeOpaquePng(src);
  const code = await run(["node", "cli", "--dry-run", src], {
    log: () => {},
    error: console.error,
  });
  assert(code === 0, "--dry-run exits 0");
  assert(!existsSync(path.join(dir, "dry.webp")), "--dry-run writes nothing");
});

{
  const code = await run(["node", "cli", "--help"], {
    log: () => {},
    error: console.error,
  });
  assert(code === 0, "--help exits 0");
}

console.log("");
if (failed) {
  console.error(`${failed} test(s) failed`);
  process.exit(1);
}
console.log("all tests passed");
