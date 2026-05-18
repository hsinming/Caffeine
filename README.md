# Caffeine

A lightweight AutoHotkey v2 script that prevents Windows from sleeping or turning off the display — similar to macOS's `caffeinate` command.

## Requirements

- Windows
- [AutoHotkey v2](https://www.autohotkey.com/)

## Usage

### Run as script

Double-click `caffeine.ahk`, or run from the command line:

```
AutoHotkey.exe caffeine.ahk
```

The script starts immediately and runs in the system tray. To stop it, right-click the tray icon and select **Stop & Exit**. Power management is restored automatically on exit.

### Compile to executable

Run the build script:

```
.\build.ps1
```

This compiles `caffeine.ahk` into `Caffeine.exe` using Ahk2Exe. The `.ico` file and version metadata are embedded automatically via compiler directives.

## How It Works

Calls the Win32 `SetThreadExecutionState` API with `ES_CONTINUOUS | ES_DISPLAY_REQUIRED` to block sleep and display timeout. A timer refreshes this state every 30 seconds. On exit, the flag is cleared so Windows resumes normal power management.

## License

See [LICENSE](LICENSE).