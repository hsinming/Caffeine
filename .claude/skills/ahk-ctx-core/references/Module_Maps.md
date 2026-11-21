# Module_Maps.md
<!-- DOMAIN: Map objects — construction, key rules, Has/Get/Set/Delete/Clear, Count, Capacity, CaseSense, Default, enumeration and Map-based recipes in AHK v2 -->
<!-- SCOPE: Choosing between Map, Array and Object, nested structures and error-guard patterns are in Module_ContainerChoice.md. Array API is in Module_ArrayBasics.md. Defining methods on prototypes in general is in Module_RuntimePrototyping.md. -->
<!-- TRIGGERS: Map, Map(), "key-value", dictionary, hash, "associative array", Has, Get, Set, Delete, Clear, Count, Capacity, CaseSense, "case-insensitive keys", Default, "default value for missing key", "iterate map", "for key, value", "map keys", "merge maps", UnsetItemError -->
<!-- CONSTRAINTS: Reading a missing key with m[key] or m.Get(key) throws UnsetItemError unless a default is given or Map.Default is defined. m.Delete(key) throws UnsetItemError when the key is absent. String keys are case-sensitive by default; CaseSense can be assigned only while the Map is empty. Float keys are converted to strings; object keys compare by reference. Map has no Keys()/Values() methods — enumerate with for. Enumeration order is not documented as a contract. -->
<!-- CROSS-REF: Module_ContainerChoice.md, Module_ArrayBasics.md, Module_ObjectBasics.md, Module_RuntimePrototyping.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `{key: val}` / `obj[key]` as a dictionary | `Map("key", val)` / `m[key]` | Plain Objects have no `__Item`, `Has`, `Get`, `Delete`, `Count` or `__Enum` |
| `val := m["key"]` expecting `""` when missing | `m.Get("key", default)` or `m.Has("key")` | v2 throws UnsetItemError for a missing key |
| `m.HasKey(k)` / `m.Remove(k)` / `m.Count()` | `m.Has(k)` / `m.Delete(k)` / `m.Count` | Old names do not exist; `Count` is a property |
| Case-insensitive keys by default | `m.CaseSense := "Off"` on an empty Map | v2 Map keys are case-sensitive by default |
| `m.Keys()` | `for k in m` (or add a helper) | No built-in `Keys` method (MethodError) |
| `new Map()` | `Map()` | `new` is not a v2 operator |

## API QUICK-REFERENCE

### Map

| Method / Property | Signature | Returns | Throws | Notes |
|-------------------|-----------|---------|--------|-------|
| `Map()` | `Map(Key1, Value1, ...)` | Map | — | Like `m[k] := v` for each pair, but `__Item` is not called and Capacity is sized once |
| `[]` | `m[Key]` / `m[Key] := Value` | Value | UnsetItemError (get, missing key, no `Default`) | Assigning adds or replaces |
| `.Get()` | `.Get(Key, Default?)` | Value | UnsetItemError | Order: value → `Default` argument → `m.Default` → throw. `__Item` is not called |
| `.Has()` | `.Has(Key)` | 1 or 0 | — | Key present |
| `.Set()` | `.Set(Key, Value, ...)` | The Map | — | Sets several pairs; `__Item` is not called |
| `.Delete()` | `.Delete(Key)` | Removed value | UnsetItemError if missing | Guard with `Has` when absence is normal |
| `.Clear()` | `.Clear()` | — | — | Removes all pairs |
| `.Clone()` | `.Clone()` | Map | — | Shallow copy; own properties and base copied too |
| `.Count` | `.Count` | Integer | — | Number of pairs (read-only) |
| `.Capacity` | `.Capacity := n` | Integer | — | Reserve space before a bulk insert |
| `.CaseSense` | `.CaseSense := "On"/"Off"/"Locale"` (or 1/0) | `"On"`/`"Off"`/`"Locale"` | Exception if the Map is not empty | Default `On`; `Locale` is 1–8× slower than `Off` |
| `.Default` | `.Default := value` | — | — | Not defined by default; returned by `[]` and `Get` for missing keys |
| `__Enum` | `for key, value in m` / `for key in m` | Enumerator | — | One variable yields keys |

