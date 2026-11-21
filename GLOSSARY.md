# Caffeine

Caffeine is a Windows tray app that keeps the system awake. These terms describe the agent-driven workflow that changes it.

## Language

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
