# Module_ArrayAlgorithms.md
<!-- DOMAIN: Array algorithms — shallow/deep cloning, ArrayMap/Filter/Reduce, QuickSort and multi-field sort with comparators, deduplication, Map-backed lookups, set operations and chunk/flatten recipes in AHK v2 -->
<!-- SCOPE: Array creation, indexing, mutation methods, safe access and linear search are in Module_ArrayBasics.md. The Map API is in Module_Maps.md. Fat-arrow syntax for callbacks is in Module_FatArrowFunctions.md. -->
<!-- TRIGGERS: "sort array", QuickSort, SortBy, comparator, StrCompare, "remove duplicates", Unique, UniqueBy, "deep copy", DeepClone, "transform elements", ArrayMap, Filter, Reduce, "set operations", Difference, Intersection, Union, Without, chunk, flatten, "membership test", BuildLookup -->
<!-- CONSTRAINTS: Arrays have no Sort method; the global Sort() sorts delimited strings. The relational operators < > <= >= throw TypeError when either input is a non-numeric string — compare strings with StrCompare(). Never name a global function Map (or any built-in class name); the helpers here use ArrayMap and ArrayUnion. Map keys are case-sensitive by default and Float keys become strings, which affects Map-backed dedup. A `=>` callback is one expression; use a named nested function for multi-statement comparators. -->
<!-- CROSS-REF: Module_ArrayBasics.md, Module_Maps.md, Module_FatArrowFunctions.md, Module_FunctionObjects.md -->
<!-- VERSION: AHK v2.0+ -->

## API QUICK-REFERENCE

### Built-ins Used by the Helpers

| Function / Method | Signature | Returns | Notes |
|-------------------|-----------|---------|-------|
| `.Clone()` | `arr.Clone()` | Array | Shallow copy (nested objects shared) |
| `StrCompare()` | `StrCompare(String1, String2, CaseSense?)` | Negative, 0 or positive | Alphabetical; case-insensitive by default; `CaseSense` can be `On`, `Locale` or `Logical` |
| `IsNumber()` | `IsNumber(v)` | 1 or 0 | True for numbers and numeric strings |
| `Sort()` | `Sort(String, Options?, Callback?)` | String | Sorts a delimited string (e.g. `"N"` numeric, `"U"` unique) |
| `Map()` | `Map()` | Map | Seen-set for dedup and set operations |
| `Mod()` | `Mod(Dividend, Divisor)` | Number | ZeroDivisionError when Divisor is 0 |

### Module Helpers (defined below)

| Helper | Signature | Returns | Notes |
|--------|-----------|---------|-------|
| `DeepClone()` | `DeepClone(value)` | Copy | Recurses through Array, Map and plain Object value properties; no cycle handling |
| `ArrayMap()` | `ArrayMap(arr, fn)` | Array | New Array of `fn(value, index, arr)` |
| `Filter()` | `Filter(arr, pred)` | Array | Elements where `pred(value, index, arr)` is truthy |
| `Reduce()` | `Reduce(arr, fn, initial?)` | Any | Throws when empty and no initial value |
| `CompareValues()` | `CompareValues(a, b)` | Negative, 0, positive | Numeric when both are numbers, otherwise `StrCompare` |
| `QuickSort()` | `QuickSort(arr, cmp?)` | Array | In place; `cmp(a, b)` returns negative/0/positive |
| `SortBy()` | `SortBy(arr, fields*)` | Array | Multi-field sort of Arrays of Maps |
| `Unique()` / `UniqueBy()` | `Unique(arr)` / `UniqueBy(arr, keyFn)` | Array | First-seen order kept |
| `BuildLookup()` | `BuildLookup(arr)` | Map | Build once, query many times |
| `ModifyInPlace()` | `ModifyInPlace(arr, fn)` | Array | No new allocation |
| `Difference()` / `Intersection()` / `ArrayUnion()` / `Without()` | see TIER 4 | Array | Map-backed set operations |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- **No `Array.Sort()`.** Use `QuickSort()` or, for flat lists of strings/numbers, build a delimited string and call `Sort()`.
- **Relational operators are numeric only.** `"apple" < "banana"` throws TypeError; use `StrCompare(a, b) < 0`. `=`/`!=` test string equality (case-insensitive for ASCII); `==` is case-sensitive. Comparators for strings use `StrCompare`.
  ✗ `(a, b) => a < b ? -1 : 1` for names → ✓ `StrCompare(a, b)`
- **Do not shadow built-in classes.** A global function named `Map`, `Array` or `Filter`-like names that collide with built-ins breaks code that expects the class. Rename such helpers (`ArrayMap`, `ArrayUnion`). Method names on your own classes (e.g. `FunctionalArray.Map`) are fine.
  ✗ `Map(arr, fn) { ... }` → ✓ `ArrayMap(arr, fn)`
- **Map-backed dedup follows Map key rules.** Keys are case-sensitive by default (`"a"` and `"A"` stay distinct; set `CaseSense := "Off"` on the empty Map to merge them), Float keys are converted to strings, and objects are compared by reference.
  ✗ `Unique(["a", "A"])` expected to return length 1 → ✓ Map with `CaseSense := "Off"`
