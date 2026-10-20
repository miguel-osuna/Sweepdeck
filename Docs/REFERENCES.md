# API and design references

Reviewed during implementation, 2026-10-19. No source from these projects was copied.

- [Apple FileManager.trashItem](https://developer.apple.com/documentation/foundation/filemanager/trashitem(at:resultingitemurl:)):
  supported Finder-style Trash operation; the installed SDK header documents
  success/failure and the resulting URL when a collision requires renaming.
- [Apple NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator):
  coordinates filesystem access with cooperating file presenters. Not an atomic
  protection against all concurrent local processes.
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app-sandbox):
  reviewed as an alternative deployment model; see DESIGN.md for the local MVP choice.
- [Mole](https://github.com/tw93/Mole): command-line cleanup/disk/health feature
  organization. CLI repository is GPL-3.0; native products are separate. Inspiration
  only; no code or shell commands incorporated.
- [Pearcleaner](https://github.com/alienator88/Pearcleaner): native review-oriented
  application cleanup. Repository identifies fair-code/source-available licensing.
  No implementation copied and no license compatibility assumed.
- [Stats license](https://github.com/exelban/stats/blob/master/LICENSE): MIT. Used
  as a reference for the category of useful metrics, not as a code dependency.
- [GitHub macOS 15 runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md):
  lists Xcode 26 installations. Workflow selects an installed Swift 6.2 toolchain;
  a runner listing is not evidence that our workflow has executed.
- [SwiftPM contributing guide](https://github.com/swiftlang/swift-package-manager/blob/main/CONTRIBUTING.md):
  documents `SWIFTPM_CUSTOM_LIBS_DIR`, used only for a detected stale manifest
  interface in a local copy.

Installed SDK headers were also inspected for Mach statistics and filesystem
interfaces. OS compatibility claims are limited to recorded test evidence.
