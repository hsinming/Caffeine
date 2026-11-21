# ahk-ctx-core Section Index

Per-heading detail for the routing table in `SKILL.md`. Find the row for the task, `grep -n "^## heading text"` the Reference module, and read that section through the next heading of the same level.

`## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` cover most routine tasks. Load a TIER section only when a complete example is needed. Every Reference module also has `## RUNTIME ERROR MAPPING` and `## SEE ALSO` sections. QA checks and anti-patterns live in `## AHK V2 CONSTRAINTS`.

### Functions — declaration, parameters, scope (Module_FunctionBasics.md)

| Task | Grep for heading |
|------|-----------------|
| Parameter forms: default, unset `?`, variadic `*`, ByRef `&` | `### Parameter Modifier Syntax` |
| Required → optional → variadic order | `### Parameter Order Rule` |
| `global` / `static` / `local`, assume-local reads | `### Scope Declaration Keywords` |
| `IsSet()` / `IsSetRef()` | `### IsSet / IsSetRef` |
| v1 → v2 breaking changes | `## V1 → V2 BREAKING CHANGES` |
| Constraints, QA checks and anti-patterns: call spacing, scope, ByRef, unset, parameter order | `## AHK V2 CONSTRAINTS` |
| **Example** — declaration and calling | `## TIER 1 — Basic Declaration and Calling` |
| **Example** — local, global, static | `## TIER 2 — Variable Scope: Local, Global, Static` |
| **Example** — default, unset, variadic | `## TIER 3 — Parameter Modifiers: Default, Unset, Variadic` |
| **Example** — ByRef output parameters | `## TIER 4 — ByRef Parameters: Output Params and In-Place Mutation` |

### Functions as values — closures, Func objects (Module_FunctionObjects.md)

| Task | Grep for heading |
|------|-----------------|
| Func methods/properties, `HasMethod` callability | `## API QUICK-REFERENCE` |
| Constraints, QA checks and anti-patterns: shared captures, reference cycles, dynamic calls | `## AHK V2 CONSTRAINTS` |
| **Example** — nested functions, closures, introspection | `## TIER 1 — Nested Functions, Closures, and Func Objects` |
| **Example** — multi-return, pure vs side effect | `## TIER 2 — Multi-Return and Pure vs Side-Effect Separation` |
| Memoize / TrySafeCall / DispatchFn | `## DROP-IN RECIPES` |

### Fat arrow functions and functional patterns (Module_FatArrowFunctions.md)

| Task | Grep for heading |
|------|-----------------|
| All `=>` forms (lambda, named, method, property) | `### Fat Arrow Syntax Forms` |
| Constraints, QA checks and anti-patterns: one expression, implicit object arg, read-only properties | `## AHK V2 CONSTRAINTS` |
| **Example** — basic syntax | `## TIER 1 — Basic Arrow Function Syntax` |
| **Example** — named arrows, recursion | `## TIER 2 — Named Arrow Functions and Recursion` |
| **Example** — closures and capture | `## TIER 3 — Closures and Variable Capture` |
| **Example** — fat-arrow properties | `## TIER 4 — Fat Arrow Properties` |
| **Example** — compose, curry, Bind, pipeline class | `## TIER 5 — Functional Programming Patterns` |
| Pipe / Partial | `## DROP-IN RECIPES` |

### Objects — Any/Object API, literals, binding (Module_ObjectBasics.md)

| Task | Grep for heading |
|------|-----------------|
| `Any` methods (`HasProp`, `HasMethod`, `GetMethod`, `Base`) | `### Any (root — every value except COM objects inherits these)` |
| `Object` methods (`Clone`, `OwnProps`, `HasOwnProp`) | `### Object (instance methods)` |
| `.Bind(this)` vs `ObjBindMethod` | `### Binding Methods for Callbacks` |
| `Type()`, `is`, `IsObject` | `### Type Introspection` |
| Constraints, QA checks and anti-patterns: `new`, callback binding, literals vs Map | `## AHK V2 CONSTRAINTS` |
| **Example** — fundamentals | `## TIER 1 — Object Fundamentals, Creation, and the Any Root` |
| **Example** — inheritance, prototype extension | `## TIER 2 — Class Inheritance and Prototype Extension` |
| **Example** — bound callbacks (SetTimer, OnEvent) | `## TIER 3 — BoundFunc and Callback Context Management` |

