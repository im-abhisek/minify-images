#!/usr/bin/env node

import { mkdir, readdir, stat } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import sharp from "sharp";

const VERSION = "1.0.0";
const IMAGE_EXT = new Set([".jpg", ".jpeg", ".png"]);
const DEFAULT_QUALITY = 90;

const HELP = `
minify-images  ·  JPEG/PNG → high-quality WebP for blog posts

Usage:
  ./compress-for-blog [options] <file-or-folder> [more...]

Examples:
  ./compress-for-blog photo.jpg
  ./compress-for-blog shot.png ~/Desktop/exports/
  ./compress-for-blog --out ./output --max 2400 ./drafts
  ./compress-for-blog --photo screenshot.png

Options:
  -o, --out <dir>     Write WebP files here (default: next to each original)
  -q, --quality <n>   Photo quality 1–100 (default: ${DEFAULT_QUALITY})
      --max <px>      Cap the longest side; never upscales (off by default)
      --lossless      Force lossless WebP (exact pixels, larger files)
      --photo         Treat PNGs as photos (lossy quality; keeps alpha)
  -r, --recursive     Include images in subfolders
      --dry-run       Print the plan; write nothing
  -h, --help          Show this help
  -v, --version       Show version

Defaults (blog-oriented, visually lossless):
  JPEG              WebP quality ${DEFAULT_QUALITY}, effort 6
  PNG + transparency  lossless WebP (alpha preserved)
  PNG, no alpha     near-lossless WebP
  Resize            off unless you pass --max

Quality quick guide:
  90   visually lossless photographs — the default
  80   still sharp, noticeably smaller
  70   fine for small inline images
  lossless  screenshots, UI, logos, anything with hard edges + alpha
`.trim();

export function parseArgs(argv) {
  const opts = {
    out: null,
    quality: DEFAULT_QUALITY,
    max: null,
    lossless: false,
    photo: false,
    recursive: false,
    dryRun: false,
    inputs: [],
  };

  const args = argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    const next = () => {
      const value = args[++i];
      if (value == null || value.startsWith("-")) {
        throw new Error(`Missing value for ${arg}`);
      }
      return value;
    };

    switch (arg) {
      case "-h":
      case "--help":
        opts.help = true;
        break;
      case "-v":
      case "--version":
        opts.version = true;
        break;
      case "-o":
      case "--out":
        opts.out = next();
        break;
      case "-q":
      case "--quality": {
        const n = Number(next());
        if (!Number.isInteger(n) || n < 1 || n > 100) {
          throw new Error("--quality must be an integer from 1 to 100");
        }
        opts.quality = n;
        break;
      }
      case "--max": {
        const n = Number(next());
        if (!Number.isInteger(n) || n < 1) {
          throw new Error("--max must be a positive pixel size");
        }
        opts.max = n;
        break;
      }
      case "--lossless":
        opts.lossless = true;
        break;
      case "--photo":
        opts.photo = true;
        break;
      case "-r":
      case "--recursive":
        opts.recursive = true;
        break;
      case "--dry-run":
        opts.dryRun = true;
        break;
      default:
        if (arg.startsWith("-")) {
          throw new Error(`Unknown option: ${arg}\n\n${HELP}`);
        }
        opts.inputs.push(arg);
    }
  }

  return opts;
}

function isImageFile(filePath) {
  return IMAGE_EXT.has(path.extname(filePath).toLowerCase());
}

async function collectImages(inputPath, recursive) {
  const abs = path.resolve(inputPath);
  if (!existsSync(abs)) {
    throw new Error(`Not found: ${inputPath}`);
  }

  const info = await stat(abs);
  if (info.isFile()) {
    if (!isImageFile(abs)) {
      throw new Error(`Not a JPEG or PNG: ${inputPath}`);
    }
    return [{ source: abs, root: path.dirname(abs) }];
  }

  if (!info.isDirectory()) {
    throw new Error(`Not a file or folder: ${inputPath}`);
  }

  const found = [];
  async function walk(dir) {
    const entries = await readdir(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name.startsWith(".")) continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if (recursive) await walk(full);
        continue;
      }
      if (entry.isFile() && isImageFile(full)) {
        found.push({ source: full, root: abs });
      }
    }
  }

  await walk(abs);
  return found;
}

export function outputPathFor(source, root, outDir) {
  const base = `${path.basename(source, path.extname(source))}.webp`;
  if (!outDir) {
    return path.join(path.dirname(source), base);
  }
  const relativeDir = path.relative(root, path.dirname(source));
  return path.join(path.resolve(outDir), relativeDir, base);
}

export function webpOptions({ format, hasAlpha, quality, lossless, photo }) {
  const forceLossless = lossless;
  const pngLikePhoto = format === "png" && photo;
  const pngPreserve = format === "png" && !photo && !forceLossless;

  if (forceLossless || (pngPreserve && hasAlpha)) {
    return {
      label: hasAlpha ? "png+alpha, lossless" : "lossless",
      options: {
        lossless: true,
        alphaQuality: 100,
        effort: 6,
        exact: hasAlpha,
      },
    };
  }

  if (pngPreserve) {
    return {
      label: `png, near-lossless q${quality}`,
      options: {
        nearLossless: true,
        quality,
        alphaQuality: 100,
        effort: 6,
      },
    };
  }

  return {
    label: hasAlpha ? `photo+alpha, q${quality}` : `photo, q${quality}`,
    options: {
      quality,
      alphaQuality: 100,
      smartSubsample: true,
      effort: 6,
      preset: "photo",
    },
  };
}

