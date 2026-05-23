# Luma

Luma is a native macOS photo-editing prototype built with SwiftUI and Core Image.

The first version focuses on a local workflow:

- import local images
- browse thumbnails
- preview the selected photo
- adjust exposure, contrast, saturation, and warmth
- export an edited JPEG

## Run

Open the package in Xcode:

```sh
open /Users/ying/claude/Luma/Package.swift
```

Or build it from the command line:

```sh
swift build
```

This is an MVP skeleton. The next serious pieces are a persistent catalog, faster preview caching, crop/rotate, and a more complete RAW/color pipeline.
