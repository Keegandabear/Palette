# Research Log
08.09.26 @ 2:20 pm

# DaVinci Resolve Color-Page Parameter Control Research

**Date:** August 9, 2026  
**Installed Resolve checked:** DaVinci Resolve 21.0.0, build 21.0.00048  
**Product target:** `Tangent Wave → Palette → Resolve Color page → DCTL or OFX parameter`

## Executive Answer

An external macOS application cannot currently change an **arbitrary existing Color-page DCTL or OFX parameter through Resolve's official scripting API**.

The official API exposes a Color-page node graph, but its graph object stops at node-level operations and tool-name discovery. It does not expose a scriptable handle for an effect instance or a `GetParameter`/`SetParameter` operation for the DCTL or OFX controls inside that node.

The practical conclusion is:

- **Color-page native controls:** some are directly supported through the official API, but only where Blackmagic exposes a dedicated method such as CDL, LUT, node enablement, or node cache mode.
- **Color-page OFX parameters:** not directly supported for arbitrary effect instances by the Resolve scripting API. A custom OFX plugin could be designed as its own bridge, but that would control the custom plugin's own parameters, not arbitrary parameters of unrelated existing OFX effects.
- **Color-page DCTL `DEFINE_UI_PARAMS`:** no documented Resolve scripting API access was found. DCTL UI parameters are declared in DCTL source and bound to Resolve's DCTL UI, but the Color-page scripting API provides no parameter-level object or setter.

Therefore the requested arbitrary-DCTL proof is **not directly supported** and is best classified as **NOT POSSIBLE through the official API**. A constrained custom-plugin route is **POSSIBLE BUT REQUIRES A BRIDGE/PLUGIN**, but it would require changing the effect strategy rather than remotely editing any arbitrary DCTL already on a node.

## Scope and Non-Goals

This investigation intentionally stayed Color-page-only. It did not:

- build Fusion integration;
- build Palette UI or networking;
- connect the Tangent Wave to Resolve;
- modify `WaveExplorerCore`, TIPC, the event model, or verified mappings;
- add dependencies or redesign the Palette architecture;
- create a Resolve project, install a test DCTL, or alter a user's grade.

The earlier Fusion-page proof-of-concept is not treated as evidence for Color-page control.

## Evidence Checked

### Local installed Resolve materials

The following files belong to the installed Resolve 21.0.0 developer package and were inspected directly:

- `/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/README.txt`
- `/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/CHANGELOG.txt`
- `/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules/DaVinciResolveScript.py`
- `/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/DaVinciCTL/README.txt`
- `/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/OpenFX/README.txt`
- `/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/OpenFX/Support/`
- `/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/OpenFX/GainPlugin/`

### Non-destructive runtime check

The official Python bridge loaded successfully from Resolve's installed `fusionscript.so`. Calling `scriptapp("Resolve")` returned `None` because Resolve was not connected/running for scripting at the time of the check. No project or grade was changed.

This confirms the installed bridge can be imported, but it does **not** constitute the requested visual proof of changing a Color-page DCTL parameter. That proof was deliberately not run because the task explicitly said not to implement or connect the proof-of-concept yet. The report therefore separates verified installed-file evidence from conclusions that still require an approved isolated OFX experiment.

### Official external sources

- Blackmagic Resolve scripting documentation is distributed with the installed application and is the primary source for the API claims above.
- OpenFX reference documentation: <https://openfx.readthedocs.io/en/main/Reference/ofxParameter.html>
- OpenFX parameter suite reference: <https://openfx.readthedocs.io/en/main/Reference/ofxParameter.html#parameter-suite>
- OpenFX packaging/installation reference: <https://openfx.readthedocs.io/en/main/Reference/ofxPackaging.html>

## 1. Official Resolve Scripting API

Resolve's installed scripting README states that scripts can run in Python or Lua, through the Console, command line, or — when enabled in Preferences — from the local network. The script must load `DaVinciResolveScript` and connect to a running Resolve process.

The scripting README also documents Resolve's object model, including project, timeline, media-pool, render, and Color-page graph objects. The scripting bridge is not a general public REST/socket API and does not expose an official Swift-native interface.

