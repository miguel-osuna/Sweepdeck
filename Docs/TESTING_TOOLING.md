# Sweepdeck testing tools

Reviewed 2026-10-20 against the package manifest, test script, CI workflow,
appearance tests, and current official Apple and project documentation.

## What is already in place

- Swift logic and appearance tests use Apple's Swift Testing framework
  (`@Test`, `#expect`) and run through Swift Package Manager.
- The current appearance test hosts a synthetic `NavigationSplitView` and checks
  color-scheme values plus rendered-image equality. A control run against the
  unchanged PR implementation passes, so it does not reproduce the reported
  mixed sidebar/detail appearance and cannot prove that bug is fixed. An
  exploratory offscreen render of the real `ContentView` also omitted the native
  sidebar material; its remaining pixel differences came from the selected
  Appearance segment. The production visual issue is still unverified.
- The Rust crate already uses Cargo's built-in test runner, `rustfmt`, and
  Clippy. The shared test script runs these before Swift tests, and CI runs the
  test suite on multiple macOS/Swift toolchains with a core coverage floor.

Swift Testing is Apple's modern choice for unit and integration tests and works
with both Swift packages and Xcode projects. Apple recommends keeping most
coverage in fast logic tests, with fewer end-to-end UI tests for important
workflows. [Swift Testing](https://developer.apple.com/documentation/testing/),
[Apple's testing overview](https://developer.apple.com/documentation/xcode/testing)

## Best next additions

1. **Use XCTest + XCUIAutomation for a few real UI workflows.** This is Apple's
   native way to launch the app, click controls, inspect accessibility state,
   and catch regressions that view-model tests cannot. Good first journeys are
   changing Dark → System, selecting an authorized test folder and seeing scan
   progress/cancellation, and reviewing a cleanup plan before its confirmation
   step. Keep these few and focused because UI tests take longer and are more
   sensitive to timing. [XCUIAutomation](https://developer.apple.com/documentation/xcuiautomation),
   [Adding tests to an Xcode project](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project)

   The project currently builds and tests with SwiftPM and has no Xcode UI-test
   target. Adding XCUIAutomation therefore means adding Xcode test-project
   wiring as well as the tests; the app's Rust static library build/link step
   must be included in that target. Until that is in place, the existing SwiftPM
   tests remain the simplest reliable workflow.

2. **Use XcodeGen only if we add a real UI-test project.** XcodeGen generates an
   Xcode project from a readable `project.yml`, so app and UI-test target wiring
   can be reviewed like normal code instead of maintained only in Xcode's
   project editor. It is a developer tool, not a test framework or app runtime
   dependency. The generated app target would still need to invoke and link the
   Rust static library correctly, so this adds value only when we commit to
   XCUIAutomation tests. [XcodeGen](https://github.com/yonaskolb/XcodeGen)

3. **Add a visible-window UI regression for the appearance bug.** The offscreen
   Swift Testing render does not reproduce the user's mixed sidebar/detail
   screenshot. A small macOS XCUITest should launch the production app, switch
   Dark → System under a controlled system appearance, and attach a screenshot
   of the actual app window. Compare the sidebar and detail regions while
   masking the selected segmented-control state. Keep it on one stable macOS CI
   lane first; retain the faster Swift Testing checks for scheme propagation.
   Point-Free's
   `swift-snapshot-testing` can save and compare reference outputs, supports
   Swift Testing, and allows custom strategies. Its built-in image strategies
   are not a turnkey fit for every macOS `NSView`/SwiftUI rendering setup, and
   image scale/rendering differences can make baselines noisy. Start with
   transition-to-transition image comparison and saved test attachments before
   adopting a checked-in golden image. [SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing),
   [custom strategies](https://github.com/pointfreeco/swift-snapshot-testing/blob/main/Sources/SnapshotTesting/Documentation.docc/Articles/CustomStrategies.md),
   [macOS view scale discussion](https://github.com/pointfreeco/swift-snapshot-testing/issues/428)

4. **Optionally add `swift format lint --strict` to CI.** `swift-format` is
   included with Swift 6 toolchains, so this adds no app dependency and can
   standardize Swift style. Agree on a configuration before enabling strict
   checks so existing files do not create avoidable CI noise.
   [swift-format](https://github.com/swiftlang/swift-format)

## Recommendation

Do not add a third-party snapshot dependency yet. Keep Swift Testing and Cargo
for fast tests, add `swift-format` linting when the team wants consistent
formatting, and add a small XCTest/XCUIAutomation target for the high-value
appearance transition and cleanup-confirmation journeys. XcodeGen is an optional
way to keep that project's configuration readable. The existing offscreen
appearance test is useful for scheme propagation only; it is not visual proof
of the reported production issue.
