# minify-images

A small Mac tool that turns JPEG, PNG, and HEIC files into **high-quality WebP** for a personal blog.

It aims for visually lossless results, not aggressive crushing. Transparency is kept. Nothing is resized unless you ask.

Two ways to run it:

1. **Mac app** — drop files on a window. Best everyday path.
2. **CLI** — `./compress-for-blog`, same quality defaults, still fully supported.

## Mac app

**WebPinch** is the native SwiftUI app, always in dark mode. The built bundle is `WebPinch.app`. It encodes with [libwebp](https://developers.google.com/speed/webp). The quality slider applies to JPEG, PNG, and HEIC (lossy WebP, alpha kept) and starts at **75**; the CLI default is still 90. HEIC is decoded with ImageIO. Display P3 and other wide-gamut sources are converted to sRGB before encoding, because the WebP bytes are raw pixels and do not store an ICC profile.

This repo can be opened on a Mac. The app is not prebuilt; you compile it once in Xcode.

### Open, build, run

You need a Mac and **Xcode 16 or later** (Mac App Store). macOS 14 Sonoma or newer. Apple Silicon is the expected machine; Intel works when Xcode builds for it.

```bash
git clone https://github.com/im-abhisek/minify-images.git
cd minify-images
open macos/MinifyImages.xcodeproj
```

1. Wait for Swift packages to finish resolving (first open downloads [libwebp](https://github.com/SDWebImage/libwebp-Xcode); needs network).
2. Select the **Minify Images** scheme (Xcode scheme name; the app is WebPinch) and **My Mac**.
3. Press **⌘R**.

If signing complains, open the **MinifyImages** target → **Signing & Capabilities** and choose your Personal Team (a free Apple ID is enough to run locally). The project ships ad-hoc signed (`CODE_SIGN_IDENTITY = "-"`) so Run often works with no team set.

**⌘O** opens files or a folder. **⌘↩** converts. Esc cancels. Finder Open With and `open -a` add files to the one window.

Product → Test (**⌘U**) runs the Mac unit tests (quality policy, output paths, folder collection).

### What you get

- Drop JPEG, PNG, or HEIC files **or a folder**. A dropped folder includes JPEG, PNG, and HEIC files in subfolders. Finder’s Open With lists WebPinch for `.heic` and `.heif` too.
- One pane: drop files or a folder, or use Add Files. Added images show as a thumbnail grid with per-file size and progress. The pane is a solid rounded surface with a faint canvas grid and hairline, and a soft blue tint while dragging. While converting, the border picks up a slow, faint blue-and-pink tint.
- Output reads **Next to originals**, with a **Choose Folder** link. After a folder is chosen the name is shown, a small clear button returns to originals, and **Change** reopens the panel. The folder is remembered until it is cleared.
- Quality (default 75) sits beside Output on a 0–100 slider whose track runs from red through yellow to green. Folder drops always include subfolders. The app does not resize. Transparent PNGs keep their alpha. The window title, Dock label, and app menu use the name WebPinch.

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
photo.heic →  photo.webp
```

**Folder of images:** every JPEG, PNG, or HEIC in that folder (not subfolders unless `-r`). `.heif` is accepted too.

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
| JPEG, HEIC, HEIF | quality **90**, effort 6 | Visually lossless for photographs. Alpha is kept when the source has it. |
| PNG with transparency | **lossless**, alpha kept | Soft edges and clear pixels stay intact |
| PNG, no alpha | **near-lossless** at quality 90 | Screenshots and graphics stay sharp |
| Size | **no resize** | CLI: pass `--max 2400` if the file is huge. The Mac app does not resize. |

`--quality` (CLI, 1–100) and the app slider (0–100) only change the photo / near-lossless paths:

- **90** — default. Safe for a header image.
- **80** — still sharp, smaller. Fine for most posts.
- **70** — use when the image is small on the page.
- **Lossless** — bit-exact. Larger. Best for logos and UI.

On the CLI, `--max` never upscales. Skip it unless the source is far larger than the post layout. The Mac app does not resize.

## Requirements

- macOS 14+ for the app (Apple Silicon first; Intel via the same Xcode project)
- Xcode 16+ to build the app
- Node 20+ (`brew install node`) for the CLI
- JPEG, PNG, or HEIC input (`.jpg`, `.jpeg`, `.png`, `.heic`, `.heif`)

iPhone photos are auto-rotated from EXIF (and the HEIC rotation box) so portrait shots don’t land sideways. The Mac app uses the primary image when a HEIC file contains more than one.

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
