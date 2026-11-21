# Module_ContainerChoice.md
<!-- DOMAIN: Choosing and combining data containers — Array vs Map vs Object literal, nested records (Array of Maps), static lookup tables in classes, accumulation patterns, and defensive guards for IndexError/UnsetItemError in AHK v2 -->
<!-- SCOPE: Full Array API is in Module_ArrayBasics.md; sorting, dedup and set operations in Module_ArrayAlgorithms.md; full Map API in Module_Maps.md; object/property mechanics in Module_ObjectBasics.md. Structured error recovery beyond guards is in Module_ExceptionHandling.md. -->
<!-- TRIGGERS: "data structure", "which container", "Map vs Array", "Map vs Object", collection, "store ordered items", "store named settings", "nested data", "list of records", "table of rows", "lookup table", "config table", "error code table", "static Map", IndexError, UnsetItemError, "safe access", "defensive guard" -->
<!-- CONSTRAINTS: Array = ordered, 1-based, integer-indexed. Map = any Integer/String/object key, case-sensitive string keys by default, no documented enumeration order. Object literal = fixed set of named properties; it has no Has/Get/Delete/Count/__Item/__Enum, so it is not a dictionary (Map for runtime key-value data is a repository convention backed by these API differences). Out-of-range Array index → IndexError; missing Map key or valueless element → UnsetItemError. Clone() is shallow for both. -->
<!-- CROSS-REF: Module_ArrayBasics.md, Module_ArrayAlgorithms.md, Module_Maps.md, Module_ObjectBasics.md, Module_ClassBasics.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| One object type for lists and dictionaries | `[]`/`Array()` for lists, `Map()` for key-value data | v2 Arrays, Maps and plain Objects have different APIs |
| `arr[0]` | `arr[1]`, `arr[-1]` | IndexError |
| Missing key/element returns `""` | `Get(key, default)` / `Has()` / `.Default` | v2 throws UnsetItemError |
| `{key: val}` enumerated with `for k, v in obj` | `Map` with `for k, v in m`, or `obj.OwnProps()` for real properties | Plain Objects have no `__Enum` |

## API QUICK-REFERENCE

### Which Container

| Need | Use | Example |
|------|-----|---------|
| Ordered sequence, stack, queue | Array | `steps := ["init", "run"]`, `Push`/`Pop`/`RemoveAt(1)` |
| Lookup by name or arbitrary key | Map | `cfg := Map("host", "localhost")` |
| Keys that are objects | Map | `m[guiCtrl] := info` |
| Fixed set of named fields known in code | Object literal or class | `pt := {x: 1, y: 2}`; `Point(1, 2)` |
| Descriptor / options object for an API | Object literal | `obj.DefineProp("p", {get: fn})` |
| Table of records | Array of Maps (or of class instances) | `rows.Push(Map("id", 1, "name", "A"))` |
| Membership test, dedup | Map as a set | `seen[item] := true` |

### Shared Guard API

| Method | Array | Map | Notes |
|--------|-------|-----|-------|
| `.Has(x)` | valid index **and** has a value | key present | Never throws |
| `.Get(x, default)` | IndexError if out of range; default for valueless element | default for missing key | `Default` argument wins over `.Default` |
| `.Default` | for valueless elements | for missing keys | Not defined by default |
| `.Clone()` | shallow | shallow | Nested objects are shared |
| `.Length` / `.Count` | `Length` | `Count` | Properties, no parentheses |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- **Pick by access pattern.** Position → Array. Name/key → Map. Fixed field names known while writing the code → object literal or class.
- **Records in tables are Maps or class instances**, not positional sub-arrays (index bugs).
  ✗ `row := ["Alice", "admin", 42]` read as `row[2]` → ✓ `Map("name", "Alice", "role", "admin")`
- **Repeated lookups by key use a Map built once.** A linear search costs O(n) per access.
  ✗ `for u in users` each time to find an id → ✓ build a `byId` Map once
- **Plain Objects are not dictionaries.** No `Has`, `Get`, `Delete`, `Count`, `[]` indexing or `for k, v` enumeration (use `OwnProps()` only for real properties).
  ✗ `config := {width: 800}` then `config[k]` → ✓ `Map("width", 800)`
- **Two different "missing" errors.** Array index out of range → IndexError (a subclass of ValueError). Missing Map key, or an Array element without a value → UnsetItemError (a subclass of UnsetError). Read every possibly-missing key or element with `Has`, `Get(x, default)` or `.Default` (V1 → V2 BREAKING CHANGES).
- **`Get(index, default)` on an Array still throws IndexError** for out-of-range indexes; check `Length` first when the index may be outside the Array. The default only covers valueless elements.
  ✗ `arr.Get(99, "")` on a short Array → ✓ check `Length` first
- **Shallow copies.** `Clone()` copies only the top level; mutate nested records in a clone and the original changes too (see `DeepClone` in Module_ArrayAlgorithms.md).
- **No documented Map order.** Keep a separate Array of keys when order matters.

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Fix |
|----------------|-------------------|-----|
| `IndexError` | `arr[0]`, `arr[Length + 1]`, `arr.Get(99, x)` | 1-based index; check `Length` |
| `UnsetItemError` | `m["missing"]`; reading an Array element with no value | `Get(x, default)`, `Has`, `.Default` |
| Error on `obj["k"]` / `for k, v in obj` | Plain Object used as a dictionary | Use a Map |
| `MethodError` | `m.Keys()`, `obj.Has(k)` on a plain Object | `for k in m`; use a Map |

