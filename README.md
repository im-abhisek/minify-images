# minify-images

A small Mac tool that turns JPEG and PNG files into **high-quality WebP** for a personal blog.

It aims for visually lossless results, not aggressive crushing. Transparency is kept. Nothing is resized unless you ask.

Two ways to run it:

1. **Mac app** — drop files on a window. Best everyday path.
2. **CLI** — `./compress-for-blog`, same quality defaults, still fully supported.

## Mac app

Native SwiftUI app. Encodes with [libwebp](https://developers.google.com/speed/webp) using the same quality policy as the CLI (quality 90 photos, lossless PNG with alpha, near-lossless opaque PNG).

This repo can be opened on a Mac. The app is not prebuilt; you compile it once in Xcode.

### Open, build, run

You need a Mac and **Xcode 16 or later** (Mac App Store). macOS 14 Sonoma or newer. Apple Silicon is the expected machine; Intel works when Xcode builds for it.

```bash
git clone https://github.com/im-abhisek/minify-images.git
cd minify-images
open macos/MinifyImages.xcodeproj
```

1. Wait for Swift packages to finish resolving (first open downloads [libwebp](https://github.com/SDWebImage/libwebp-Xcode); needs network).
2. Select the **Minify Images** scheme and **My Mac**.
3. Press **⌘R**.

If signing complains, open the **MinifyImages** target → **Signing & Capabilities** and choose your Personal Team (a free Apple ID is enough to run locally). The project ships ad-hoc signed (`CODE_SIGN_IDENTITY = "-"`) so Run often works with no team set.

**⌘O** opens files or a folder. **⌘↩** converts. Esc cancels.

Product → Test (**⌘U**) runs the Mac unit tests (quality policy, output paths, folder collection).

### What you get

- Drop JPEG/PNG files **or a folder**
- Progress, per-file success/error, Show in Finder
- Output **next to originals** (default) or a folder you pick
- Optional quality, long-edge cap, PNG Auto / Photo / Lossless, include subfolders

Originals are never modified.

### Not included (on purpose)

- Background removal
- App Store / notarization / Developer ID. To give someone else a `.app`: Product → Archive, then sign with Developer ID, enable Hardened Runtime, and notarize. Sandbox stays **off** so the app can write beside originals like ImageOptim.

## CLI

You need [Homebrew](https://brew.sh) and Node 20+.

```bash
brew install node
git clone https://github.com/im-abhisek/minify-images.git
cd minify-images
chmod +x compress-for-blog compress-for-blog.command
./compress-for-blog --help
```

The first run runs `npm install` for you (it pulls in [sharp](https://sharp.pixelplumbing.com), which ships Apple Silicon and Intel binaries).

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
| Size | **no resize** | Pass `--max 2400` (CLI) or set Long edge (app) if the file is huge |

`--quality` / the app slider only changes the photo / near-lossless paths (1–100):

- **90** — default. Safe for a header image.
- **80** — still sharp, smaller. Fine for most posts.
- **70** — use when the image is small on the page.
- **Lossless** — bit-exact. Larger. Best for logos and UI.

Optional max dimension never upscales. Skip it unless the source is far larger than the post layout.

## Requirements

- macOS 14+ for the app (Apple Silicon first; Intel via the same Xcode project)
- Xcode 16+ to build the app
- Node 20+ (`brew install node`) for the CLI
- JPEG or PNG input (`.jpg`, `.jpeg`, `.png`)

iPhone photos are auto-rotated from EXIF so they don’t land sideways.

## Develop

```bash
npm install
npm test
node src/cli.mjs --help
```

Mac app sources live in `macos/`. The encoder is a small libwebp wrapper in `macos/Packages/WebPBridge`; the quality decision tree in `macos/MinifyImages/Engine/QualityPolicy.swift` matches `webpOptions` in `src/cli.mjs`.

The Mac app itself has to be built in Xcode on a Mac. The encoder wrapper can be smoke-tested anywhere `libwebp` is installed:

```bash
gcc -Imacos/Packages/WebPBridge/Sources/WebPBridge/include \
  macos/Packages/WebPBridge/Sources/WebPBridge/MinifyWebPBridge.c \
  macos/Packages/WebPBridge/test-encode.c \
  -lwebp -lwebpdecoder -o /tmp/webp-bridge-test
/tmp/webp-bridge-test
```
