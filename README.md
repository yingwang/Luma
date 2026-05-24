# Luma

Luma is a native macOS photo-editing prototype built with SwiftUI and Core Image.

The first version focuses on a local workflow:

- import local images
- drag photos or folders into the workspace to import
- click the empty workspace to open photos
- restore a local catalog across launches
- browse thumbnails
- search and filter the library
- sort by file name, capture date, rating, or flag
- filter by minimum star rating
- preview the selected photo
- compare before and after
- undo and redo non-destructive edits
- rotate photos
- crop to common aspect ratios
- straighten photos
- rate, pick, and reject photos
- copy and paste adjustments between photos
- sync the current adjustments to picked photos
- apply built-in presets and auto enhance
- inspect a luminance histogram
- adjust exposure, highlights, shadows, whites, blacks, contrast, saturation, hue, warmth, tint, vibrance, clarity, dehaze, noise reduction, sharpness, and vignette
- tune saturation by color range with a simple color mixer
- apply simple portrait beauty controls for smoothing, wrinkle softening, blemish fading, whitening, rosy tone, brightening, skin warmth, glow, softening, detail, face slimming, and body slimming
- view basic file information
- inspect common EXIF fields such as camera, lens, exposure, focal length, and capture time
- choose JPEG export quality
- resize exports by long edge
- export an edited JPEG
- batch export picked photos

## Run

Open the package in Xcode:

```sh
open Package.swift
```

Or build it from the command line:

```sh
swift build
```

This is an MVP skeleton. The next serious pieces are local masks, healing, faster preview caching, and a more complete RAW/color pipeline.
