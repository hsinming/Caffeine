---
name: ahk-ctx-core
description: >
  AutoHotkey v2 core language reference. Use when writing, modifying, or reviewing .ahk code that
  involves functions and parameters (ByRef, variadic, scope), closures and arrow functions, objects and DefineProp
  descriptors, classes and meta-functions, object lifetime (__Delete), arrays, Maps, container choice, or
  v1-to-v2 conversion.
metadata:
  version: "2026.10.16"
---

# AHK v2 Core Context

Read `references/Module_Instructions.md` in full first; its `<how_to_use>` is the flow for this Skill.
Then load `references/Module_CodeStyle.md` in full when writing or editing AHK.

## Router

Read the listed heading through the next `## ` heading. `references/SECTION_INDEX.md` lists every
heading per Module, including TIER examples.

| Signal | Module | Heading |
|---|---|---|
| function, parameter, `&`, `*`, `?`, `IsSet`, scope, `global`, `static` | `Module_FunctionBasics.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| closure, nested function, Func object, `Bind`, dynamic call, multi-return | `Module_FunctionObjects.md` | `## API QUICK-REFERENCE` |
| `=>`, lambda, arrow function, fat-arrow property, compose, curry | `Module_FatArrowFunctions.md` | `## AHK V2 CONSTRAINTS` |
| object, object literal, `HasProp`, `Type`, `is`, callback binding | `Module_ObjectBasics.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| `DefineProp`, getter/setter, descriptor, read-only property | `Module_PropertyDescriptors.md` | `## API QUICK-REFERENCE` |
| class, `__New`, `extends`, `super`, static, nested class | `Module_ClassBasics.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| `__Get`, `__Set`, `__Call`, `__Item`, `__Enum`, fluent | `Module_ClassMetaFunctions.md` | `### Meta-Functions` |
| `__Delete`, dispose, cleanup, reference cycle, `ObjPtr`, observer | `Module_ClassLifecycle.md` | `## AHK V2 CONSTRAINTS` |
| Array, index, `Push`, `Pop`, `RemoveAt`, search | `Module_ArrayBasics.md` | `## API QUICK-REFERENCE` or `## TIER 3 — Iteration, Search, and Predicates` |
| sort, dedup, `Filter`, `Reduce`, deep copy, set operations | `Module_ArrayAlgorithms.md` | `## API QUICK-REFERENCE` |
| Map, key-value, `CaseSense`, `Default`, `Has`, `Get` | `Module_Maps.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| Map vs Array vs Object, nested data, IndexError/UnsetItemError guards | `Module_ContainerChoice.md` | `### Which Container` |
| runtime prototype change, `Base`, built-in prototype extension (opt-in) | `Module_RuntimePrototyping.md` | `## AHK V2 CONSTRAINTS` |
| runtime class generation, decorators (opt-in) | `Module_RuntimeClassFactory.md` | `## AHK V2 CONSTRAINTS` |
| GUI, window, control | `../ahk-ctx-ui/references/Module_GuiBasics.md` | per `ahk-ctx-ui` |
| try/catch, async, error handling | `../ahk-ctx-logic/references/Module_ExceptionHandling.md` | per `ahk-ctx-logic` |
| DLL, COM, system calls | `../ahk-ctx-system/references/Module_DllCallBasics.md` | per `ahk-ctx-system` |

Descend into a `## TIER` section when the task needs a runnable example. A normal class or object
task does not need the two opt-in meta-programming Modules.

## Critical Rules

- Instance members are `this.property`; static members are `ClassName.property`.
- A derived class reaches base behavior through `super.Method()`.

## Cross-Skill Dependencies

Every other `ahk-ctx-*` reference Skill loads `references/Module_Instructions.md`. Further borrowed Modules:

| Referencing Skill | Modules borrowed |
|-------------------|-----------------|
| `ahk-ctx-logic` | `references/Module_FatArrowFunctions.md` |
| `ahk-ctx-ui` | `references/Module_ClassBasics.md`, `references/Module_FatArrowFunctions.md` |
| `ahk-ctx-uia` | `references/Module_ClassBasics.md` |

## Verification

Report snippets as compiled only after `AutoHotkey64.exe /ErrorStdOut path\to\script.ahk` passed on a
Windows AHK v2 interpreter; static review is not equivalent.
