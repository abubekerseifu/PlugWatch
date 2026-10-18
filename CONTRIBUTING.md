# Contributing to PlugWatch

Thanks for helping improve PlugWatch.

## Development setup

1. Clone the repo and open `PlugWatch.xcodeproj` in Xcode 15+
2. Select the **PlugWatch** scheme and run (macOS 14+ target)
3. Prefer a **Debug** build while iterating — the default unplugged threshold is shortened for faster testing

## Coding guidelines

- Keep power monitoring **event-driven** (IOKit notifications). Do not add polling timers for AC/battery state.
- Habit and history timers should use **one-shot deadline** sources (`DispatchSourceTimer`), not 1 Hz clocks in the background.
- Sleep must **pause** awake-time accrual (`NSWorkspace.willSleepNotification` / `didWakeNotification`).
- Prefer small, focused pull requests with a clear description and test notes.
- Do not commit `build/`, DerivedData, signing certificates, or personal `power_history.json` data.

## Pull requests

1. Fork and create a branch (`feature/…` or `fix/…`)
2. Make your changes and verify Release still builds:

   ```bash
   xcodebuild -project PlugWatch.xcodeproj -scheme PlugWatch \
     -configuration Release -derivedDataPath build \
     CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO
   ```

3. Open a PR using the template; link related issues when applicable

## Issues

Use the bug / feature templates under `.github/ISSUE_TEMPLATE/`. Include macOS version and steps to reproduce for bugs.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
