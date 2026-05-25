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
- Adjust the thumbnail grid size from the library sidebar.
- Keep thumbnail cells stable while showing rating and flag state.
- Move to the previous or next visible photo from the toolbar or keyboard.
- Jump to the first or last visible photo from the Photo menu.
- Search by filename and clear the active search quickly.
- Sort by file name, capture date, rating, or flag.
- Filter by picked, rejected, rated, unrated, unflagged, edited, unedited, and minimum star rating.
- Clear active library filters in one action.
- Hide rejected photos during everyday browsing.
- Keep the preview selection aligned with the visible library filter.
- Clear in-memory image caches when needed.
- Rate photos from zero to five stars.
- Use number keys 0-5 to clear or set the selected photo rating.
- Mark photos as picked or rejected.
- Remove photos from the local catalog without deleting the original file.

### Editing

- Non-destructive adjustment model.
- Before and after comparison.
- Side-by-side original and edited comparison.
- Undo and redo for adjustment changes.
- Collapse advanced adjustment panel sections.
- In-memory preview caching for repeated renders.
- In-memory thumbnail caching for smoother library browsing.
- Rotate left and right.
- Straighten.
- Crop to common aspect ratios.
- Apply built-in presets.
- Apply one-click Auto Enhance.
- Apply a one-click black and white look.
- Copy and paste adjustments between photos.
- Sync the current adjustments to all picked photos.
- Reset the selected photo adjustments from the Photo menu or keyboard.
- Apply a built-in preset to all picked photos.
- Reset adjustments on all picked photos.
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
- Radial local exposure with center, radius, and feather controls.
- Linear gradient exposure with start and end controls.
- Invert radial and linear local masks.
- Flip linear gradient direction without changing the exposure amount.
- Reset radial and linear local adjustments independently.
- Single-point spot healing with source offset, radius, feather, and strength controls.
- Reset only the active spot-heal controls.
- Reset local adjustments without changing global edits.
- Per-color saturation controls for red, orange, yellow, green, aqua, blue, purple, and magenta.
- Reset color mixer channels without changing other edits.

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
- Reset beauty adjustments without changing other edits.

### Metadata And Export

- View basic file information.
- Inspect common EXIF fields such as camera, lens, exposure, focal length, and capture time.
- Identify system-readable RAW files with a RAW badge.
- Export the selected edited photo as JPEG.
- Apply export presets for full-size, large web, social, and thumbnail output.
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
- Preview and thumbnail caching are in memory only. Very large libraries and large RAW files still need disk-backed caching and more scheduling work.

## Next Work

- More local adjustment mask types.
- Brush and more gradient tools.
- Multi-point healing and spot removal.
- Disk-backed preview cache.
- More complete RAW and color pipeline.
- Side-by-side compare view.
- Export presets and metadata options.
