# Luma

Luma is a native macOS photo-editing prototype built with SwiftUI and Core Image.

The goal is a fast local editor for browsing photos, making common non-destructive adjustments, applying simple portrait retouching, and exporting edited JPEGs without sending images to a server.

## What Works

### Library

- Import local photos and folders.
- Drag photos or folders into the workspace to import them.
- Click the empty workspace to open the system file picker.
- Restore the local catalog across launches.
- Browse thumbnails and preview the selected photo.
- Search by filename.
- Sort by file name, capture date, rating, or flag.
- Filter by picked, rejected, and minimum star rating.
- Rate photos from zero to five stars.
- Mark photos as picked or rejected.
- Remove photos from the local catalog without deleting the original file.

### Editing

- Non-destructive adjustment model.
- Before and after comparison.
- Side-by-side original and edited comparison.
- Undo and redo for adjustment changes.
- Rotate left and right.
- Straighten.
- Crop to common aspect ratios.
- Apply built-in presets.
- Apply one-click Auto Enhance.
- Copy and paste adjustments between photos.
- Sync the current adjustments to all picked photos.
- Inspect a luminance histogram.

### Light And Color

- Exposure.
- Highlights.
- Shadows.
- Whites.
- Blacks.
- Contrast.
- Saturation.
- Hue.
- Warmth.
- Tint.
- Vibrance.
- Clarity.
- Dehaze.
- Noise reduction.
- Sharpness.
- Vignette.
- Per-color saturation controls for red, orange, yellow, green, aqua, blue, purple, and magenta.

### Portrait Retouching

- One-click Auto Beauty.
- Skin smoothing.
- Wrinkle softening.
- Blemish fading.
- Whitening.
- Rosy tone.
- Brightening.
- Skin warmth.
- Glow.
- Softening.
- Detail.
- Eye enlargement using face detection when eye landmarks are available.
- Face slimming using face detection.
- Body slimming with a simple center-weighted distortion.

### Metadata And Export

- View basic file information.
- Inspect common EXIF fields such as camera, lens, exposure, focal length, and capture time.
- Identify system-readable RAW files with a RAW badge.
- Export the selected edited photo as JPEG.
- Choose JPEG quality.
- Resize exports by long edge.
- Batch export all picked photos.

## Run

Open the package in Xcode:

```sh
open Package.swift
```

Or build it from the command line:

```sh
swift build
```

Run tests from the command line:

```sh
swift test
```

## Current Limits

- RAW support depends on what macOS ImageIO and Core Image can decode on the current machine.
- RAW processing is still basic. Luma does not yet provide a full camera-profile, demosaic, lens-correction, or color-management pipeline.
- Portrait retouching is simple Core Image based processing. It is useful for quick edits, but it is not yet a semantic face/body retouching engine.
- Healing and masking are not complete yet.
- Preview caching is still basic, so very large libraries and large RAW files need more optimization.

## Next Work

- Local adjustment masks.
- Brush and gradient tools.
- Better healing and spot removal.
- Faster preview cache.
- More complete RAW and color pipeline.
- Side-by-side compare view.
- Export presets and metadata options.
