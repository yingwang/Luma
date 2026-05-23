# Luma

Luma is a native macOS photo-editing prototype built with SwiftUI and Core Image.

The first version focuses on a local workflow:

- import local images
- browse thumbnails
- preview the selected photo
- compare before and after
- rotate photos
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

This is an MVP skeleton. The next serious pieces are a persistent catalog, faster preview caching, crop, and a more complete RAW/color pipeline.
