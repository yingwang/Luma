# Luma

Luma is a native macOS photo-editing prototype built with SwiftUI and Core Image.

The first version focuses on a local workflow:

- import local images
- restore a local catalog across launches
- browse thumbnails
- search and filter the library
- preview the selected photo
- compare before and after
- rotate photos
- rate, pick, and reject photos
- copy and paste adjustments between photos
- apply built-in presets and auto enhance
- inspect a luminance histogram
- adjust exposure, contrast, saturation, warmth, vibrance, and sharpness
- view basic file information
- export an edited JPEG

## Run

Open the package in Xcode:

```sh
open Package.swift
```

Or build it from the command line:

```sh
swift build
```

This is an MVP skeleton. The next serious pieces are crop, faster preview caching, batch export, and a more complete RAW/color pipeline.
