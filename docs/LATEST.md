# Palette Current Status

Current Milestone

Wave Explorer

Latest Session

docs/sessions/2026-08-04.md

Current Goal

Finish the Wave Explorer 1.0 hardware-verification pass: confirm physical
control numbers against the friendly mapping, keep the transport test-backed,
and document the verified behavior before building Palette features.

Repository Status

The working Swift package now lives in `WaveExplorer_V2/` in this repository.
The package connects to Tangent Hub, receives live Wave events, writes all
three OLED displays, builds successfully, and has ten passing tests.

Immediate Next Task

Run the short physical mapping check and correct only confirmed mismatches.

Do Not Change

- Resolve owns grading.
- Palette owns plugin mode.
- Use TIPC.
- Keep scope small.
