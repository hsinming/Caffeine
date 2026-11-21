# Caffeine

Caffeine is a Windows tray app that keeps the system awake. These terms describe the app and the agent-driven workflow that changes it.

## Product

**Active**:
The state in which Caffeine keeps the system and the display awake.
_Avoid_: on, enabled, caffeinated

**Inactive**:
The state in which Caffeine lets Windows sleep and turn off the display as usual.
_Avoid_: off, disabled, paused

**Indefinite**:
An Active period with no End Time; it lasts until the user changes it or exits Caffeine.
_Avoid_: forever, permanent

**End Time**:
The moment a timed Active period ends and Caffeine becomes Inactive. A duration and a clock time are two ways to choose the same End Time.
_Avoid_: deadline, expiry, target time

**Toggle**:
A click on the tray icon that makes any Active period Inactive, and makes Inactive into Active Indefinite.
_Avoid_: switch, flip

## Workflow

**Closed Loop**:
The repeated cycle of plan, develop, Test Run, fix and review that takes one issue to a commit, or to an Escalation.
_Avoid_: pipeline, CI, workflow

**Quality Gate**:
A pass/fail check every change must pass before it is committed: all tests pass, the executable builds, and the Reviewer approves.
_Avoid_: check, guard

**Test Run**:
One execution of the deterministic test runner over the smoke test and every test suite.
_Avoid_: test pass, test cycle

**Test Result**:
The single JSON record a Test Run produces; the only source of truth for whether tests passed and why they failed.
_Avoid_: test report, test output, test log

**Escalation**:
Ending the Closed Loop on an issue before it passes, and handing the issue to a human with the last Test Result.
_Avoid_: give up, abort, failure
