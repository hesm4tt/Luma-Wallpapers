# Luma

Luma is a focused iPhone app for importing `.tendies` wallpaper packs and installing their PosterBoard descriptors. It has a light blue glass interface, a local library, and an activity view that reports each stage of applying or resetting wallpapers.

## SideStore source

Copy this link into SideStore's Sources screen:

```text
https://raw.githubusercontent.com/hesm4tt/Luma-Wallpapers/main/source.json
```

The IPA is also available under [Releases](https://github.com/hesm4tt/Luma-Wallpapers/releases). It is ad-hoc signed only to carry the requested entitlement; you must sign it with a provisioning profile and sideload it. **The signing method must preserve and provision an App Group**. Luma detects the first usable signed App Group. Some signing methods strip this entitlement or cannot provision it, in which case applying wallpapers will fail. SideStore installation and App Group provisioning have not been tested here.

Luma uses an undocumented sandbox escape, `worse_query`, and writes to PosterBoard. The published exploit lists iOS 26 and 27 support, but this app has not been tested on a physical device, including iOS 27.0.1. Back up your phone before using it and only import files you trust. A malformed or incompatible wallpaper may cause instability. Luma does not claim to be a jailbreak.

## Using Luma

Import a `.tendies` archive, select it, and tap Apply. The Activity sheet shows container scanning, access requests, descriptor copies, and errors; you can copy the log. After applying, restart the iPhone and check the Lock Screen wallpaper picker. Container detection can take time. Reset removes only descriptors recorded as installed by Luma. Deleting an import does not remove applied descriptors. Reinstalling may erase the reset record, and a crash between a copy and its record can leave an untracked descriptor.

The importer accepts ZIP-based `.tendies` files containing one recognizable descriptor folder, with up to 15 descriptors and 1 GB uncompressed. Formats vary; some files may not import.

## Build

Open `LumaTendies.xcodeproj` in Xcode. Set a team, unique bundle identifier, and a matching provisioned App Group in `App/Luma.entitlements`, then build for iOS. ZIPFoundation is vendored. To build an unsigned archive, run `xcodebuild -project LumaTendies.xcodeproj -scheme LumaTendies -configuration Release -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`. The build still needs to be packaged into `Payload/LumaTendies.app` and signed for installation.

The importer smoke checks can be run with `swift run --package-path Tests/ImporterChecks` on macOS. They cover a valid archive, empty and malformed input, traversal, truncation, and staging cleanup. They do not exercise device installation.

## Credits and license

Luma's app code is distributed under GPL-3.0-or-later. It includes `worse_query` and `pathleak` by forcequit and contributors, also GPL-3.0-or-later; their source and license are included. ZIPFoundation by Thomas Zoechling is MIT licensed; its source and license are under `Vendor/ZIPFoundation`. The Luma icon was created for this project.
