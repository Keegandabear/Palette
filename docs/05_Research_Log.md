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