- **Comparators must be consistent.** Return negative when `a` sorts first, 0 when equal, positive when `b` sorts first.
- **Clone before sorting when the original order must be kept.** `QuickSort` sorts in place.
  ✗ `QuickSort(data)` when order matters → ✓ `QuickSort(data.Clone())`
- **Use `DeepClone()` when nested items of a copy will change.** `.Clone()` is shallow.
  ✗ mutating nested items of a `.Clone()` result → ✓ `DeepClone()`
- **Give `Reduce` an initial value when the Array may be empty.**
- **Membership tests:** see `### Performance Notes`.
  ✗ nested `for x in a1 { for y in a2 ... }` → ✓ Map seen-set / `BuildLookup`

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Fix |
|----------------|-------------------|-----|
| `TypeError` | `<`/`>` comparison of non-numeric strings in a comparator | `StrCompare(a, b)` or `CompareValues` |
| `MethodError` | `arr.Sort()` | `QuickSort(arr)` |
| `Error` | `Reduce` of an empty Array without an initial value | Pass an initial value |
| `UnsetItemError` | Helper reads an element with no value | Check `arr.Has(i)` or set `.Default` |

## TIER 1 — Transformations: Clone, DeepClone, ArrayMap, Filter, Reduce
> METHODS COVERED: `.Clone()` · `DeepClone()` · `ArrayMap()` · `Filter()` · `Reduce()`

```ahk
shallow := [[1, 2], [3]].Clone()       ; inner Arrays are shared

DeepClone(value) {
    if !IsObject(value)
        return value
    if value is Array {
        result := []
        for item in value
            result.Push(DeepClone(item))
        return result
    }
    if value is Map {
        result := Map()
        result.CaseSense := value.CaseSense
        for k, v in value
            result[k] := DeepClone(v)
        return result
    }
    result := {}
    for name in value.OwnProps() {     ; one variable: getters are not called
        desc := value.GetOwnPropDesc(name)
        if desc.HasProp("Value")
            result.DefineProp(name, {Value: DeepClone(desc.Value)})
    }
    return result
}

ArrayMap(arr, fn) {
    result := []
    for index, value in arr
        result.Push(fn(value, index, arr))
    return result
}

Filter(arr, pred) {
    result := []
    for index, value in arr
        if pred(value, index, arr)
            result.Push(value)
    return result
}

Reduce(arr, fn, initial?) {
    if IsSet(initial) {
        acc := initial, start := 1
    } else {
        if arr.Length = 0
            throw Error("Reduce of empty array with no initial value", -1)
        acc := arr[1], start := 2
    }
    loop arr.Length - start + 1 {
        i := start + A_Index - 1
        acc := fn(acc, arr[i], i, arr)
    }
    return acc
}

numbers := [1, 2, 3, 4, 5]
doubled := ArrayMap(numbers, (x, *) => x * 2)
evens   := Filter(numbers, (x, *) => Mod(x, 2) = 0)
total   := Reduce(numbers, (acc, x, *) => acc + x)
MsgBox(doubled[5] " " evens.Length " " total)   ; 10 2 15
```

## TIER 2 — Sorting with Comparators
> METHODS COVERED: `CompareValues()` · `QuickSort()` · `SortBy()` · `StrCompare()` · `Sort()`

`QuickSort` sorts in place (Lomuto partition). Call `arr.Clone()` first to keep the original order.

```ahk
CompareValues(a, b) {
    if IsNumber(a) && IsNumber(b)
        return a < b ? -1 : a > b ? 1 : 0
    return StrCompare(a, b)            ; ✓ strings: never use < or > here
}

QuickSort(arr, cmp := CompareValues, left := 1, right?) {
    if !IsSet(right)
        right := arr.Length
    if left >= right
        return arr
    pivot := arr[right], i := left - 1
    loop right - left {
        j := left + A_Index - 1
        if cmp(arr[j], pivot) <= 0 {
            i++
            t := arr[i], arr[i] := arr[j], arr[j] := t
        }
    }
    i++
    t := arr[i], arr[i] := arr[right], arr[right] := t
    QuickSort(arr, cmp, left, i - 1)
    QuickSort(arr, cmp, i + 1, right)
    return arr
}

nums := [3, 1, 4, 1, 5]
QuickSort(nums)                                 ; 1 1 3 4 5
QuickSort(nums, (a, b) => b - a)                ; descending numeric
names := ["bob", "Alice", "carol"]
QuickSort(names)                                ; Alice bob carol (case-insensitive)
QuickSort(names, (a, b) => StrCompare(a, b, true))   ; case-sensitive

; ✗ QuickSort(names, (a, b) => a < b ? -1 : 1)  ; → TypeError: non-numeric strings

SortBy(arr, fields*) {
    Comparator(a, b) {                 ; named nested function: several statements
        for field in fields {
            r := CompareValues(a[field], b[field])
            if r != 0
                return r
        }
        return 0
    }
    return QuickSort(arr, Comparator)
}

students := [
    Map("name", "Charlie", "grade", 85),
    Map("name", "Alice",   "grade", 92),
    Map("name", "Bob",     "grade", 85)
]
SortBy(students, "grade", "name")      ; Bob 85, Charlie 85, Alice 92

; ✓ Flat list of numbers via the global Sort() on a string
sortedText := Sort("5,3,10,1", "N D,")  ; "1,3,5,10"
```

