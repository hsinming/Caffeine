# ahk-ctx-ui Section Index

Per-heading detail for the routing table in `SKILL.md`. Find the row for the task, `grep -n "^## heading text"` the Reference module, and read that section through the next heading of the same level.

`## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` cover most routine tasks. Load a TIER section only when a complete, runnable example is needed.

### GUI Basics (Module_GuiBasics.md)

| Task | Grep for heading |
|------|-----------------|
| v1 → v2 GUI changes | `## V1 → V2 BREAKING CHANGES` |
| All Gui / GuiControl API | `## API QUICK-REFERENCE` |
| `Gui()` + `Show`/`Hide`/`Destroy`/`Submit`/`Opt`/`SetFont` | `### Gui Constructor and Window Methods` |
| `.Title`, `.BackColor`, `.MarginX`, `myGui[name]` | `### Gui Properties` |
| `AddText`/`AddEdit`/`AddCheckBox`/`AddComboBox`… and `.Value` meaning | `### Control Add Methods (common)` |
| `.OnEvent`, `.Move`, `.Focus`, `.Choose` | `### GuiControl Methods` |
| `.Value`, `.Text`, `.Enabled`, `.Name` | `### GuiControl Properties` |
| `GuiFromHwnd`, `GuiCtrlFromHwnd` | `### Helper Functions` |
| Callback parameters, binding, new-thread rule, arrow limits | `## EVENTS AND CALLBACKS` |
| What `Submit()` stores | `### Submit Rules` |
| When a Gui is destroyed | `### Lifetime` |
| Constraints, QA checks and anti-patterns | `## AHK V2 CONSTRAINTS` |
| Error → cause mapping | `## RUNTIME ERROR MAPPING` |
| **Example** — minimal window | `## TIER 1 — Minimal Window` |
| **Example** — class form with bound handlers | `## TIER 2 — Class-Based Form with Bound Handlers` |
| **Example** — show/hide toggle | `## TIER 3 — Show/Hide Toggle from a Hotkey` |

---

### ListView, TreeView, StatusBar, Tab3 (Module_GuiListViewTreeView.md)

| Task | Grep for heading |
|------|-----------------|
| ListView methods (`Add`, `Modify`, `Delete`, `GetNext`, `GetText`, `ModifyCol`) | `### ListView Methods` |
| TreeView methods (`Add`, `GetNext`, `GetSelection`, `GetParent`) | `### TreeView Methods` |
| StatusBar (`SetText`, `SetParts`, `SetIcon`) | `### StatusBar Methods` |
| Tab3 (`UseTab`) | `### Tab3 Methods` |
| Constraints, QA checks and anti-patterns (1-based rows, GetNext RowType, delete loop) | `## AHK V2 CONSTRAINTS` |
| Runtime errors | `## RUNTIME ERROR MAPPING` |
| **Example** — ListView CRUD + delete selected | `## TIER 1 — ListView CRUD` |
| **Example** — TreeView build and traverse | `## TIER 2 — TreeView Build and Traverse` |
| **Example** — StatusBar and tabs | `## TIER 3 — StatusBar and Tabs` |

---

### Owned Windows and Modal Dialogs (Module_GuiOwnedWindows.md)

| Task | Grep for heading |
|------|-----------------|
| `+Owner`, `+Disabled`, `+OwnDialogs`, `WinWaitClose` | `## API QUICK-REFERENCE` |
| Constraints, QA checks and anti-patterns: close order and cleanup | `## AHK V2 CONSTRAINTS` |
| **Example** — event-driven settings dialog | `## TIER 1 — Event-Driven Settings Dialog` |
| **Example** — blocking confirm dialog with return value | `## TIER 2 — Blocking Confirm Dialog That Returns a Value` |

---

### GUI Layout (Module_GuiLayout.md)

