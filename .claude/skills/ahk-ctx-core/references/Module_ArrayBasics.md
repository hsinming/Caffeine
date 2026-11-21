# Module_ArrayBasics.md
<!-- DOMAIN: Array basics — creation, 1-based and negative indexing, Length/Capacity/Default, Push/Pop/InsertAt/RemoveAt/Delete, safe access with Has/Get, iteration and linear search in AHK v2 -->
<!-- SCOPE: Transformations (DeepClone, ArrayMap, Filter, Reduce), sorting, deduplication, set operations and chunk/flatten recipes are in Module_ArrayAlgorithms.md. Map is in Module_Maps.md; choosing between containers is in Module_ContainerChoice.md. GUI list population is in Module_GuiListViewTreeView.md. -->
<!-- TRIGGERS: Array, Array(), "[]", Push, Pop, InsertAt, RemoveAt, Delete, Has, Get, Length, Capacity, Default, Clone, "array index", "first element", "last element", "negative index", "store multiple values", list, "iterate array", "for loop array", "remove element", IndexOf, "find in array", "array contains" -->
<!-- CONSTRAINTS: Arrays are 1-based; index 0 or |index| > Length throws IndexError; -1 is the last element. Array(N) creates [N], not N empty slots — use Capacity to reserve space. Arrays have no built-in Sort, IndexOf or Contains method. Reading an element that has no value throws UnsetItemError unless Default is defined or Get(index, default) is used. Pop on an empty Array throws. -->
<!-- CROSS-REF: Module_ArrayAlgorithms.md, Module_Maps.md, Module_ContainerChoice.md, Module_FunctionBasics.md, Module_ExceptionHandling.md, Module_GuiListViewTreeView.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `array[0]` for the first element | `array[1]` | IndexError — 0 is never a valid index |
| `arr.MaxIndex()` / `arr.Length()` | `arr.Length` (property) | `MaxIndex` does not exist; `Length` is a property |
| `arr.Insert(x)` / `arr.Remove(i)` | `arr.Push(x)` / `arr.RemoveAt(i)` | Old method names do not exist (MethodError) |
| `array.Sort()` | `QuickSort()` helper (Module_ArrayAlgorithms.md) or `Sort()` on a delimited string | Arrays have no `Sort` method (MethodError) |
| `Array(10)` to pre-allocate | `arr := [], arr.Capacity := 10` | Creates `[10]` — one element whose value is 10 |
| `new Array()` | `Array()` or `[]` | `new` is not a v2 operator |
| `for i, v in arr` assuming `i` starts at 0 | First index is 1 | Off-by-one errors |

## API QUICK-REFERENCE

### Array (built-in)

| Method / Property | Signature | Returns | Throws | Notes |
|-------------------|-----------|---------|--------|-------|
| `[]` literal | `[v1, v2, ...]` | Array | — | `[a, , c]` leaves element 2 without a value |
| `Array()` | `Array(Values*)` | Array | — | `Array(N)` creates `[N]` |
| `.Push()` | `.Push(Values*)` | — | — | Appends one or more values; `arr.Push(other*)` appends another Array's items |
| `.Pop()` | `.Pop()` | Removed value | Error if empty | Same as `.RemoveAt(-1)` |
| `.InsertAt()` | `.InsertAt(Index, Values*)` | — | ValueError if Index < -Length or > Length + 1 | 0 means Length + 1; later items shift right |
| `.RemoveAt()` | `.RemoveAt(Index, Length?)` | Removed value (only when Length is omitted) | ValueError if the range is out of bounds | Later items shift left |
| `.Delete()` | `.Delete(Index)` | Removed value (blank if none) | ValueError if out of range | Element loses its value; Length unchanged |
| `.Has()` | `.Has(Index)` | Integer | — | Non-zero only if the index is valid **and** has a value |
| `.Get()` | `.Get(Index, Default?)` | Value | IndexError if out of range; UnsetItemError if no value, no Default argument and no `.Default` | Default argument applies only to in-range elements without a value |
| `.Clone()` | `.Clone()` | Array | — | Shallow copy |
| `.Length` | `.Length` / `.Length := n` | Integer | — | Includes elements without a value; increasing adds valueless elements, decreasing truncates |
| `.Capacity` | `.Capacity := n` | Integer | — | Reserve space; setting it below Length removes elements |
| `.Default` | `.Default := value` | — | — | Not defined by default; when defined, returned for elements without a value; does not prevent IndexError |
| `.__Item` | `arr[i]` | Value | IndexError / UnsetItemError | Negative `i` counts from the end |
| `__Enum` | `for v in arr` / `for i, v in arr` | Enumerator | — | Elements without a value leave the loop variable uninitialized |

### Global Functions Used with Arrays