### Property descriptors (Module_PropertyDescriptors.md)

| Task | Grep for heading |
|------|-----------------|
| `DefineProp`, `GetOwnPropDesc`, descriptor keys | `## API QUICK-REFERENCE` |
| Constraints, QA checks and anti-patterns: `this` first, partial redefinition, read-only | `## AHK V2 CONSTRAINTS` |
| **Example** — get/set/call + class property blocks | `## TIER 1 — Property Descriptors: get, set, call, and DefineProp` |
| **Example** — runtime properties over a Map | `## TIER 2 — Runtime Properties from a Backing Map` |
| **Example** — validated config | `## TIER 3 — Validated Objects and Config Patterns` |
| SafeGetProp / BindAll / MakeReadOnly | `## DROP-IN RECIPES` |

### Classes — definitions, constructors, inheritance (Module_ClassBasics.md)

| Task | Grep for heading |
|------|-----------------|
| Class members syntax table | `### Class Members` |
| `ClassName()`, `__New`, `super`, static `__New` | `### Construction` |
| v1 → v2 breaking changes | `## V1 → V2 BREAKING CHANGES` |
| Constraints, QA checks and anti-patterns: `new`, `super()`, static access, class-name reuse | `## AHK V2 CONSTRAINTS` |
| **Example** — constructors, properties, static, timers | `## TIER 1 — Class Fundamentals: Constructors, Properties, and Static Members` |
| **Example** — inheritance, polymorphism | `## TIER 2 — Inheritance and Polymorphism` |
| **Example** — nested classes, factories | `## TIER 3 — Nested Classes and Factory Patterns` |

### Meta-functions — __Get/__Set/__Call/__Item/__Enum (Module_ClassMetaFunctions.md)

| Task | Grep for heading |
|------|-----------------|
| Signatures and default actions | `### Meta-Functions` |
| `__Item`, `__Enum`, `Call` | `### Special Members` |
| Constraints, QA checks and anti-patterns | `## AHK V2 CONSTRAINTS` |
| **Example** — property bags | `## TIER 1 — Dynamic Property Bags with __Get and __Set` |
| **Example** — `__Call`, `__Item`, `__Enum` | `## TIER 2 — __Call, __Item and __Enum` |
| **Example** — fluent builder | `## TIER 3 — Fluent Interfaces` |
| TypedStore | `## DROP-IN RECIPES` |

### Lifetime — __Delete, Dispose, cycles (Module_ClassLifecycle.md)

| Task | Grep for heading |
|------|-----------------|
| `__Delete`, Dispose, ObjPtr family | `## API QUICK-REFERENCE` |
| Constraints, QA checks and anti-patterns: reference counting, cycles, termination, Dispose | `## AHK V2 CONSTRAINTS` |
| **Example** — Dispose + try/finally | `## TIER 1 — Resource Management with Dispose and try/finally` |
| **Example** — observer with subscriptions | `## TIER 2 — Observer Pattern with Explicit Subscriptions` |
| **Example** — timer without keeping object alive | `## TIER 3 — Timers Without Keeping the Object Alive` |
| MakeTimerSubscription / Disposable | `## DROP-IN RECIPES` |

### Arrays — API, indexing, mutation, search (Module_ArrayBasics.md)

