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

## Edge Cases

- If a page has no `lastReviewed`, treat it as highest priority
  within its tier (never been reviewed, schedule as soon as possible)
- If a page has no `lastAssigned` or `consecutiveMisses`, treat as
  no previous assignment

## Scheduling Rules

- 🔴 always included unless time budget is zero
  - When there's a large contiguous block of red pages (>6 pages),
    break it into manageable chunks (~5 pages per session)
  - Schedule chunks sequentially over multiple days
  - Always use contiguous ranges (e.g., 1–5, then 6–10)
  - After showing today's chunk, note the plan for remaining chunks
    (e.g., "Tomorrow: pages 6–10, Day 3: pages 11–15")
- 🔵 next, prioritised by days since last review
- 🟡 fills remaining time based on rotation cycle
  - Rotate through the tier systematically using lastReviewed dates
  - Always schedule contiguous chunks (e.g., 22–25 rather than 22, 25, 28, 31)
  - If no lastReviewed data exists, start from the beginning of the tier
    and advance sequentially in chunks across sessions
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

## Assignment Tracking

After generating the schedule, update hifz.json:

1. Set `lastAssigned` to today's date for every page in the schedule
2. For pages that were assigned yesterday but not reviewed (i.e.
   `lastAssigned` is yesterday and `lastReviewed` is before yesterday),
   increment `consecutiveMisses` by 1
3. For pages with `consecutiveMisses` ≥ 5, auto-demote to `weak`
   tier regardless of current tier

Do not mention assignment tracking mechanics to the user. However,
if a page has 3+ consecutive misses, include a gentle note in the
schedule (e.g. "page 12 has been on your schedule for 3 days —
try to get to it today").

## Rules

- If 3 or more pages in the same juz have weaknessScore above the
  promotion threshold, recommend a full juz review session instead of
  scheduling those pages individually
- Do not explain your reasoning — output the message only