| Function | Signature | Returns | Notes |
|----------|-----------|---------|-------|
| `Type()` | `Type(v)` | String | `"Array"` for Arrays (subclasses report their class name) |
| `is` | `v is Array` | 1 or 0 | True for Arrays and Array subclasses |
| `IsSet()` | `IsSet(var)` | 1 or 0 | Detect omitted optional parameters |
| `StrSplit()` | `StrSplit(String, Delimiters?)` | Array | String → Array |
| `Sort()` | `Sort(String, Options?, Callback?)` | String | Sorts a delimited **string**, not an Array |

### Module Helpers (defined below)

| Helper | Signature | Returns | Notes |
|--------|-----------|---------|-------|
| `IsValidIndex()` | `IsValidIndex(arr, i)` | 1 or 0 | 1 ≤ i ≤ Length |
| `GetRange()` | `GetRange(arr, start, end)` | Array | Inclusive slice, skips out-of-range |
| `SafeInsert()` | `SafeInsert(arr, i, v)` | Array | Clamps the index, then `InsertAt` |
| `RemoveValue()` | `RemoveValue(arr, v)` | Array | Removes every occurrence in place |
| `IndexOf()` | `IndexOf(arr, v, from := 1)` | Integer | 1-based index or 0 |
| `LastIndexOf()` | `LastIndexOf(arr, v)` | Integer | Right-to-left; index or 0 |
| `ArrayContains()` | `ArrayContains(arr, v)` | 1 or 0 | Wrapper around `IndexOf` |
| `FindIndex()` | `FindIndex(arr, pred)` | Integer | First index where `pred(value, index, arr)` is truthy, else 0 |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- **1-based indexing.** `arr[1]` is first, `arr[-1]` is last; `arr[0]` and any `|i| > Length` throw IndexError. Indexes and loop counters are 1-based; the `arr[0]` wrong form is in V1 → V2 BREAKING CHANGES.
- **`-1` is not "not found".** `-1` is a valid (last-element) index, so search helpers return `0` when nothing matches.
  ✗ `return -1` → ✓ `return 0`
- **`Length` is a property.** Write `arr.Length` with no parentheses; the `arr.Length()` wrong form is in V1 → V2 BREAKING CHANGES.
- **No built-in search or sort methods.** Use the helpers below or in Module_ArrayAlgorithms.md. The `arr.Sort()` wrong form is in V1 → V2 BREAKING CHANGES.
- **`Array(N)` is not pre-allocation.** Use `arr.Capacity := N`; Length stays 0. The `Array(10)` wrong form is in V1 → V2 BREAKING CHANGES.
- **Valueless elements.** `[1, , 3]`, `Delete()` and growing `Length` create elements without a value. Reading one with `arr[i]` throws UnsetItemError; use `Has()`, `Get(i, default)` or `.Default`.
- **Guard `Pop()`.** Check `arr.Length > 0` before calling `Pop()`.
  ✗ `x := queue.Pop()` → ✓ `if queue.Length` first
- **Equality on strings is case-insensitive.** `IndexOf` built on `=` matches `"abc"` and `"ABC"`; use `==` for case-sensitive matching.
- **Do not change the Array's shape while a `for` loop walks it** (advice). Removing inside `for i, v in arr` shifts later items and skips one; use a `while` loop with manual index, iterate backwards, or iterate `arr.Clone()`. Assigning `arr[i] := x` to existing indices is fine.
  ✗ `for i, v in arr { arr.RemoveAt(i) }` → ✓ `while` loop or backwards loop
- **`Clone()` is shallow.** Nested Arrays/Maps stay shared; see `DeepClone` in Module_ArrayAlgorithms.md.

Safe-access priority order:
1. `arr.Get(i, default)` — in-range element that may have no value
2. `arr.Has(i)` — when the branches differ
3. `IsValidIndex(arr, i)` — when the index may be out of range
4. `try`/`catch IndexError` — only when the error itself is useful

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Fix |
|----------------|-------------------|-----|
| `IndexError` | `arr[0]`, `arr[Length + 1]`, `arr.Get(99)` on a short Array | 1-based index; `IsValidIndex()` guard |
| `UnsetItemError` | Reading an element with no value (sparse literal, after `Delete`, after growing `Length`) | `Get(i, default)`, `Has(i)`, or `.Default` |
| `ValueError` | `InsertAt`/`RemoveAt`/`Delete` with an index outside the allowed range | Check `Length` first |
| `Error` | `Pop()` on an empty Array | `if arr.Length` first |
| `MethodError` | `arr.Sort()`, `arr.IndexOf()`, `arr.Length()` | Use helpers; `Length` without `()` |

## TIER 1 — Fundamentals: Creation, Access, and Type Verification
> METHODS COVERED: `[]` · `Array()` · `.Length` · `.Capacity` · `.Get()` · `.Has()` · `.Default` · `Type()` · `IsValidIndex()` · `GetRange()`