For Palette, the supported external shape would be a helper process that invokes the Resolve scripting API, not a direct Swift call into an undocumented Resolve protocol.

## 2. Color-Page Node Access

The installed API's `Graph` object exposes these Color-page operations:

- `GetNumNodes()`
- `SetLUT(nodeIndex, lutPath)` and `GetLUT(nodeIndex)`
- `SetNodeCacheMode(nodeIndex, cache_value)` and `GetNodeCacheMode(nodeIndex)`
- `GetNodeLabel(nodeIndex)`
- `GetToolsInNode(nodeIndex)`
- `SetNodeEnabled(nodeIndex, isEnabled)`
- grade-level operations such as `ApplyGradeFromDRX()`, `ApplyArriCdlLut()`, and `ResetAllGrades()`

The important limitation is `GetToolsInNode()`: the documentation describes its result as a list of **strings** naming the tools used in the node. It does not return a tool object, parameter collection, or editable effect handle.

No documented Color-page graph method was found for:

- getting a node's arbitrary effect instance;
- getting an OFX parameter by script name;
- setting an OFX parameter value;
- getting a DCTL parameter by `DEFINE_UI_PARAMS` variable name;
- setting a DCTL parameter value;
- reading back arbitrary Color-page effect parameters.

## 3. Required Distinction: A, B, and C

### A. Color-page native Resolve controls

**Category: DIRECTLY SUPPORTED, but only for explicitly exposed controls.**

The official API can change certain native or grade-level data through dedicated methods. Examples include:

- node enabled/disabled state;
- node cache mode;
- LUT assignment;
- CDL assignment;
- applying a grade from a `.drx` file;
- node labels and other documented node operations where available.

This proves that Resolve can expose selected Color-page controls to scripting. It does **not** prove that every visible Color-page control is scriptable.

### B. Color-page OFX parameters

**Category for arbitrary existing OFX effects: NOT POSSIBLE through the official Resolve scripting API.**

OpenFX itself has a parameter suite. An OFX plugin receives a host-provided parameter set and can define parameters such as doubles, choices, booleans, colors, and strings. The installed Resolve OpenFX examples demonstrate defining plugin parameters and handling parameter changes inside the plugin.

That is an interface between an OFX plugin and its host. It is not a Resolve scripting API for an external application to enumerate an arbitrary Color-page OFX instance and mutate its parameters. The installed Resolve `Graph` API does not expose the OFX parameter suite for a node's tools.

### C. Color-page DCTL `DEFINE_UI_PARAMS` parameters

**Category: NOT POSSIBLE through the official Resolve scripting API.**

The installed DCTL documentation confirms that `DEFINE_UI_PARAMS` declares custom controls such as:

- float sliders;
- integer sliders;
- value boxes;
- checkboxes;
- combo boxes;
- color pickers.

The declared variable is linked to the DCTL transform, and the documentation says changes made through the Resolve UI, undo actions, or DCTL logic are reflected in both the Resolve UI and the DCTL variable.

However, this DCTL documentation does not define an external scripting API for those controls. The Resolve Color-page `Graph` API likewise contains no DCTL parameter getter or setter. `DEFINE_UI_PARAMS` therefore gives a DCTL a visible UI, but not an externally addressable Color-page scripting object.

## 4. Is There a Color-Page Equivalent to Fusion Tool-Input Scripting?

No documented equivalent was found.

Fusion exposes a composition/tool object model. Fusion scripts can obtain a tool and set an input on that tool. That is a different object model from the Color-page `Graph` API.

The existence of Fusion tool-input scripting must not be generalized to Color-page nodes. A DCTL or OFX effect inside a Fusion composition is not evidence that the same effect's parameter is scriptable when applied to a Color-page node.

## 5. Resolve-Side Plugin or OFX Bridge

### What is technically possible

A custom OFX plugin can be written with parameters owned by that plugin. Its implementation could be designed to communicate with a companion external app over a deliberately chosen local IPC channel, for example:

- a localhost socket;
- a Unix-domain socket;
- a carefully designed shared-memory or file-based protocol.

The plugin could use incoming values while rendering and could potentially ask the host to update its own parameter state through the OpenFX parameter suite. The exact host-threading and UI-refresh behavior would need a small, isolated experiment.

**Classification: POSSIBLE BUT REQUIRES A BRIDGE/PLUGIN.**

### The critical limitation

This does **not** create a generic remote-control layer for arbitrary existing Color-page DCTLs or OFX plugins.

A custom bridge plugin cannot automatically obtain a handle to an unrelated ResolveFX, third-party OFX, or DCTL instance already present in another node. The bridge would control:

- its own parameters;
- or parameters of a plugin specifically written/cooperating to expose that bridge;
- or a replacement effect whose implementation is designed around the external control channel.

For an arbitrary existing DCTL, there is no documented path for a separate OFX plugin to reach into the DCTL's `DEFINE_UI_PARAMS` variables.

### Smallest bridge proof, if approved later

The smallest meaningful bridge proof would not touch Palette or the Wave:

1. Build one minimal custom OFX plugin with one visible numeric parameter.
2. Add it to a Color-page node in Resolve 21.0.0.
3. Run a tiny external helper that sends a numeric value over a local IPC channel.
4. Have the plugin receive that value and update/render using its own parameter.
5. Verify both the rendered image and the visible Color-page control respond.

That would prove a **cooperative custom OFX bridge**, not arbitrary DCTL control. A second proof would be required before claiming that the plugin can safely update its visible host parameter UI from a background IPC thread.

## 6. Current Resolve Version

The installed application reports:

- version: `21.0.0`;
- build: `21.0.00048`;
- bundle identifier: `com.blackmagic-design.DaVinciResolve`.

The installed scripting changelog was last updated May 5, 2026. Its Resolve 21.0 additions concern transcription, audio classification, motion blur, slate analysis, background tasks, and speech generation. No new Color-page DCTL or arbitrary OFX parameter API is listed.

The installed scripting README was last updated May 8, 2026. Its `Graph` section still lists node-level methods and `GetToolsInNode()` as a string list, with no arbitrary effect-parameter API.

This is the current installed-version evidence. It is stronger than relying on an older online example, but it is still not a visual end-to-end DCTL test.

## 7. Required Classification

| Mechanism | Classification | Why |
|---|---|---|
| Dedicated Color-page native methods exposed by Resolve scripting | **DIRECTLY SUPPORTED** | Resolve provides explicit methods for selected node/grade operations such as LUT, CDL, enablement, cache mode, and labels. |
| Arbitrary existing Color-page OFX parameter via official Resolve scripting | **NOT POSSIBLE** | No effect handle or parameter getter/setter is exposed by the installed `Graph` API. |
| Arbitrary existing Color-page DCTL `DEFINE_UI_PARAMS` via official Resolve scripting | **NOT POSSIBLE** | DCTL UI declarations are documented, but no external Color-page parameter API exists. |
| Cooperative custom OFX plugin with external IPC | **POSSIBLE BUT REQUIRES A BRIDGE/PLUGIN** | A plugin can own its parameters and be deliberately coded to communicate with a companion app. |
| Background IPC-driven host-UI mutation from inside an OFX plugin | **UNDOCUMENTED/EXPERIMENTAL** | The OpenFX plugin can be made to receive external data, but thread safety, host parameter mutation, undo behavior, and visible UI refresh need a dedicated test. |
| Fusion tool-input scripting used as a substitute | **NOT ACCEPTABLE FOR THIS PRODUCT TARGET** | It targets a different Resolve page and does not prove Color-page DCTL control. |

## 8. Single Simplest Path

The simplest path that can plausibly achieve the desired user experience is **not**:

`Wave knob → Palette → arbitrary existing Color-page DCTL parameter`

That path has no supported parameter endpoint.

The simplest technically viable path is:

`Wave knob → Palette → small cooperative Color-page OFX bridge plugin → bridge-owned parameter/effect`

