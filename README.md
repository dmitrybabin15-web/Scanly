# Scanly

Scanly is a native iPhone expense tracker built with SwiftUI. It can capture or import receipts, recognize text with Apple Vision, let users review and edit extracted details, and organize expenses with summaries and CSV/PDF exports. RevenueCat is used for subscription management.

## Requirements

- Xcode 15 or newer
- iOS 16 or newer

## Build

1. Open `Scanly.xcodeproj` in Xcode.
2. Select the `Scanly` scheme and an iPhone simulator or device.
3. Build and run. Swift Package Manager resolves the RevenueCat dependency from the project.

The simulator build can also be checked from the command line:

```sh
xcodebuild -project Scanly.xcodeproj -scheme Scanly -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

## Optional service configuration

- Set `REVENUECAT_API_KEY` in the Xcode Run scheme to test subscriptions.
- Set `ANTHROPIC_API_KEY` in the Xcode Run scheme to enable optional receipt-field parsing from OCR text.

These values are intentionally not included in the repository. Do not embed an Anthropic key in a distributed app; use a secured backend for production AI requests.

## Project contents

- `Scanly/` — SwiftUI screens, receipt/OCR flow, persistence, exports, localization, and app resources.
- `Scanly.xcodeproj/` — Xcode project and Swift Package Manager lockfile.
- `docs/RELEASE_CHECKLIST.md` — App Store preparation and device QA checklist.

The repository contains source and demo preview data only; user receipts and local Xcode settings are not part of the source tree.
