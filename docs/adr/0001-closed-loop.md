# Closed Loop: local, script-judged, bounded

AI agents change `caffeine.ahk` from `ready-for-agent` issues. Before this decision nothing independent checked their work, the agent decided on its own that it was done, and AutoHotkey error dialogs hung unattended runs. We decided on a Closed Loop with these parts (spec #1):

- **Local only, no CI.** The loop runs on the maintainer's machine. Tests need a Windows desktop with AutoHotkey v2 and the real tray app; CI was considered and dropped to keep the loop simple and the maintainer in control of what is published. The agent commits on `main` and never pushes without approval.
- **The Tester is a script, not an LLM.** `test.ps1` runs the tests headless with `/ErrorStdOut`, kills a hung run after 30 s, and writes one JSON Test Result. The agent that wrote the code cannot declare its own work correct; the verdict is deterministic and machine-readable, with file, line, expected, actual and stack.
- **Pre-commit Quality Gate and `--no-verify` ban.** `.githooks/pre-commit` re-runs the tests and the build, so no broken commit reaches the repository; `test.ps1` sets `core.hooksPath` so a fresh clone is protected after its first Test Run. A gate that can be skipped is not a gate, so `.claude/settings.json` denies `git commit --no-verify` and `-n`, and the agent instructions state the same rule.
- **Stop limits.** The agent escalates after the same test fails 3 rounds in a row, or after 5 rounds in total, where a Reviewer `CHANGES` counts as a round. Without a bound an agent burns effort on a problem it cannot solve, and review could loop forever; the human starts from the last Test Result.
- **No telemetry.** Bug reports come only from a user who chooses "Report a Bug", which opens a pre-filled GitHub issue form. Caffeine sends nothing on its own, to respect user privacy.
- **No performance metrics.** Caffeine has no performance-sensitive path; measuring it would add cost to every Test Run for no decision it would inform.
