# Weakness Score Reference

## Overview

The weakness score is a decimal value (0.0–1.0) that represents how shaky a page's memorization is. It determines when pages can promote between tiers and helps prioritize scheduling.

## Initial Values by Tier

When setting up a new page during onboarding, assign the initial weakness score based on the user's assessment:

| User Description | Tier | Initial Score | Reasoning |
|-----------------|------|---------------|-----------|
| "Forgotten" / "Very weak" / "Rusty" | 🔴 Red | 0.8–0.9 | Needs many clean reviews before promoting (🔴→🔵 threshold is ≤0.2) |
| "Recently memorized" / "Still needs work" / "A bit weak" | 🔵 Blue | 0.3–0.4 | Some issues expected, actively improving |
| "Solid" / "Established" / "Confident" | 🟡 Yellow | 0.05–0.15 | Occasional slips only, well-maintained |

**Guidelines:**
- If the user is uncertain or vague, use the midpoint of the range
- If they give mixed signals (e.g., "solid but haven't reviewed in a while"), bias toward higher weakness
- Never set initial weakness below 0.05 — even solid pages need monitoring

## Adjustment Over Time

After each review session, update the weakness score based on performance:

| Event | Adjustment | Notes |
|-------|-----------|-------|
| Clean review (no issues) | -0.05 | Gradual improvement with repeated success |
| Minor issue flagged | +0.08 | Small slip, but noticeable |
| Major issue flagged | +0.15 | Significant struggle on that page |

**Constraints:**
- Weakness score is clamped to [0.0, 1.0]
- If a page drops below the promotion threshold and meets review count requirements, it promotes automatically

## Promotion Thresholds

Default thresholds (user-configurable):

- **🔴 → 🔵**: weakness score ≤ 0.2 AND ≥ 5 clean reviews
- **🔵 → 🟡**: ≥ 5 total reviews (weakness score not gating, but should trend downward)

## Example: Red Page Recovery

A forgotten page starts at weakness 0.9:

| Session | Event | New Score | Notes |
|---------|-------|-----------|-------|
| 1 | Clean review | 0.85 | -0.05 |
| 2 | Clean review | 0.80 | -0.05 |
| 3 | Minor issue | 0.88 | +0.08 (setback) |
| 4 | Clean review | 0.83 | -0.05 |
| 5 | Clean review | 0.78 | -0.05 |
| 6 | Clean review | 0.73 | -0.05 |
| ... | ... | ... | ... |
| ~15 | Clean review | ≤0.20 | Eligible for 🔴→🔵 promotion (if 5+ clean reviews since last flag) |

## Usage

- **During onboarding**: Use the "Initial Values" table to assign weakness scores based on user descriptions
- **During session logging**: Apply adjustments based on the user's reported performance
- **During scheduling**: Pages with higher weakness scores within a tier are prioritized for review