```ahk
numbers := [1, 2, 3, 4, 5]
mixed   := ["text", 42, true, [1, 2]]
empty   := []

preAllocated := []
preAllocated.Capacity := 10            ; Length stays 0
; bad := Array(10)                     ; ✗ → [10], Length 1

MsgBox(Type(numbers) " " (numbers is Array))   ; Array 1

first := numbers[1]
last  := numbers[-1]                   ; ✓ negative index from the end
secondToLast := numbers[-2]

sparse := [1, , 3]                     ; element 2 has no value
MsgBox(sparse.Has(2))                  ; 0
MsgBox(sparse.Get(2, "default"))       ; default
; MsgBox(sparse[2])                    ; ✗ UnsetItemError

sparse.Default := "N/A"
MsgBox(sparse[2])                      ; N/A
; MsgBox(sparse[99])                   ; ✗ IndexError — Default does not cover out-of-range

IsValidIndex(arr, index) {
    return index >= 1 && index <= arr.Length
}

GetRange(arr, start, end) {
    result := []
    loop end - start + 1 {
        i := start + A_Index - 1
        if IsValidIndex(arr, i)
            result.Push(arr[i])
    }
    return result
}
MsgBox(GetRange(numbers, 2, 4).Length) ; 3
```

## TIER 2 — Mutation: Add, Remove, and Clear
> METHODS COVERED: `.Push()` · `.Pop()` · `.InsertAt()` · `.RemoveAt()` · `.Delete()` · `.Length` setter · `SafeInsert()` · `RemoveValue()`

`Push`/`Pop` work at the end without shifting. `InsertAt`/`RemoveAt` shift later elements, so avoid head insertion/removal in tight loops on large Arrays. `arr.Length := 0` empties the Array in place (other references see the change); `arr := []` makes a new Array.

```ahk
arr := ["A", "B", "C"]
arr.Push("D", "E")                     ; A B C D E
last := arr.Pop()                      ; "E"
arr.InsertAt(1, "first")               ; prepend
arr.InsertAt(0, "append")              ; 0 = Length + 1
arr.InsertAt(-1, "beforeLast")         ; before the last element
removed := arr.RemoveAt(1)             ; "first"
arr.RemoveAt(2, 2)                     ; remove two items, no return value
arr.Delete(1)                          ; element 1 has no value; Length unchanged

if arr.Length > 0
    arr.Pop()                          ; ✓ guard: Pop on empty throws

other := ["x", "y"]
arr.Push(other*)                       ; append another Array's items

arr.Length := 0                        ; clear in place

SafeInsert(arr, index, value) {
    index := Max(1, Min(index, arr.Length + 1))
    arr.InsertAt(index, value)
    return arr
}

RemoveValue(arr, value) {
    i := 1
    while i <= arr.Length {
        if arr.Has(i) && arr[i] = value
            arr.RemoveAt(i)            ; next element shifts into i
        else
            i++
    }
    return arr
}
MsgBox(RemoveValue([1, 2, 1, 3], 1).Length)   ; 2

; ✗ Removing inside for-in skips the element that shifts into the removed slot
; for i, v in arr
;     if v = target
;         arr.RemoveAt(i)
```

## TIER 3 — Iteration, Search, and Predicates
> METHODS COVERED: `for` · `Loop` + `A_Index` · `IndexOf()` · `LastIndexOf()` · `ArrayContains()` · `FindIndex()`

Search helpers return a 1-based index on success and `0` when not found (0 is never a valid index, so it is a safe "not found" value).

```ahk
colors := ["red", "green", "blue"]
for color in colors
    OutputDebug(color)
for index, color in colors
    OutputDebug(index ": " color)
Loop colors.Length
    OutputDebug(colors[-A_Index])      ; last → first

IndexOf(arr, value, fromIndex := 1) {
    loop arr.Length - fromIndex + 1 {
        i := fromIndex + A_Index - 1
        if arr.Has(i) && arr[i] = value
            return i
    }
    return 0
}

LastIndexOf(arr, value) {
    loop arr.Length {
        i := arr.Length - A_Index + 1
        if arr.Has(i) && arr[i] = value
            return i
    }
    return 0
}

ArrayContains(arr, value) => IndexOf(arr, value) > 0

FindIndex(arr, predicate) {
    for index, value in arr
        if predicate(value, index, arr)
            return index
    return 0
}

nums := [4, 12, 7, 30]
MsgBox(IndexOf(nums, 7))                           ; 3
MsgBox(FindIndex(nums, (v, *) => v > 10))          ; 2
MsgBox(ArrayContains(colors, "GREEN"))             ; 1 — = is case-insensitive
```

## SEE ALSO

- `Module_ArrayAlgorithms.md` — DeepClone, ArrayMap/Filter/Reduce, QuickSort/SortBy, Unique, set operations, chunk/flatten recipes.
- `Module_Maps.md` — key-value storage.
- `Module_ContainerChoice.md` — choosing Array vs Map vs Object, nested structures.
- `Module_FunctionBasics.md` — variadic parameters and `arr*` spread.
- `Module_ExceptionHandling.md` — handling IndexError and UnsetItemError.
- `Module_GuiListViewTreeView.md` — filling ListView/ComboBox from Arrays.
