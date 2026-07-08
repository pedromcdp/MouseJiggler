# Contributing to MouseJiggler

Thanks for considering it — this is a small, personal-scale project, so the
process is intentionally lightweight.

## Getting set up

1. Fork and clone the repo
2. Make sure you have the Xcode Command Line Tools: `xcode-select --install`
3. Build it: `chmod +x build.sh scripts/make_icon.sh && ./build.sh`
4. Run it from `build/MouseJiggler.app`, or move it to `/Applications` like
   the main README describes

There's no Xcode project file — the whole thing builds via `swiftc` in
`build.sh`. If you want to iterate in Xcode itself for autocomplete/debugging,
you can create a new macOS App project, add the existing files under
`Sources/` and `Resources/` to it, and set the bundle identifier and
`LSUIElement` in its own generated Info.plist to match `Resources/Info.plist`.
This isn't checked into the repo since it'd conflict with the plain
`swiftc`-based build.

## Before opening a PR

- Test on real hardware — there's no simulator for a menu bar utility, and
  the schedule/idle-detection logic in particular is easy to get subtly
  wrong without testing against the wall clock and actual mouse/keyboard input.
- Keep changes focused. Small, single-purpose PRs are much easier to review
  than ones that touch UI, settings schema, and build tooling all at once.
- If you change `AppSettings` in `Models.swift` (add/remove/rename a field),
  say so explicitly in the PR description — existing users' saved
  preferences will silently reset to defaults on next launch, since decoding
  fails closed rather than crashing. That's expected, but worth calling out
  each time it happens.
- Match the existing style: `Form` + `.formStyle(.grouped)` + `LabeledContent`
  for settings rows, colored `SettingsIcon` tiles rather than plain
  monochrome SF Symbols, no `NavigationSplitView` (it caused real layout bugs
  in this app's fixed-size window — see git history if curious).
- **Adding user-facing text?** Add the English key to
  `Resources/en.lproj/Localizable.strings` and (ideally) the Portuguese
  translation to `Resources/pt-PT.lproj/Localizable.strings`. One gotcha:
  SwiftUI only auto-localizes a string *literal* written directly at the
  call site (`Text("Foo")`); a string that arrives via a variable or
  property (`Text(someTitle)`, loop variables in `ForEach`, etc.) silently
  skips localization unless wrapped explicitly:
  `Text(LocalizedStringKey(someTitle))`. `RowLabel` and the interval/threshold
  pickers already do this — follow that pattern for new variable-sourced
  text. For `NSMenuItem` titles (AppKit, not SwiftUI), there's no automatic
  path at all — always wrap with `NSLocalizedString(_:comment:)`.

## Reporting bugs

Screenshots or screen recordings help enormously, especially for anything
visual. If it's layout-related, a screenshot with the window dragged over
plain desktop (no other windows/widgets behind it) makes it much easier to
tell a real bug apart from something else on screen.

## Ideas / feature requests

Check the Roadmap section in the README first — if it's already listed,
feel free to comment on interest or take a stab at it. Otherwise, open an
issue describing the use case before jumping straight to a PR, just so we're
aligned on approach first.