## TIER 1 — Choosing Array vs Map vs Object
> METHODS COVERED: `[]` · `Map()` · object literal · class with static Map

```ahk
steps := ["init", "run", "cleanup"]               ; ordered → Array
config := Map("width", 800, "height", 600)        ; keyed → Map
origin := {x: 0, y: 0}                            ; fixed fields → object literal

class AppConfig {
    static Settings := Map("theme", "dark", "lang", "en", "version", "2.0")
}
MsgBox(AppConfig.Settings["theme"])

; ✗ Runtime dictionary in an object literal
; data := {}
; data[userName] := score                          ; → plain Objects have no __Item
; ✓
data := Map()
data["alice"] := 95
```

## TIER 2 — Nested Structures and Static Lookup Tables
> METHODS COVERED: Array of Maps · static class Maps · `Get` with fallback · accumulation loops

```ahk
class UserManager {
    static Users := []
    static AddUser(name, role) {
        UserManager.Users.Push(Map("name", name, "role", role, "loginTime", A_Now))
    }
    static Describe() {
        out := ""
        for index, user in UserManager.Users
            out .= index ": " user["name"] " (" user["role"] ")`n"
        return out
    }
}
UserManager.AddUser("Alice", "admin")
UserManager.AddUser("Bob", "viewer")
MsgBox(UserManager.Describe())

class AppSettings {
    static Defaults := Map("width", 1280, "height", 720, "theme", "dark")
    static ErrorMessages := Map(
        "NOT_FOUND",  "Resource not found.",
        "PERMISSION", "Access denied."
    )
    static Setting(key) => AppSettings.Defaults.Get(key, "")
    static Message(code) => AppSettings.ErrorMessages.Get(code, "Unknown error.")
}
MsgBox(AppSettings.Setting("theme") " / " AppSettings.Message("TIMEOUT"))   ; dark / Unknown error.

; Accumulation patterns (helpers: Module_ArrayAlgorithms.md)
numbers := [1, 2, 3, 4, 5, 6]
evens := [], squares := [], total := 0
for n in numbers {
    if Mod(n, 2) = 0
        evens.Push(n)
    squares.Push(n ** 2)
    total += n
}
MsgBox(evens.Length " " squares[6] " " total)     ; 3 36 21

; Index a table by id once, then look up by key
users := [Map("id", 7, "name", "Ann"), Map("id", 9, "name", "Ben")]
byId := Map()
for i, user in users
    byId[user["id"]] := user
MsgBox(byId[9]["name"])                           ; Ben
```

## TIER 3 — Defensive Guards: IndexError and UnsetItemError
> METHODS COVERED: `Has` · `Get` · `.Default` · `try`/`catch IndexError` · `catch UnsetItemError`

Prefer `Has`/`Get` for expected absence; use `try`/`catch` when the error message itself is useful.

```ahk
arr := ["a", "b", "c"]

SafeGet(arr, index, default := "") {
    return (index >= 1 && index <= arr.Length && arr.Has(index)) ? arr[index] : default
}
MsgBox(SafeGet(arr, 99, "none"))       ; none — no IndexError

sparse := ["a", , "c"]
MsgBox(sparse.Get(2, "fallback"))      ; fallback

try {
    MsgBox(arr[0])
} catch IndexError as e {
    MsgBox("Index error: " e.Message)
}

cfg := Map("host", "localhost", "port", 5432)
timeout := cfg.Get("timeout", 30)
if !cfg.Has("user")
    MsgBox("Key 'user' not configured.")

try {
    val := cfg["nonexistent"]
} catch UnsetItemError as e {
    MsgBox("Missing key: " e.Message)
}
```

### Performance Notes

- Reserve space with `.Capacity` before large `Push`/`[]` loops when the final size is known.
- Build a Map index once (TIER 2 `byId`) instead of scanning an Array for every lookup.
- Iterate the original container when the loop does not change its shape; clone only when removing or adding during iteration.

## DROP-IN RECIPES

```ahk
; SafeArraySlice — elements startIndex..endIndex (inclusive); clamps to the valid range
SafeArraySlice(arr, startIndex, endIndex := 0) {
    if !(arr is Array)
        throw TypeError("SafeArraySlice: arr must be an Array", -1)
    endIndex := (endIndex = 0 || endIndex > arr.Length) ? arr.Length : endIndex
    startIndex := Max(1, startIndex)
    result := []
    if startIndex > endIndex
        return result
    result.Capacity := endIndex - startIndex + 1
    Loop endIndex - startIndex + 1 {
        i := startIndex + A_Index - 1
        result.Push(arr.Get(i, ""))    ; valueless elements become ""
    }
    return result
}
; Call site: page := SafeArraySlice(allRows, 21, 40)

; GroupBy — Map from key to Array of records
GroupBy(records, keyFn) {
    groups := Map()
    for rec in records {
        k := keyFn(rec)
        if !groups.Has(k)
            groups[k] := []
        groups[k].Push(rec)
    }
    return groups
}
; Call site: byRole := GroupBy(UserManager.Users, (u) => u["role"])
```

## SEE ALSO

- `Module_ArrayBasics.md` — Array API and safe access.
- `Module_ArrayAlgorithms.md` — DeepClone, sorting, dedup, set operations.
- `Module_Maps.md` — Map API, CaseSense, Default, Map recipes.
- `Module_ObjectBasics.md` — object literals vs Maps.
- `Module_ClassBasics.md` — static class variables.
- `Module_ExceptionHandling.md` — IndexError/UnsetItemError handling and recovery.
