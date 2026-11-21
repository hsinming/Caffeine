# Module_GuiOwnedWindows.md
<!-- DOMAIN: GUI — multi-window, owner/owned, modal dialogs -->
<!-- SCOPE: +Owner relationships, disabling/re-enabling the owner, modal dialog patterns (event-driven and blocking), +OwnDialogs for MsgBox/InputBox/FileSelect. Not covered: single-window Gui API (Module_GuiBasics.md), layout (Module_GuiLayout.md). -->
<!-- TRIGGERS: "+Owner", "+OwnDialogs", "+Disabled", "modal dialog", "owned window", "settings dialog", "child window", "dialog returns a value", "confirm dialog" -->
<!-- CONSTRAINTS: Re-enable the owner (Opt("-Disabled")) BEFORE hiding or destroying the owned window. +Owner can be set before or after the owned window is created. Owned windows are destroyed with their owner only when the owner belongs to the same process. -->
<!-- CROSS-REF: Module_GuiBasics.md, Module_GuiLayout.md, Module_ClassBasics.md -->
<!-- VERSION: AHK v2.0+ -->

## API QUICK-REFERENCE

| Option / call | Effect (from the Gui docs) |
|---------------|----------------------------|
| `child.Opt("+Owner" parent.Hwnd)` | `child` becomes owned by `parent`: no taskbar button by default, always on top of its owner when visible, destroyed automatically when the owner is destroyed (if the owner is in the same process). Can be used before or after the owned window is created. |
| `myGui.Opt("+Owner")` | Owned by the script's main window — a simple way to hide the taskbar button |
| `parent.Opt("+Disabled")` | User cannot interact with the owner while the owned window is open |
| `parent.Opt("-Disabled")` | Re-enable; do this **before** cancelling/destroying the owned window so the owner is reactivated automatically |
| `myGui.Opt("+OwnDialogs")` | Per thread: subsequent `MsgBox`/`InputBox`/`FileSelect`/`DirSelect` in this thread are owned by (and modal to) the Gui. Call it in each event handler that shows such a dialog. |
| `WinWaitClose(dlg.Hwnd)` | Blocks the current thread until the dialog is destroyed **or hidden** (WinWait/WinWaitClose obey DetectHiddenWindows even for a pure HWND) |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- Disable the owner when the dialog opens. Order on close: `owner.Opt("-Disabled")` first, then `dialog.Hide()` / `dialog.Destroy()` (documented on the `+Owner` option).
  ✗ `dlg.Destroy()` then `owner.Opt("-Disabled")` → ✓ `owner.Opt("-Disabled")` then `dlg.Destroy()`
- Route every close path (OK, Cancel, `Close` event, `Escape`) through one cleanup method so the owner is always re-enabled.
  ✗ cleanup only in the OK handler → ✓ one cleanup for every close path
- Deliver the dialog result by callback or by a blocking wait — not by polling with no exit.
- **Repository convention:** track an open dialog with an object reference (e.g. `this.dialog`), not a title search, to prevent duplicates.
  ✗ new dialog on every click → ✓ keep a reference; return if open
- `+OwnDialogs` is per thread; setting it once at startup does not affect later event threads.
  ✗ `myGui.Opt("+OwnDialogs")` once → ✓ call it in the handler thread that shows the MsgBox

## TIER 1 — Event-Driven Settings Dialog

```ahk
#Requires AutoHotkey v2.0

MainWindow()

class MainWindow {
    __New() {
        this.gui := Gui("+Resize", "Main Window")
        this.dialog := ""
        this.gui.AddButton("w180", "Open Settings…").OnEvent("Click", this.OpenSettings.Bind(this))
        this.gui.Show("w300 h100")
    }

    OpenSettings(*) {
        if IsObject(this.dialog)                    ; already open
            return
        this.gui.Opt("+Disabled")
        dlg := Gui("+Owner" this.gui.Hwnd, "Settings")
        dlg.AddText("w220", "Settings for the application.")
        dlg.AddButton("w100 Default", "OK").OnEvent("Click", this.CloseSettings.Bind(this))
        dlg.AddButton("x+8 w100", "Cancel").OnEvent("Click", this.CloseSettings.Bind(this))
        dlg.OnEvent("Close", this.CloseSettings.Bind(this))
        dlg.OnEvent("Escape", this.CloseSettings.Bind(this))
        this.dialog := dlg
        dlg.Show()
    }

    CloseSettings(*) {
        this.gui.Opt("-Disabled")                  ; re-enable the owner first
        if IsObject(this.dialog) {
            this.dialog.Destroy()
            this.dialog := ""
        }
        return true                                 ; also stops default Close handling
    }
}
```

## TIER 2 — Blocking Confirm Dialog That Returns a Value

```ahk
#Requires AutoHotkey v2.0

; Returns "OK" or "" (cancelled). Blocks the calling thread with WinWaitClose.
ConfirmDialog(ownerGui, title, message) {
    result := ""
    dlg := Gui("+Owner" ownerGui.Hwnd, title)
    dlg.AddText("w300", message)
    dlg.AddButton("w145 Default", "OK").OnEvent("Click", (*) => (result := "OK", Finish()))
    dlg.AddButton("x+10 w145", "Cancel").OnEvent("Click", (*) => Finish())
    dlg.OnEvent("Close", (*) => Finish())
    dlg.OnEvent("Escape", (*) => Finish())

    ownerGui.Opt("+Disabled")
    dlg.Show()
    WinWaitClose(dlg.Hwnd)                          ; returns when the dialog is destroyed or hidden
    return result

    Finish() {                                      ; nested function captures ownerGui, dlg
        ownerGui.Opt("-Disabled")                   ; re-enable owner before destroying
        dlg.Destroy()
    }
}

main := Gui(, "Owner")
main.AddButton("w200", "Delete item").OnEvent("Click", AskDelete)
main.Show()

AskDelete(btn, *) {
    if ConfirmDialog(btn.Gui, "Confirm", "Delete this item?") = "OK"
        MsgBox("Deleted.")
}
```

## SEE ALSO

- `Module_GuiBasics.md` — Gui API, events, binding.
- `Module_GuiLayout.md` — positioning the dialog's controls.