| Task | Grep for heading |
|------|-----------------|
| `xm`, `x+n`, `xp`, `Section`/`xs`/`ys`, default positions | `### Position Options (Gui.Add Options string)` |
| Margins, `+Resize`, `+MinSize`, DPI scaling, `Size` event, `Move` | `### Window Sizing and Scaling` |
| Constraints, QA checks and anti-patterns | `## AHK V2 CONSTRAINTS` |
| **Example** — automatic positioning with sections | `## TIER 1 — Automatic Positioning with Sections` |
| **Example** — resizable window | `## TIER 2 — Resizable Window (Size Event)` |
| **Example** — GuiForm explicit coordinates, button rows | `## TIER 3 — GuiForm Explicit Coordinates (repository pattern)` |
| **Example** — equal columns, LayoutCalculator | `## TIER 4 — N Equal Columns and a Validating Layout Calculator (repository pattern)` |

---

### Window Management (Module_WindowManagement.md)

| Task | Grep for heading |
|------|-----------------|
| v1 → v2 changes | `## V1 → V2 BREAKING CHANGES` |
| `ahk_id` vs pure HWND, `ahk_exe`, match mode, hidden windows | `### WinTitle Criteria` |
| `WinExist`, `WinWait*`, `WinActivate`, `WinClose`, min/max | `### Existence, Wait and State` |
| `WinGetTitle`/`Class`/`ProcessName`/`PID`/`Pos`/`List`/`Style` | `### Metadata` |
| `WinMove`, `WinSetAlwaysOnTop`, `WinSetTransparent`, `WinSetTitle` | `### Mutation` |
| `GroupAdd`, `GroupActivate`, `ahk_group` | `### Window Groups` |
| Constraints, QA checks and anti-patterns (TargetError contract, per-thread settings) | `## AHK V2 CONSTRAINTS` |
| Runtime errors | `## RUNTIME ERROR MAPPING` |
| **Example** — existence, activation, waiting | `## TIER 1 — Existence, Activation, Waiting` |
| **Example** — metadata and enumeration | `## TIER 2 — Metadata and Enumeration` |
| **Example** — groups and batch operations | `## TIER 3 — Groups and Batch Operations` |
| **Example** — HWND wrapper class | `## TIER 4 — HWND-Anchored Wrapper Class` |
| Snippets (`WaitAndActivate`, `ForEachWindow`) | `## DROP-IN RECIPES` |

---

### Control Interaction (Module_ControlInteraction.md)

| Task | Grep for heading |
|------|-----------------|
| v1 → v2 changes | `## V1 → V2 BREAKING CHANGES` |
| `ControlClick`, `ControlSend(Text)`, `ControlFocus`, `ControlGetPos` | `### Interaction` |
| Text, ListBox/ComboBox items, checkboxes | `### Text and Item Data` |
| Constraints, QA checks and anti-patterns (1-based, CoordMode not used, own Gui vs other programs) | `## AHK V2 CONSTRAINTS` |
| Runtime errors | `## RUNTIME ERROR MAPPING` |
| **Example** — click, send, focus | `## TIER 1 — Click, Send, Focus` |
| **Example** — list/checkbox data | `## TIER 2 — ListBox / ComboBox / Checkbox Data` |

---

### Window Event Hooks (Module_WinEventHook.md)

| Task | Grep for heading |
|------|-----------------|
| `CallbackCreate`, `SetWinEventHook`, constants | `## API QUICK-REFERENCE` |
| Constraints, QA checks and anti-patterns: lifetime, binding, no "Fast" | `## AHK V2 CONSTRAINTS` |
| **Example** — WinEventMonitor class | `## TIER 1 — WinEventMonitor Class` |

---

### Hotkeys and Hotstrings (Module_HotkeysAndHotstrings.md)