### Key Rules

| Key type | Behavior |
|----------|----------|
| String | Case-sensitive unless `CaseSense` says otherwise; "Off" ignores case for ASCII A–Z only |
| Integer | Any Integer |
| Float | Converted to String |
| Object | Compared by reference (identity) |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- Read a key that may be missing with `m.Get("key", default)`, `if m.Has("key")`, or a defined `m.Default`. `m["key"]` on a missing key throws UnsetItemError; that wrong form is in V1 → V2 BREAKING CHANGES.
- Set `CaseSense` on an empty Map, before the first key is added; setting it after inserting keys throws. Keys are case-sensitive by default (V1 → V2 BREAKING CHANGES).
  ✗ `m["k"] := 1` then `m.CaseSense := "Off"` → ✓ create the Map empty, set `CaseSense`, then add keys
- `m.Delete(k)` on a missing key throws UnsetItemError. Guard it when the key may already be gone.
  ✗ `m.Delete("missing")` → ✓ `if m.Has(k)` then `m.Delete(k)`
- `Count` is a property, and a Map has no `Keys()`/`Values()` methods: use `for k in m`, or a helper/prototype method (see TIER 3). The `Count()` and `Keys()` wrong forms are in V1 → V2 BREAKING CHANGES.
  ✗ `m.Values()` → ✓ `for k in m` / helper
- Repository convention (backed by the API differences above): use `Map` for runtime key-value data; keep object literals for descriptors, option objects and fixed-shape records. The object-literal dictionary wrong form is in V1 → V2 BREAKING CHANGES.
- Do not rely on a particular enumeration order; keep a separate Array of keys when order matters.
- A Map that stores a reference to itself (directly or through other objects) is a reference cycle and is not freed until the cycle is broken.

Safe-access priority order:
1. `m.Get(key, default)` — optional key, one line
2. `m.Has(key)` — when the branches differ
3. `m.Default` — one fallback for every missing key
4. `try`/`catch UnsetItemError` — only when the error message is useful

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Fix |
|----------------|-------------------|-----|
| `UnsetItemError` | `m[key]` / `m.Get(key)` for a missing key with no default | `Get(key, default)`, `Has`, or `Default` |
| `UnsetItemError` | `m.Delete(key)` for a missing key | `Has(key)` first |
| Exception on `CaseSense` | Assigning `CaseSense` on a non-empty Map | Set it while the Map is empty |
| `MethodError` | `m.Keys()`, `m.Values()`, `m.HasKey()` | `for` loop / `Has` |

## TIER 1 — Map Construction, Safe Access, and Mutation
> METHODS COVERED: `Map()` · `[]` · `Get` · `Has` · `Set` · `Delete` · `Clear` · `Count` · `Default`

```ahk
colors := Map("red", "ff0000", "green", "00ff00")
settings := Map(
    "host",    "localhost",
    "port",    5432,
    "timeout", 30
)
settings["timeout"] := 60              ; replace
settings["user"] := "admin"            ; add
MsgBox(settings.Count)                 ; 4

if settings.Has("host")
    MsgBox(settings["host"])
font := settings.Get("font", "Segoe UI")   ; default when missing
; v := settings["nonexistent"]         ; ✗ UnsetItemError

settings.Set("retries", 3, "verbose", false)
removed := settings.Delete("retries")  ; 3
if settings.Has("retries")
    settings.Delete("retries")         ; ✓ guarded

fallback := Map("a", 1)
fallback.Default := ""
MsgBox(fallback["zzz"] = "")           ; 1 — Default used

settings.Clear()
MsgBox(settings.Count)                 ; 0
```

