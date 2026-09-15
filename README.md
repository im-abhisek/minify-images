# minify-images

A tiny Mac-friendly CLI that turns JPEG and PNG files into **high-quality WebP** for a personal blog.

It aims for visually lossless results, not aggressive crushing. Transparency is kept. Nothing is resized unless you ask.

## Install (macOS)

You need [Homebrew](https://brew.sh) and Node 20+.

```bash
brew install node
git clone https://github.com/im-abhisek/minify-images.git
cd minify-images
chmod +x compress-for-blog compress-for-blog.command
./compress-for-blog --help
```

The first run runs `npm install` for you (it pulls in [sharp](https://sharp.pixelplumbing.com), which ships Apple Silicon and Intel binaries).

## Usage

```bash
./compress-for-blog path/to/image.png
./compress-for-blog path/to/photo.jpg
./compress-for-blog ~/Desktop/blog-exports/
```

Drag a file onto the Terminal window after typing `./compress-for-blog ` (note the trailing space), or double-click `compress-for-blog.command` to pick files in Finder.

### Where files go

**Default:** a `.webp` is written **next to the original**, same name.

```
hero.jpg   →  hero.webp
logo.png   →  logo.webp
```

**Folder of images:** every JPEG/PNG in that folder (not subfolders unless `-r`).

**`--out`:** collect everything in one place, keeping subfolder names if you passed `-r`.

```bash
./compress-for-blog --out ./output ./drafts
```

Originals are never modified.

## Examples

```bash
# One screenshot
./compress-for-blog ~/Desktop/hero.png

# A folder of exports
./compress-for-blog ~/Pictures/blog-week-12

# Cap the long edge at 2400px (good for a ~1200px-wide post at 2×)
./compress-for-blog --max 2400 --out ./output ./drafts

# Treat a PNG photograph as a photo (lossy, still keeps alpha)
./compress-for-blog --photo scan.png

# Exact pixels — logos, UI chrome, hard edges
./compress-for-blog --lossless icon.png
```

## What the defaults mean

| Source | Default WebP | Why |
| --- | --- | --- |
| JPEG | quality **90**, effort 6 | Visually lossless for photographs |
| PNG with transparency | **lossless**, alpha kept | Soft edges and clear pixels stay intact |
| PNG, no alpha | **near-lossless** at quality 90 | Screenshots and graphics stay sharp |
| Size | **no resize** | Pass `--max 2400` if the file is huge |

`--quality` only changes the photo / near-lossless paths (1–100):

- **90** — default. Safe for a header image.
- **80** — still sharp, smaller. Fine for most posts.
- **70** — use when the image is small on the page.
- **`--lossless`** — bit-exact. Larger. Best for logos and UI.

Optional `--max` never upscales. Skip it unless the source is far larger than the post layout.

## Requirements

- macOS (Apple Silicon first; Intel is supported by the same Node binary)
- Node 20+ (`brew install node`)
- JPEG or PNG input (`.jpg`, `.jpeg`, `.png`)

iPhone photos are auto-rotated from EXIF so they don’t land sideways.

## Develop

```bash
npm install
npm test
node src/cli.mjs --help
```