In practical terms, the product would need to standardize on a custom OFX effect that Palette knows how to control. If the desired visual operation currently lives in a DCTL, the likely route is to port or wrap the required operation into the cooperative OFX plugin, rather than trying to reach into an arbitrary DCTL's hidden UI parameters.

That is a product change and should not be implemented until the isolated OFX bridge proof succeeds.

## 9. Recommendation

**Do not modify Palette yet.**

The next action, if approval is given, should be one tiny standalone OFX bridge experiment outside the Palette repository's production code. Its success criteria must be explicit:

- a visible Color-page control belongs to the custom plugin;
- an external process changes a value;
- the Color page visibly reflects the new value;
- the image output changes;
- no Fusion page is involved;
- no Wave hardware is involved.

If that experiment fails to update the visible host control reliably, the safer conclusion is that external control should target a documented Resolve-native mechanism or a different cooperative integration design—not arbitrary Color-page DCTL parameters.

## Bottom Line

For the exact requested proof — an external macOS app changing an arbitrary `DEFINE_UI_PARAMS` DCTL control on an existing Color-page node — the installed Resolve 21.0.0 API provides no supported path, and no end-to-end proof should be claimed yet.

A custom OFX bridge is the smallest plausible alternative, but it controls a cooperative plugin's own parameter rather than arbitrary DCTL/OFX effects. Palette's verified hardware and WaveExplorerCore should remain frozen until that separate proof is approved and succeeds.

08.09.26 @ 2:59
# External Control of Existing Color-Page DCTL/OFX Parameters — Workaround Methods

**Premise confirmed from prior investigation:** the official Resolve scripting API cannot get/set arbitrary DCTL or OFX parameters on the Color page (Graph API tops out at `SetLUT`/`SetCDL`/`SetNodeEnabled`/`GetToolsInNode`). This report evaluates three ways to work *around* that limit by treating Resolve as a controllable application rather than a scriptable one, targeting Resolve Studio 21.0.00048 on macOS, with Dehancer Pro considered as the representative third-party OFX case.

For every load-bearing claim below, I've tagged it **[DEMONSTRATED]** (someone has actually built/shown this against a real app — Resolve specifically where noted) or **[THEORETICAL]** (technically plausible, extrapolated from adjacent evidence, not verified against Resolve).

---

## Legal framing (applies to all three methods)

Blackmagic's EULA prohibits reverse engineering: <cite index="133-1">you may not modify, translate, reverse engineer, decompile, disassemble, or create derivative works based on the Software, copy the Software, or remove proprietary notices</cite>. **[DEMONSTRATED — verified from the actual EULA text]**

None of the three methods below decompile, disassemble, or patch the Resolve binary — they all operate through ordinary OS-level surfaces (the accessibility tree, synthetic input events, the screen framebuffer) that any human user, screen reader, or the many existing commercial control-surface products already use. That is a materially different legal posture than reverse engineering. It is not risk-free — EULAs can still theoretically be read broadly, and this is not legal advice — but the common commercial precedent (Loupedeck, Stream Deck, BetterTouchTool, Keyboard Maestro, and Blackmagic's own tolerance of the Loupedeck Resolve packs sold on their and Logi's marketplaces) indicates this category of automation is treated as legitimate, distinct from cracking or memory-patching. Memory hacking/binary patching is excluded from this report per your instruction and because nothing found justifies it.

---

## Method Ranking

### #1 (Best overall) — Synthetic Mouse/Keyboard Automation (CGEvent / Quartz Event Services), driven by a coordinate/value map