| Task | Grep for heading |
|------|-----------------|
| v1 → v2 changes | `## V1 → V2 BREAKING CHANGES` |
| `::` syntax, prefixes `~ $ * & up`, hotstring options | `### Hotkey Syntax` |
| `Hotkey()`, `HotIf()`, `HotIfWin…`, `#HotIf`, `Hotstring()` | `### Hotkey() and HotIf()` |
| `A_ThisHotkey`, `A_PriorHotkey`, `A_EndChar` | `### Built-in Variables` |
| Hook installation and `#HotIf` evaluation facts | `## FACTS ABOUT HOOKS AND #HotIf` |
| Constraints, QA checks and anti-patterns | `## AHK V2 CONSTRAINTS` |
| Runtime errors | `## RUNTIME ERROR MAPPING` |
| **Example** — static hotkeys and hotstrings | `## TIER 1 — Static Hotkeys and Hotstrings` |
| **Example** — dynamic `Hotkey()` | `## TIER 2 — Dynamic Hotkeys with Hotkey()` |
| **Example** — `#HotIf` and `HotIf()` | `## TIER 3 — Context Sensitivity: #HotIf and HotIf()` |
| **Example** — class-managed hotkeys | `## TIER 4 — Class-Managed Hotkeys` |
| Snippet (`ContextHotkey`) | `## DROP-IN RECIPES` |

---

### Send, Mouse, Key State, InputHook (Module_SendAndInputHook.md)

| Task | Grep for heading |
|------|-----------------|
| v1 → v2 changes | `## V1 → V2 BREAKING CHANGES` |
| `Send`/`SendText`/`SendMode`/`SetKeyDelay`/`BlockInput` | `### Sending Keys` |
| `Click`, `MouseMove`, `MouseClick(Drag)`, `MouseGetPos` | `### Mouse` |
| `GetKeyState`, `KeyWait` | `### Key State` |
| `InputHook` options, properties, callbacks | `### InputHook` |
| Constraints, QA checks and anti-patterns | `## AHK V2 CONSTRAINTS` |
| Runtime errors | `## RUNTIME ERROR MAPPING` |
| **Example** — send modes | `## TIER 1 — Send Modes` |
| **Example** — mouse | `## TIER 2 — Mouse` |
| **Example** — key state and waiting | `## TIER 3 — Key State and Waiting` |
| **Example** — InputHook | `## TIER 4 — InputHook` |

---

### Screen Coordinates and Monitors (Module_ScreenCoordinates.md)

| Task | Grep for heading |
|------|-----------------|
| `CoordMode`, `A_Screen*`, `MonitorGet*`, `SysGet` | `## API QUICK-REFERENCE` |
| Constraints, QA checks and anti-patterns: per-thread CoordMode rule, primary-only variables | `## AHK V2 CONSTRAINTS` |
| **Example** — CoordMode and primary screen | `## TIER 1 — CoordMode and Primary Screen` |
| **Example** — monitors and work areas | `## TIER 2 — Monitors and Work Areas` |
| **Example** — resolution-independent coordinates | `## TIER 3 — Resolution-Independent Coordinates` |

---

### Pixel and Image Search (Module_PixelAndImageSearch.md)

| Task | Grep for heading |
|------|-----------------|
| v1 → v2 changes | `## V1 → V2 BREAKING CHANGES` |
| `PixelGetColor`, `PixelSearch`, `ImageSearch` + options | `## API QUICK-REFERENCE` |
| Constraints, QA checks and anti-patterns (Boolean return, blank outputs, visibility, color compare) | `## AHK V2 CONSTRAINTS` |
| **Example** — pixel color, wait for pixel | `## TIER 1 — Pixel Color` |
| **Example** — PixelSearch and ImageSearch | `## TIER 2 — PixelSearch and ImageSearch` |
| **Example** — wait for image on any monitor | `## TIER 3 — Wait for an Image on Any Monitor` |

---

### Screen Overlays (Module_ScreenOverlays.md)

| Task | Grep for heading |
|------|-----------------|
| Overlay Gui options, `WinSetTransColor` vs `WinSetTransparent` | `## API QUICK-REFERENCE` |
| Constraints, QA checks and anti-patterns (DPI, cleanup) | `## AHK V2 CONSTRAINTS` |
| **Example** — overlay class marking an ImageSearch hit | `## TIER 1 — Overlay Class` |
| **Example** — overlay across all monitors | `## TIER 2 — Overlay Across All Monitors` |