| Task | Grep for heading |
|------|-----------------|
| Array methods/properties | `### Array (built-in)` |
| Constraints, QA checks and anti-patterns: 1-based, valueless elements, no Sort | `## AHK V2 CONSTRAINTS` |
| Runtime errors | `## RUNTIME ERROR MAPPING` |
| **Example** — creation, access | `## TIER 1 — Fundamentals: Creation, Access, and Type Verification` |
| **Example** — mutation | `## TIER 2 — Mutation: Add, Remove, and Clear` |
| **Example** — iteration, IndexOf, FindIndex | `## TIER 3 — Iteration, Search, and Predicates` |

### Array algorithms (Module_ArrayAlgorithms.md)

| Task | Grep for heading |
|------|-----------------|
| Helpers table, `StrCompare`, `Sort()` | `## API QUICK-REFERENCE` |
| Constraints, QA checks and anti-patterns: string comparison, name shadowing, in-place sort | `## AHK V2 CONSTRAINTS` |
| **Example** — DeepClone, ArrayMap, Filter, Reduce | `## TIER 1 — Transformations: Clone, DeepClone, ArrayMap, Filter, Reduce` |
| **Example** — QuickSort, SortBy | `## TIER 2 — Sorting with Comparators` |
| **Example** — Unique, lookups | `## TIER 3 — Deduplication, Lookups, and In-Place Updates` |
| **Example** — set operations | `## TIER 4 — Set Operations: Difference, Intersection, Union, Without` |
| SafePop / ChunkArray / Flatten | `## DROP-IN RECIPES` |

### Maps (Module_Maps.md)

| Task | Grep for heading |
|------|-----------------|
| Map methods/properties | `### Map` |
| Key rules | `### Key Rules` |
| Constraints, QA checks and anti-patterns: missing keys, CaseSense, Delete | `## AHK V2 CONSTRAINTS` |
| **Example** — construction, safe access | `## TIER 1 — Map Construction, Safe Access, and Mutation` |
| **Example** — CaseSense, Clone, Capacity | `## TIER 2 — CaseSense, Clone, and Capacity` |
| **Example** — enumeration, Keys helper | `## TIER 3 — Enumeration and a Keys() Helper` |
| MapFromArrays / MapMerge / MapInvert | `## DROP-IN RECIPES` |

### Choosing containers (Module_ContainerChoice.md)

| Task | Grep for heading |
|------|-----------------|
| Which container for which need | `### Which Container` |
| Has/Get/Default across Array and Map | `### Shared Guard API` |
| **Example** — Array vs Map vs Object | `## TIER 1 — Choosing Array vs Map vs Object` |
| **Example** — nested records, static tables | `## TIER 2 — Nested Structures and Static Lookup Tables` |
| **Example** — IndexError / UnsetItemError guards | `## TIER 3 — Defensive Guards: IndexError and UnsetItemError` |

### Advanced: runtime prototyping — opt-in (Module_RuntimePrototyping.md)

| Task | Grep for heading |
|------|-----------------|
| Descriptor/prototype functions | `### Descriptor and Prototype Functions` |
| Constraints, QA checks and anti-patterns | `## AHK V2 CONSTRAINTS` |
| **Example** — call/get/set on one object | `## TIER 1 — Descriptor Fundamentals: Call, Get and Set on One Object` |
| **Example** — guards, inspection | `## TIER 2 — Existence Guards and Descriptor Inspection` |
| **Example** — Base changes, built-in prototypes | `## TIER 3 — Changing Bases and Extending Built-in Prototypes` |
| SafeDefineProp / CopyOwnDescriptors | `## DROP-IN RECIPES` |

### Advanced: runtime class factory — opt-in (Module_RuntimeClassFactory.md)

| Task | Grep for heading |
|------|-----------------|
| Class construction pieces | `### Class Construction Pieces` |
| **Example** — closure factories | `## TIER 1 — Closure Factories: Context-Aware Properties` |
| **Example** — method decorators | `## TIER 2 — Method Decorators: Non-Destructive Interception` |
| **Example** — runtime class generation | `## TIER 3 — Runtime Class Generation (v2.0-compatible)` |