## TIER 2 — CaseSense, Clone, and Capacity
> METHODS COVERED: `CaseSense` · `Clone` · `Capacity`

```ahk
m1 := Map("Hello", 1)
MsgBox(m1.Has("hello"))                ; 0 — case-sensitive by default

m2 := Map()
m2.CaseSense := "Off"                  ; ✓ before adding keys
m2["Hello"] := 1
MsgBox(m2.Has("hello"))                ; 1

; m3 := Map("key", 1)
; m3.CaseSense := "Off"                ; ✗ throws — Map is not empty

original := Map("x", 10, "nested", [1, 2])
copy := original.Clone()
copy["z"] := 30
MsgBox(original.Count)                 ; 2 — pairs are independent
copy["nested"].Push(3)
MsgBox(original["nested"].Length)      ; 3 — nested objects are shared

bulk := Map()
bulk.Capacity := 500
Loop 500
    bulk["key" A_Index] := A_Index
```

## TIER 3 — Enumeration and a Keys() Helper
> METHODS COVERED: `for key, value in m` · `for key in m` · `Map.Prototype.DefineProp`

```ahk
scores := Map("Alice", 95, "Bob", 87, "Carol", 92)
for name, score in scores
    OutputDebug(name ": " score)
for name in scores                     ; keys only
    OutputDebug(name)

; ✓ Plain helper function — no global side effects
MapKeys(m) {
    keys := []
    for k in m
        keys.Push(k)
    return keys
}
MsgBox(MapKeys(scores).Length)         ; 3

; Optional: add a Keys() method to every Map (affects the whole script)
MapKeysMethod(this) => MapKeys(this)
Map.Prototype.DefineProp("Keys", {Call: MapKeysMethod})
MsgBox(scores.Keys().Length)           ; 3

; ✓ Preserve insertion order explicitly when it matters
order := [], data := Map()
AddOrdered(key, value) {
    global order, data
    if !data.Has(key)
        order.Push(key)
    data[key] := value
}
AddOrdered("b", 2), AddOrdered("a", 1)
for key in order
    OutputDebug(key " = " data[key])   ; b then a
```

## DROP-IN RECIPES

```ahk
; MapFromArrays — zip a keys Array and a values Array into a Map
MapFromArrays(keys, values, caseSense := "On") {
    if !(keys is Array) || !(values is Array)
        throw TypeError("MapFromArrays: keys and values must be Arrays", -1)
    if keys.Length != values.Length
        throw ValueError("MapFromArrays: length mismatch (" keys.Length " vs " values.Length ")", -1)
    result := Map()
    result.CaseSense := caseSense       ; set before inserting
    result.Capacity := keys.Length
    Loop keys.Length
        result[keys[A_Index]] := values[A_Index]
    return result
}
; Call site: cfg := MapFromArrays(["host", "port"], ["localhost", 5432])

; MapMerge — returns a new Map; override wins on duplicate keys
MapMerge(base, override) {
    if !(base is Map) || !(override is Map)
        throw TypeError("MapMerge: both arguments must be Maps", -1)
    result := base.Clone()
    for k, v in override
        result[k] := v
    return result
}
; Call site: effective := MapMerge(defaults, userOverrides)

; MapInvert — values become keys (later duplicates overwrite earlier ones)
MapInvert(m) {
    result := Map()
    result.CaseSense := m.CaseSense
    for k, v in m
        result[v] := k
    return result
}
```

## SEE ALSO

- `Module_ContainerChoice.md` — Map vs Array vs Object, nested records, static lookup tables, error guards.
- `Module_ArrayBasics.md` — Array API.
- `Module_ObjectBasics.md` — why plain Objects are not dictionaries.
- `Module_RuntimePrototyping.md` — rules and risks of extending built-in prototypes.
- `Module_ExceptionHandling.md` — UnsetItemError handling.