## TIER 3 — Deduplication, Lookups, and In-Place Updates
> METHODS COVERED: `Unique()` · `UniqueBy()` · `BuildLookup()` · `ModifyInPlace()` · `Map.Has()`

A Map seen-set avoids nested membership loops. Remember the Map key rules (case-sensitive by default).

```ahk
Unique(arr) {
    result := [], seen := Map()
    for item in arr {
        if !seen.Has(item) {
            seen[item] := true
            result.Push(item)
        }
    }
    return result
}

UniqueBy(arr, keyFn) {
    result := [], seen := Map()
    for item in arr {
        key := keyFn(item)
        if !seen.Has(key) {
            seen[key] := true
            result.Push(item)
        }
    }
    return result
}

BuildLookup(arr) {
    lookup := Map()
    for item in arr
        lookup[item] := true
    return lookup
}

ModifyInPlace(arr, fn) {
    for index, value in arr
        arr[index] := fn(value)        ; assigning existing indices during for is fine
    return arr
}

MsgBox(Unique([1, 2, 2, 3, 1]).Length)                       ; 3
people := [Map("id", 1, "name", "Al"), Map("id", 2, "name", "Bo"), Map("id", 1, "name", "Al")]
MsgBox(UniqueBy(people, (p) => p["id"]).Length)               ; 2
allowed := BuildLookup(["read", "write"])
MsgBox(allowed.Has("write"))                                  ; 1
```

## TIER 4 — Set Operations: Difference, Intersection, Union, Without
> METHODS COVERED: `Difference()` · `Intersection()` · `ArrayUnion()` · `Without()`

```ahk
Difference(a1, a2) {
    set2 := BuildLookup(a2), result := []
    for item in a1
        if !set2.Has(item)
            result.Push(item)
    return result
}

Intersection(a1, a2) {
    set2 := BuildLookup(a2), result := []
    for item in a1 {
        if set2.Has(item) {
            result.Push(item)
            set2.Delete(item)          ; each value matched once
        }
    }
    return result
}

ArrayUnion(arrays*) {
    result := [], seen := Map()
    for arr in arrays
        for item in arr
            if !seen.Has(item) {
                seen[item] := true
                result.Push(item)
            }
    return result
}

Without(arr, excluded*) {
    skip := BuildLookup(excluded), result := []
    for item in arr
        if !skip.Has(item)
            result.Push(item)
    return result
}

a := [1, 2, 3, 4], b := [3, 4, 5, 6]
MsgBox(Difference(a, b).Length " " Intersection(a, b).Length " "
    . ArrayUnion(a, b).Length " " Without(a, 2, 4).Length)   ; 2 2 6 2
```

### Performance Notes

- `Push`/`Pop` at the end avoid shifting; `InsertAt(1, …)`/`RemoveAt(1)` shift every later element.
- Set `arr.Capacity := n` before a long `Push` loop when the final size is known.
- Repeated membership tests: build a Map once (`BuildLookup`) instead of scanning the Array each time.
- `ArrayMap`/`Filter` allocate a new Array; use `ModifyInPlace` when the original is not needed.
- `DeepClone` allocates one container per node; share read-only sub-structures instead of deep-copying them.

## DROP-IN RECIPES

```ahk
; SafePop — returns a default instead of throwing on an empty Array
SafePop(arr, default?) {
    if !(arr is Array)
        throw TypeError("SafePop: expected Array, got " Type(arr), -1)
    if arr.Length
        return arr.Pop()
    if IsSet(default)
        return default
    throw Error("SafePop: array is empty and no default was provided", -1)
}

; ChunkArray — splits into sub-arrays of at most `size` items
ChunkArray(arr, size) {
    if !IsInteger(size) || size < 1
        throw ValueError("ChunkArray: size must be a positive integer", -1)
    chunks := [], chunk := []
    for index, value in arr {
        chunk.Push(value)
        if Mod(index, size) = 0
            chunks.Push(chunk), chunk := []
    }
    if chunk.Length
        chunks.Push(chunk)
    return chunks
}

; Flatten — depth 1 flattens one level; depth -1 flattens all levels
Flatten(arr, depth := 1) {
    result := []
    FlattenInto(arr, depth)
    return result
    FlattenInto(src, remaining) {
        for item in src {
            if (item is Array) && remaining != 0
                FlattenInto(item, remaining - 1)
            else
                result.Push(item)
        }
    }
}
; Call site: Flatten([[1, 2], [3, [4, 5]]])   ; → [1, 2, 3, [4, 5]]
```

## SEE ALSO

- `Module_ArrayBasics.md` — Array API, indexing, safe access, mutation and search helpers.
- `Module_Maps.md` — Map API, `CaseSense`, `Default`.
- `Module_FatArrowFunctions.md` — callback syntax, compose/curry.
- `Module_FunctionObjects.md` — passing and validating callbacks.