**How it works:** Palette posts synthetic `CGEvent` mouse-down/drag/mouse-up (and optionally keyboard) events at specific screen coordinates corresponding to a known DCTL/OFX control, simulating a user physically dragging the slider. Values are written by mapping a Wave encoder delta to a proportional pixel-drag distance (or a precise click into a numeric entry field where the control type supports typed values, per DCTL's `DCTLUI_VALUE_BOX`).

**Evidence it works against Resolve specifically:**
- **[DEMONSTRATED]** SideshowFX sells a shipping, commercial "DaVinci Resolve Color Panel" profile for Loupedeck (Mac and Windows versions, both listed on Logi's Marketplace) that <cite index="110-1">gives access to and can control most parameters in the Color Room workspace of DaVinci Resolve — Primary Color, Primary Log, HDR, Qualifiers, Power Windows, Tracking, Color Warper, Color Slice, Mattes/Keys, Sizing, Dolby Vision, Magic Mask, and Printer Lights</cite>. This is a real, currently-sold product built entirely outside Blackmagic's scripting API — it has to be doing UI automation (click/drag or keystroke injection) under the hood, since none of those Color-page tools are exposed by the scripting API either.
- **[DEMONSTRATED, partial]** A public Hammerspoon discussion documents someone doing exactly the low-level version of this against Resolve's own primary color wheels: <cite index="106-1">using hs.eventtap.leftClick to activate a wheel and hs.mouse.absolutePosition to position the cursor on it, driven by a Loupedeck Live's knobs</cite>, with the author reporting the click-to-activate part works but the continuous knob-to-drag mapping was still being worked out — i.e., proven feasible, proven non-trivial to get smooth/reliable.
- **[DEMONSTRATED]** A parallel effort exists in the Bome MIDI Translator Pro community, again building "click and drag" mappings against Resolve's Color page from MIDI hardware — a second independent confirmation that this class of automation is viable and actively used in production by colorists.

**DCTL:** Should work the same as any other Inspector slider — DCTL controls render as ordinary numeric sliders/value boxes/checkboxes/combo-boxes in the same Inspector panel Loupedeck already drives. **[THEORETICAL for DCTL specifically — no project found automating a *DCTL* control by name, but architecturally indistinguishable from the ResolveFX/native controls that are proven]**

**Dehancer:** Uncertain. Third-party OFX plugins are free to draw their own custom parameter UI inside the Inspector panel (many high-end film-emulation and grain plugins render knobs/dials via their own custom paint routines rather than native slider widgets, for a distinctive brand look). If Dehancer's dials are custom-painted, click/drag coordinates still work (you're just clicking pixels), but the drag *feel* (linear vs. radial vs. logarithmic response) has to be reverse-derived by testing, not assumed. **[THEORETICAL — no evidence found either way for Dehancer's specific control rendering; must be verified empirically against the installed copy]**

**Reading current value back:** Not natively possible with this method alone — mouse/keyboard automation is write-only. You'd need to either (a) maintain your own shadow state (since Palette is the only thing changing the value, it can just remember what it last set — viable as long as nothing else touches that parameter), or (b) pair this with OCR of the printed numeric readout (Method 3) for authoritative read-back or to detect out-of-band changes (undo, a colorist manually nudging the same control).

**Reliability / complexity / latency:** Reliability is good *once calibrated* for a fixed layout, but calibration is manual and per-effect (SideshowFX's own listing is version-pinned: "Compatible with DaVinci Resolve 20 and later," implying they maintain/verify coordinate maps against specific UI revisions). Complexity is low-to-moderate (CGEvent APIs are simple; the hard part is the calibration UX, not the automation code). Latency is low — a synthetic event round-trips in low single-digit milliseconds.

**Resistance to UI/version changes:** Weak by default — absolute screen coordinates break if Blackmagic reflows the Inspector, if the user resizes/moves the Resolve window, or if display scaling changes. This is manageable (not fatal) with a "Learn Mode" calibration step per control (see Recommended Architecture) rather than hardcoded coordinates.

**Accessibility permission:** Yes — posting synthetic CGEvents into another application, and reading window geometry to compute coordinates, requires the calling app to be granted **Accessibility** permission in System Settings → Privacy & Security. This is a standard, user-visible one-time grant (same permission Loupedeck, Stream Deck, and BetterTouchTool all require) — not a red flag, but must be designed into onboarding.

**Shippability:** Yes — this is proven at commercial scale already (Loupedeck packs). It's the same category of product you're trying to build.

---

### #2 — macOS Accessibility API (AXUIElement)

**How it works:** Palette queries Resolve's accessibility tree (the same tree VoiceOver and screen readers use) to enumerate windows → panels → controls, ideally identifying a DCTL/OFX slider by its label, reading `kAXValueAttribute`, and setting it directly via `AXUIElementSetAttributeValue` or a synthetic `kAXPressAction`/`AXIncrement`/`AXDecrement` action — no coordinates, no pixel-dragging.

**Why this would be the ideal answer if it worked:** unlike Method 1, it can dynamically discover controls by name (no manual coordinate mapping), read the current value, and set it directly and precisely without simulating a drag gesture. This is the only method of the three with a real shot at satisfying "arbitrary DCTL" generically.

**Evidence against relying on it for Resolve's Color-page/Inspector controls specifically:**
- **[DEMONSTRATED, negative signal]** Columbia University's OASID accessibility testing team, after <cite index="86-1">"extensive automated and manual tests," did not recommend DaVinci Resolve for students, citing "numerous prominent accessibility issues... with no possible workarounds discovered or established," and noted Blackmagic has published no VPAT and no public accessibility documentation</cite>. This is a real third-party audit of the actual application, not speculation — and it's a strong negative signal for exactly the population of custom-drawn controls (sliders, wheels, curve editors) that DCTL/OFX parameters live among.
- **[THEORETICAL, but well-grounded]** Resolve on macOS is a Qt application (confirmed by Blackmagic's own forum and by the Cocoa/xcb platform-plugin references in their Linux/macOS build logs). Qt bridges to `NSAccessibility` through `QAccessible`, and that bridge is known to be incomplete for custom-painted widgets — a Qt Forum thread from a VoiceOver user documents that even basic attributes like `QAccessible::Help` <cite index="98-1">don't surface correctly through the Cocoa accessibility bridge, requiring users to patch Qt's own `qcocoaaccessibility.mm` to fix it</cite>. Standard Qt widgets (buttons, menus, plain text fields, list views) generally do get *some* AX exposure "for free"; **custom-painted widgets — which is exactly what color wheels, curve editors, and stylized OFX/DCTL parameter panels usually are — get none unless the app vendor explicitly implements a `QAccessibleInterface` subclass for that widget class**, and nothing found suggests Blackmagic has done this for the Color page.
- **[THEORETICAL, corroborating]** A recent practitioner write-up on macOS automation failure modes independently names this exact category as a known dead end: <cite index="96-1">`kAXErrorCannotComplete` is a documented, common failure returned specifically by Qt/Python/OpenGL-rendered applications that expose no real AX tree</cite> — Resolve's Color page (GPU-composited node graph, curves, scopes, custom sliders) fits this profile closely.
- **[No direct evidence found]** No GitHub project, forum post, or blog was found describing anyone successfully walking Resolve's Color-page AX tree down to an individual DCTL/OFX slider. This absence, combined with the negative signals above, is meaningful — Resolve automation is a popular enough niche (CommandPost, several MCP servers, Loupedeck packs, Hammerspoon threads) that a working AX approach would likely have surfaced if it were easy.
- Notably, CommandPost's creator — who explicitly said in a direct request to Blackmagic that <cite index="89-1">CommandPost already "uses the Accessibility API built directly into macOS to control Final Cut [Pro]"</cite> (a native AppKit app) — asked Blackmagic for a better integration path for Resolve rather than just pointing the same AX technique at Resolve, which is a soft signal from someone with hands-on AX experience that the direct port wasn't the obvious answer for Resolve.

**Practical verdict:** worth a cheap 30-minute empirical test (open Apple's free **Accessibility Inspector**, point it at Resolve's Color page with a DCTL/OFX effect applied, and see what — if anything — is exposed) before writing any code, but the balance of evidence says: menu bar, dialogs, and possibly some standard-widget panels may be AX-visible, while the Inspector's custom sliders/wheels/DCTL controls are likely invisible or unreliable. **Do not architect the product assuming this works — treat a positive result as a bonus, not the plan.**

**Dehancer:** Same reasoning as DCTL — likely worse, since third-party OFX vendors have even less incentive than Blackmagic to implement custom accessibility interfaces for their branded custom-drawn controls.

**Reading values:** if AX exposure exists at all for a given control, this is the *only* one of the three methods that can read the live value directly and cheaply — a meaningful advantage if it works even partially.

**Accessibility permission:** Yes, required (`AXIsProcessTrusted`).

**Shippability:** Fine from a permissions/legal standpoint; the open question is purely technical (does the tree exist for the controls you need).

---

### #3 — Computer Vision / OCR Visual Targeting

**How it works:** Screenshot the Resolve window → OCR to find a text label ("Exposure," "Print," a DCTL parameter name) → locate the associated slider/value box by proximity or template matching → hand off coordinates to Method 1 for the actual click/drag, and/or OCR the numeric readout for read-back.

**Evidence:** **[THEORETICAL, no Resolve-specific evidence found]**. This is a well-established general technique — commercial RPA tools like Ui.Vision ship exactly this pattern (screenshot → OCR/template match → synthetic click) for arbitrary desktop and even Citrix-streamed applications, and current LLM-era "vision desktop agents" (screenshot → VLM/OCR → click) are an active, working category in 2025–2026. But no one has been found applying this specifically to Resolve's Color page, DCTL, or Dehancer. It should work in principle — Resolve's Inspector text is real rendered text, not obfuscated — but nothing here is proven against this exact target.

**Why it ranks third despite being the only way to generalize to truly arbitrary controls:**
- Highest implementation complexity of the three (screenshot capture pipeline, OCR engine/model, label-to-control association heuristics, coordinate hand-off to Method 1).
- Highest latency — a screenshot + OCR + reasoning round-trip is tens to hundreds of milliseconds at best, versus single-digit milliseconds for a direct CGEvent. That's a bad fit for "one physical Wave control" driving smooth, continuous parameter changes in real time; it's a much better fit for a one-time "find and register this control" calibration step than for the live control loop.
- Most fragile to theme, zoom level, window size, and localization changes (OCR text-matching breaks on any font/scale/language change).
- Requires **Screen Recording** permission (macOS 10.15+) in addition to Accessibility — a second, more alarming-looking permission prompt for end users, and one Apple treats more strictly (periodic re-consent, more prominent OS warnings).

**Practical role:** best used as a **calibration-time helper**, not a runtime control-loop component — e.g., "point the camera/OCR at the Inspector once, let it suggest which pixel region corresponds to the label the user typed in, then hand off to Method 1 for all subsequent real-time drags." Using it live, per Wave-tick, is achievable but is the least reliable and slowest option of the three and should be a stretch goal, not the v1 plan.

---

## Dehancer — specific findings

Dehancer Pro is a straightforward third-party OFX plugin: installed as a `.ofx.bundle`, <cite index="123-1">applied by dragging it onto a Color-page node from the Film Emulation section of the Effects Library, just like any other OFX/ResolveFX effect</cite>. No evidence was found of any Dehancer-published SDK, automation hook, or external API — its documentation is entirely end-user installation/workflow guides. This means Dehancer offers **no vendor-sanctioned shortcut**; it is subject to exactly the same three workaround methods, with exactly the same open question about whether its parameter controls are custom-painted (likely, given its branded, film-emulation-console aesthetic) versus native Qt widgets. This should be the very first thing verified empirically (Accessibility Inspector + a screenshot test) before committing to an architecture for Dehancer specifically, since custom-painted third-party OFX UI is the worst case for Method 2.

---

## Recommended architecture

```
Tangent Wave (hardware)
   │  USB
   ▼
Tangent Hub (Tangent's own background service — TIPC/TCP :64246, documented SDK)
   │
   ▼
WaveExplorerCore (Swift) — decodes encoder/wave deltas
   │
   ▼
Palette (Swift app)
   │
   ▼
External Resolve-control layer  ← the part this report is about
   │
   ├─ Primary path (v1, real-time): CGEvent synthesis (Method 1),
   │    driven by a per-control coordinate + value-range map that the
   │    USER creates once via a "Learn Mode" (see below) — not hardcoded
   │    by you in advance, so it works for genuinely arbitrary DCTLs/OFX,
   │    it just costs the user 5 seconds of setup per control.
   │
   ├─ Opportunistic bonus (v1, cheap to try): attempt AXUIElement
   │    read/write first; fall back to CGEvent automatically if the
   │    control isn't AX-addressable. Costs little to attempt, upgrades
   │    silently to exact read/write when it happens to work.
   │
   └─ Stretch goal (v2): OCR-assisted calibration to suggest a control's
        screen region automatically during Learn Mode, and/or OCR
        read-back to detect out-of-band changes — kept out of the
        real-time control loop.
   │
   ▼
DaVinci Resolve Color Page → existing DCTL / existing OFX / Dehancer
```

**"Learn Mode" is the key design idea that resolves the tension between "arbitrary DCTL/OFX support" and "Method 1 needs coordinates":** rather than trying to automatically discover and semantically label every control (fragile, unproven — Method 3's whole problem), have the user briefly interact with the real Resolve UI once per control while Palette watches: e.g., the user Cmd-clicks (or a Palette-side hotkey-armed click) on a slider, then drags it once through a known range while Palette's own CGEvent tap observes the mouse path and reads whatever the numeric readout shows (via a one-shot OCR crop, or AX if available) to learn the pixel-to-value mapping and control bounds. After that one-time calibration, live Wave input drives the same control purely through Method 1 with no further vision/AX dependency. This is exactly the pattern shipping products like Loupedeck's editors use internally (they ship pre-calibrated maps because Blackmagic's UI is fixed for native tools; you need the equivalent but user-driven, since DCTL/OFX layouts are open-ended).

---

## Summary against your 14 criteria

| Criterion | #1 CGEvent automation | #2 AXUIElement | #3 CV/OCR |
|---|---|---|---|
| 1. Technical feasibility | High — proven | Uncertain — likely low for custom controls | Medium — proven generically, unproven on Resolve |
| 2. Reliability | Good once calibrated | Unknown/likely poor for target controls | Fragile (font/theme/scale sensitive) |
| 3. Implementation complexity | Low–moderate | Low if it works, wasted if it doesn't | Highest |
| 4. Performance/latency | Very low (ms) | Very low (ms) if available | High (tens–hundreds of ms) |
| 5. Dynamic control identification | No (needs Learn Mode) | Yes, if AX tree exists | Yes, in principle |
| 6. Read current value | No (needs shadow-state or OCR) | Yes, if AX tree exists | Yes (OCR of readout) |
| 7. Set value | Yes | Yes, if AX tree exists | Indirect (hands off to #1) |
| 8. Works with arbitrary DCTL | Yes, after Learn Mode | Unverified, possibly no | Yes, in principle |
| 9. Works with third-party OFX (Dehancer) | Yes, after Learn Mode (drag behavior TBD) | Unverified, possibly no | Yes, in principle |
| 10. Resistant to Resolve UI layout changes | Weak (coordinates); mitigated by re-running Learn Mode | N/A if it doesn't work at all; otherwise good | Weak (visual matching) |
| 11. Resistant to Resolve version changes | Weak, same mitigation | Unknown | Weak |
| 12. Requires Accessibility permission | Yes | Yes | Yes (+ Screen Recording) |
| 13. Reverse-engineering / licensing risk | No — standard OS input synthesis, same as shipping commercial products | No — standard OS accessibility API | No — screen pixels are not the software's protected internals |
| 14. Realistic as a shippable commercial app | Yes — directly precedented (SideshowFX/Loupedeck) | Only as an opportunistic enhancement, not the core mechanism | Only as a calibration aid, not the core mechanism |

**Bottom line:** Method 1 (synthetic input, coordinate/value-mapped, with a one-time per-control "Learn Mode" instead of hardcoded coordinates) is the method to build. Attempt Method 2 opportunistically and cheaply — a 30-minute Accessibility Inspector session against your actual Resolve 21.0.00048 + a DCTL + Dehancer will settle the open question quickly and for free. Keep Method 3 out of the real-time path and revisit it only if Learn Mode proves too tedious for users at scale. 
