# Module_GuiListViewTreeView.md
<!-- DOMAIN: GUI — list and tree controls -->
<!-- SCOPE: ListView (rows, columns, selection, delete loops), TreeView (item IDs, traversal), StatusBar (parts, text, icons), Tab3 (UseTab). Not covered: basic Gui/GuiControl API and event binding (Module_GuiBasics.md), layout math (Module_GuiLayout.md), reading list controls in other programs (Module_ControlInteraction.md). -->
<!-- TRIGGERS: AddListView(), AddTreeView(), AddStatusBar(), AddTab3(), LV.Add(), LV.Modify(), LV.Delete(), LV.GetNext(), LV.GetText(), LV.ModifyCol(), TV.Add(), TV.GetNext(), TV.GetSelection(), SetParts(), SetText(), UseTab(), "listview rows", "treeview nodes", "status bar", "tab control", "delete selected rows" -->
<!-- CONSTRAINTS: ListView row and column numbers are 1-based (row 0 in GetText = header text). LV.GetNext RowType is omitted (selected), "C"/"Checked" or "F"/"Focused" — there is no "Selected" value. Deleting rows shifts later row numbers. Keep TreeView item IDs returned by TV.Add. -->
<!-- CROSS-REF: Module_GuiBasics.md, Module_GuiLayout.md, Module_ControlInteraction.md -->
<!-- VERSION: AHK v2.0+ -->

## API QUICK-REFERENCE

### ListView Methods

| Method | Signature | Returns | Notes |
|--------|-----------|---------|-------|
| `AddListView()` | `myGui.AddListView(Options?, ColumnTitlesArray?)` | GuiControl | e.g. `AddListView("w400 h200 Grid", ["Name", "Size"])` |
| `.Add()` | `.Add(Options?, Col1?, Col2?, …)` | New row number | Options such as `"Select Focus Vis Check"` |
| `.Insert()` | `.Insert(RowNumber, Options?, Col1?, …)` | New row number | Insert at a position |
| `.Modify()` | `.Modify(RowNumber, Options?, NewCol1?, …)` | — | `RowNumber` 0 = all rows, e.g. `.Modify(0, "-Select")` |
| `.Delete()` | `.Delete(RowNumber?)` | — | Omit to delete all rows |
| `.ModifyCol()` | `.ModifyCol(ColumnNumber?, Options?, ColumnTitle?)` | — | No arguments = auto-size every column to its contents; `"Integer"` sets numeric sorting |
| `.InsertCol()` / `.DeleteCol()` | `(ColumnNumber, …)` | — | Use these, not raw SendMessage |
| `.GetCount()` | `.GetCount(Mode?)` | Integer | Omit = rows; `"S"`/`"Selected"`; `"Col"`/`"Column"` |
| `.GetNext()` | `.GetNext(StartingRowNumber?, RowType?)` | Row number or 0 | `RowType` omitted = next **selected** row; `"C"`/`"Checked"`; `"F"`/`"Focused"` |
| `.GetText()` | `.GetText(RowNumber, ColumnNumber := 1)` | String | Row 0 returns the column header text |
| `.SetImageList()` | `.SetImageList(ImageListID, IconType?)` | Previous ID | Icons for rows |

ListView events (via `OnEvent`): `Click`, `DoubleClick` (receive the row number), `ColClick`, `ItemSelect`, `ItemCheck`, `ItemFocus`, `ItemEdit`, `ContextMenu`.

### TreeView Methods

| Method | Signature | Returns | Notes |
|--------|-----------|---------|-------|
| `AddTreeView()` | `myGui.AddTreeView(Options?)` | GuiControl | |
| `.Add()` | `.Add(Name, ParentItemID := 0, Options?)` | Item ID | Parent `0` = top level; options e.g. `"Expand"`, `"Select"`, `"Vis"`, `"Bold"`, `"Icon4"` |
| `.Modify()` | `.Modify(ItemID, Options?, NewName?)` | Item ID | |
| `.Delete()` | `.Delete(ItemID?)` | — | Omit to delete all items |
| `.GetSelection()` | `()` | Item ID or 0 | |
| `.GetParent()` / `.GetChild()` / `.GetPrev()` | `(ItemID)` | Item ID or 0 | |
| `.GetNext()` | `.GetNext(ItemID := 0, ItemType?)` | Item ID or 0 | Omitted type = next sibling; `"Full"`/`"F"` = next item in the whole tree; `"Checked"`/`"C"` |
| `.GetText()` | `.GetText(ItemID)` | String | |
| `.GetCount()` | `()` | Integer | Total items |
| `.Get()` | `.Get(ItemID, Attribute)` | Item ID or 0 | e.g. `"Expand"`, `"Check"`, `"Bold"` state tests |

### StatusBar Methods

| Method | Signature | Returns | Notes |
|--------|-----------|---------|-------|
| `AddStatusBar()` | `myGui.AddStatusBar(Options?, Text?)` | GuiControl | Docked at the bottom |
| `.SetText()` | `.SetText(NewText, PartNumber := 1, Style := 0)` | — | Style `0` sunken border, `1` no border, `2` raised |
| `.SetParts()` | `.SetParts(Width1?, …, Width255?)` | Status bar HWND | Widths of every part except the last (the last fills the rest); no arguments = one part |
| `.SetIcon()` | `.SetIcon(FileName, IconNumber := 1, PartNumber := 1)` | HICON | |

### Tab3 Methods

