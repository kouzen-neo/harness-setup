<!-- when: Writing or reviewing code (god files, magic numbers, slop); offer to refactor existing problems -->
# Code quality

- Never write god files: keep each file focused on one responsibility, and split large modules by concern instead of growing one file.
- No magic numbers or magic strings: give thresholds, sizes, timeouts, paths, and repeated literals a named constant or a config value.
- No slop: no dead or commented-out code, no copy-pasted blocks, no unused parameters or imports, no speculative abstractions, no comments that only restate the code, no vague names, no swallowed exceptions.
- If existing code already has these problems (god files, magic numbers, slop), do not silently rewrite it and do not silently copy the pattern: tell the owner what you found and offer to refactor it (ask if they want it changed) before touching it.
