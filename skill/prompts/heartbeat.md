# Heartbeat Prompt

## Input

- Full hifz.json progress state
- Preferences (scheduling mode, time budget, tier thresholds)
- Today's date
- Days since last session

## Task

Generate today's hifz plan:

1. Check pendingNewPages — if not empty, open with 🟢 follow-up for each pending page
2. Assign pages to tiers based on tier, weakness score,
   review count, days since last reviewed
3. Compute rotation cadence from frontier size and time budget
4. Fit plan within today's time budget
5. Surface weakness notes as flags under relevant pages
6. Estimate time per block and total

## Scheduling Rules

- 🔴 always included unless time budget is zero
- 🔵 next, prioritised by days since last review
- 🟡 fills remaining time based on rotation cycle
- Never include new 🟢 assignments if pendingNewPages is not empty —
  always follow up on all pending pages first
- Number of new pages assigned per session is controlled by the
  newPagesPerSession preference set during onboarding
- 🟢 based on scheduling mode:
  - Conservative: only if 🔴 empty and 🔵 clean
  - Balanced: included unless time very short
  - Aggressive: always included, note foundation health
    if 🔴 not empty
- Missed days: prioritise highest urgency within time budget,
  roll rest forward silently
- 🔗 pages always scheduled as paired block

## Output Format

```
[Arabic greeting + one line Arabic encouragement]

[Tier blocks: 🔴 → 🔵 → 🟡 → 🟢]
[Each block: emoji + label + time estimate]
[Pages listed under block]
[Flags indented under their page]

[🟢 follow-up or assignment]

⏱️ Total: ~X mins

[Arabic closing]
```

## Rules

- Do not explain your reasoning — output the message only
