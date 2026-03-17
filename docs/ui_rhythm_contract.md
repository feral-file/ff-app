# UI Rhythm Contract (Flutter)

Purpose: keep Figma intent while shipping readable, polished mobile UI with minimal process.

## Scope

This contract applies to all user-facing Flutter UI in this repository.

## Non-negotiables

- Use a 4pt spacing grid.
- No new ad-hoc spacing or font-size magic numbers in UI widgets.
- Primary reading text must be `>= 16sp`.
- Supporting text must be `>= 14sp`.
- Meta/micro text may be `12sp` only when non-primary.
- Interactive tap targets must be `>= 44x44`.

## Rhythm Tokens

Use shared tokens (in `lib/design/`) for layout and type. Prefer semantic names over raw values.

- Spacing tiers: `4, 8, 12, 16, 20, 24, 32, 40`.
- Common rails and row rhythm should come from tokens, not per-screen literals.
- Divider, radius, and icon sizing should use shared constants.

## Typography Rules

- Keep hierarchy semantic:
  - Primary content/title: readable and stable (`16sp+`).
  - Secondary/supporting content: `14sp+`.
  - Meta labels only: `12sp` when needed.
- Do not downsize primary text to match tiny Figma text literally.
- Preserve legibility over pixel parity when conflicts exist.

## Figma Handoff (Design)

For each screen handoff, include only:

- Primary mobile frame URL + node id.
- Key spacing rails and container paddings.
- Text roles (`primary`, `support`, `meta`) instead of many one-off sizes.
- Required states: default/loading/empty/error.
- 3-5 critical visual constraints (what must not drift).

## Build Workflow (Engineering)

For each screen update:

1. Map Figma structure to existing rhythm tokens.
2. If a number repeats across screens, promote to token first.
3. Implement UI using tokens only.
4. Validate on real device size(s) for readability.
5. Capture before/after screenshots and note any intentional deviations.

## Drift Review Loop

One lightweight loop per screen:

1. Designer handoff
2. Engineering implementation pass
3. 20-minute joint review (Todd/Lucian + engineer) with annotated drift list
4. Final polish pass

No extended ceremony. One pass, clear decisions.

## PR Checklist (UI)

- [ ] Uses rhythm/type tokens (no new magic numbers)
- [ ] Meets text-size floors (`16/14/12` rules)
- [ ] Meets touch target minimums (`44x44`)
- [ ] Includes screenshots for changed screens
- [ ] Notes any intentional Figma deviations with reason
