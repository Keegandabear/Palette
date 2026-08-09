# Control Map (unused while WaveExplorer runs unmanaged)

WaveExplorer runs the Hub in **unmanaged mode** (see top-level README,
"Managed vs. unmanaged") — it sends an application definition with empty
system/user directory paths, so the Hub never looks for XML files here.
This folder exists as a place to put them if/when something in this
codebase switches to managed mode.

If you do switch: `controls.xml` and `wave-map.xml` (as provided in the
Developer Support Pack) are the two files that matter — `controls.xml`
declares your app's abstract parameters/menus/actions/modes, and
`wave-map.xml` maps a specific panel's physical controls (by type +
number, e.g. `<Control type="Encoder" number="13">`) onto them. The
control numbers in a map file are exactly the same numbers WaveExplorer's
unmanaged-mode events report — that's how `WaveControlNaming` was seeded
(trackball 1 = encoders 9/13/14, confirmed from the sample `wave-map.xml`).