| Method | Signature | Notes |
|--------|-----------|-------|
| `AddTab3()` | `myGui.AddTab3(Options?, TabNamesArray?)` | Controls added afterwards belong to the first tab |
| `.UseTab()` | `.UseTab(Tab?, FullNameMatch := false)` | Number (1 = first tab) or leading text; `UseTab()` with no argument = later controls are not on any tab |

`.Value` of a Tab = selected tab index; `.Text` = selected tab name; `Submit()` stores the name unless `AltSubmit`.

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- Row and column numbers are 1-based; `lv.GetText(0, 1)` returns the header of column 1. ListView/TreeView loops start at row/item 1 (or ID 0 for "first item" lookups).
  ✗ `lv.GetText(1, 0)` → ✓ `lv.GetText(1, 1)`
- `lv.GetNext(start, "Selected")` is not a documented RowType. Omit the second parameter to search selected rows; the documented RowTypes are `"C"` and `"F"`.
- Deleting a row shifts all later row numbers. To delete all selected rows, restart the search from the row before the deleted one (`row - 1`; pattern below, taken from the official ListView example).
  ✗ `Loop lv.GetCount() { lv.Delete(A_Index) }` → ✓ `GetNext(row - 1)` loop
- Keep the IDs returned by `tv.Add()`; they are the only handle for later `Modify`/`Delete`/`GetText`.
  ✗ `tv.Add("Child", parent)` then search by text → ✓ `id := tv.Add(…)`
- Call `tab.UseTab()` before adding controls that do not belong to a tab.
- For bulk inserts, wrap the loop in `lv.Opt("-Redraw")` … `lv.Opt("+Redraw")` to avoid repainting per row.

## RUNTIME ERROR MAPPING

| Error | Trigger | Fix |
|-------|---------|-----|
| `ValueError` | Invalid mode string passed to `GetNext`/`GetCount` (the docs list the valid strings but do not name the error class) | Use only the documented strings |
| Rows skipped during delete | `Loop lv.GetCount()` deleting `A_Index` | Use the `GetNext(row - 1)` loop |
| Error on stale item | `tv.GetText(id)` after the item was deleted | Re-read IDs after deletion; wrap in `try` when IDs may be stale |

## TIER 1 — ListView CRUD

```ahk
#Requires AutoHotkey v2.0

LvDemo()

class LvDemo {
    __New() {
        this.gui := Gui("+Resize", "ListView CRUD")
        this.lv := this.gui.AddListView("w420 h220 Grid", ["Name", "Age", "City"])
        this.lv.Add(, "Alice", 30, "Taipei")
        this.lv.Add(, "Bob", 25, "Kaohsiung")
        this.lv.ModifyCol()                         ; auto-size all columns
        this.lv.ModifyCol(2, "Integer")             ; numeric sort for column 2
        this.lv.OnEvent("DoubleClick", this.OnDoubleClick.Bind(this))

        this.gui.AddButton("xm w100", "Add").OnEvent("Click", this.AddRow.Bind(this))
        this.gui.AddButton("x+8 w100", "Delete").OnEvent("Click", this.DeleteSelected.Bind(this))
        this.gui.Show()
    }

    AddRow(*) {
        row := this.lv.Add("Select Focus Vis", "New", 0, "Unknown")
        this.lv.ModifyCol()
    }

    DeleteSelected(*) {
        row := 0
        while row := this.lv.GetNext(row) {         ; RowType omitted = selected rows
            this.lv.Delete(row)
            row -= 1                                ; rows shifted up; search again from here
        }
    }

    OnDoubleClick(lv, row) {
        if row                                      ; 0 = double-click on empty space
            MsgBox("Row " row ": " lv.GetText(row, 1) " (header: " lv.GetText(0, 1) ")")
    }
}
```

## TIER 2 — TreeView Build and Traverse

```ahk
#Requires AutoHotkey v2.0

g := Gui(, "TreeView")
tv := g.AddTreeView("w300 h250")
fruits := tv.Add("Fruits", 0, "Expand")             ; 0 = top level; returns item ID
tv.Add("Apple", fruits)
tv.Add("Banana", fruits)
vegs := tv.Add("Vegetables", 0, "Expand")
tv.Add("Carrot", vegs)
tv.OnEvent("ItemSelect", (ctrl, id) => (id ? ToolTip(ctrl.GetText(id)) : ""))
g.AddButton("w300", "Dump tree").OnEvent("Click", (*) => MsgBox(DumpTree(tv)))
g.Show()

DumpTree(tv) {
    out := "", id := 0
    while id := tv.GetNext(id, "Full")              ; every item, depth-first
        out .= (tv.GetParent(id) ? "    " : "") tv.GetText(id) "`n"
    return out
}
```

## TIER 3 — StatusBar and Tabs

```ahk
#Requires AutoHotkey v2.0

g := Gui(, "Tabs + StatusBar")
tab := g.AddTab3("w320 h140", ["General", "Advanced"])
g.AddCheckBox("vAutoSave", "Auto-save")              ; goes on tab 1
tab.UseTab(2)
g.AddEdit("vLimit w100", "10")                        ; goes on tab 2
tab.UseTab()                                          ; later controls: no tab

sb := g.AddStatusBar()
sb.SetParts(120, 120)                                 ; three parts; the last fills the rest
sb.SetText("Ready", 1)
sb.SetText("0 items", 2)
sb.SetText("`tcentered", 3)                           ; text after a tab is centered
g.Show()
```

## SEE ALSO

- `Module_GuiBasics.md` — Gui/GuiControl API, events, Submit.
- `Module_GuiLayout.md` — sizing list controls with the window (`Size` event).
- `Module_ControlInteraction.md` — `ControlGetItems`, `ListViewGetContent`-style access to other programs' controls.