export async function convertImage(source, dest, opts) {
  const image = sharp(source, { failOn: "none" }).rotate();
  const meta = await image.metadata();

  let pipeline = image;
  if (opts.max) {
    pipeline = pipeline.resize({
      width: opts.max,
      height: opts.max,
      fit: "inside",
      withoutEnlargement: true,
    });
  }

  const { label, options } = webpOptions({
    format: meta.format,
    hasAlpha: Boolean(meta.hasAlpha),
    quality: opts.quality,
    lossless: opts.lossless,
    photo: opts.photo,
  });

  await mkdir(path.dirname(dest), { recursive: true });
  await pipeline.webp(options).toFile(dest);

  const outMeta = await sharp(dest).metadata();
  return {
    label,
    sourceBytes: (await stat(source)).size,
    destBytes: (await stat(dest)).size,
    hasAlpha: Boolean(outMeta.hasAlpha),
    width: outMeta.width,
    height: outMeta.height,
  };
}

function prettyPath(abs) {
  const resolved = path.resolve(abs);
  const rel = path.relative(process.cwd(), resolved);
  if (rel && rel !== ".." && !rel.startsWith(`..${path.sep}`) && !path.isAbsolute(rel)) {
    return rel;
  }
  const home = process.env.HOME;
  if (home && (resolved === home || resolved.startsWith(`${home}${path.sep}`))) {
    return `~${resolved.slice(home.length)}`;
  }
  return resolved;
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function pad(text, width) {
  const str = String(text);
  return str.length >= width ? str : str + " ".repeat(width - str.length);
}

function savings(from, to) {
  if (from <= 0) return "n/a";
  const pct = ((1 - to / from) * 100).toFixed(0);
  const sign = to <= from ? "−" : "+";
  return `${sign}${Math.abs(Number(pct))}%`;
}

export async function run(argv, io = console) {
  let opts;
  try {
    opts = parseArgs(argv);
  } catch (err) {
    io.error(err.message);
    return 1;
  }

  if (opts.help) {
    io.log(HELP);
    return 0;
  }
  if (opts.version) {
    io.log(VERSION);
    return 0;
  }
  if (opts.inputs.length === 0) {
    io.error("Pass at least one JPEG, PNG, or folder.\n");
    io.log(HELP);
    return 1;
  }

  const jobs = [];
  for (const input of opts.inputs) {
    jobs.push(...(await collectImages(input, opts.recursive)));
  }

  const unique = [];
  const seen = new Set();
  for (const job of jobs) {
    if (seen.has(job.source)) continue;
    seen.add(job.source);
    unique.push(job);
  }

  unique.sort((a, b) => a.source.localeCompare(b.source));

  if (unique.length === 0) {
    io.error("No JPEG or PNG files found.");
    return 1;
  }

  io.log(`minify-images  ·  ${unique.length} file${unique.length === 1 ? "" : "s"}\n`);

  let totalIn = 0;
  let totalOut = 0;
  let failed = 0;
  let wrote = 0;

  for (const job of unique) {
    const dest = outputPathFor(job.source, job.root, opts.out);
    const display = prettyPath(job.source);
    const destDisplay = prettyPath(dest);

    if (opts.dryRun) {
      io.log(`  ${display}  →  ${destDisplay}`);
      continue;
    }

    try {
      const result = await convertImage(job.source, dest, opts);
      totalIn += result.sourceBytes;
      totalOut += result.destBytes;
      wrote += 1;
      const note = result.destBytes > result.sourceBytes ? "  (larger than original)" : "";
      io.log(
        `  ${pad(display, 36)}  ${pad(formatBytes(result.sourceBytes), 8)}  →  ${pad(formatBytes(result.destBytes), 8)}  ${pad(savings(result.sourceBytes, result.destBytes), 5)}  ${result.label}${note}`
      );
    } catch (err) {
      failed += 1;
      io.error(`  ${display}  failed: ${err.message}`);
    }
  }

  if (opts.dryRun) {
    io.log(`\nDry run. Nothing written.`);
    return 0;
  }

  io.log("");
  if (wrote) {
    const where = opts.out
      ? `Wrote to ${path.resolve(opts.out)}`
      : "Wrote WebP files next to the originals";
    io.log(`  ${wrote} converted  ·  ${formatBytes(totalIn)} → ${formatBytes(totalOut)}  (${savings(totalIn, totalOut)})`);
    io.log(`  ${where}`);
  }
  if (failed) {
    io.error(`  ${failed} failed`);
    return 1;
  }
  return 0;
}

const isDirectRun =
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isDirectRun) {
  run(process.argv).then((code) => process.exit(code));
}
