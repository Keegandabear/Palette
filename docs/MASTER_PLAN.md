# Palette Master Plan

## Goal
Build Palette v1 for DaVinci Resolve + Tangent Wave.

## Non-negotiable decisions
- Preserve Resolve's native Tangent grading.
- Palette controls DCTL/OFX/plugin parameters.
- Use Tangent TIPC SDK.
- Use data-driven workspace definitions.
- Resolve first; Capture One later.

## Build order
1. Workspace specification
2. Swift core
3. TIPC integration
4. Resolve adapter
5. DCTL/OFX control
