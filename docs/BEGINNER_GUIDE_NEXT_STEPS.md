# Palette / Wave Explorer: Beginner Walkthrough

This guide assumes you are new to coding. You do not need to understand Swift yet. Follow one step at a time, and stop whenever the screen does not match the instruction.

## What we are doing first

We are **not building the full Palette app yet**.

First, we are making a small test app called **Wave Explorer** talk to your connected Tangent Wave through **Tangent Hub**. Think of it like this:

- **Tangent Wave:** the physical control surface.
- **Tangent Hub:** the translator running in the background on your Mac.
- **Wave Explorer:** our small test app.
- **Palette:** the larger app we will build after the connection works.

The goal for this session is simple: **get Wave Explorer connected and prove that one button, knob, or wheel can be detected**.

## Important safety rules

- Do not delete files.
- Do not rewrite the project architecture.
- Do not start Resolve, DCTL, OFX, Capture One, or the Palette interface yet.
- Do not guess packet numbers or protocol bytes.
- If a file name in these instructions does not exist on your screen, stop and ask Claude to identify the correct file.

## Part 1: Make sure the Wave and Hub are ready

### Step 1 — Leave the Wave plugged in

Keep the Tangent Wave connected to your Mac with its USB cable. Do not unplug it during testing.

### Step 2 — Find Tangent Hub

Look at the menu bar at the very top of your Mac screen. Tangent Hub normally runs as a small background/menu-bar application.

Important: **Tangent HUD Agent is not expected to open a normal window.** It is a background helper. Double-clicking it may appear to do nothing, and the Dock may not show a running dot. That behavior is normal.

If you do not see the Tangent Hub menu-bar icon:

1. Open **Finder**.
2. Click **Applications** in the left sidebar.
3. Open the **Tangent** folder.
4. Look for **Tangent Hub Agent**.
5. Double-click it once. Do not wait for a pop-up; it should run in the background.

If Tangent Hub is not installed, use the Tangent download link Claude already showed you: Tangent's website → Support/Downloads → Tangent Hub. Download the macOS version, install it, and launch it.

### Step 3 — Confirm Hub sees the Wave

Click the Tangent Hub icon in the menu bar and look for a message showing that the Wave is connected or detected. If no menu appears, that does not automatically mean Hub failed—the background process can still be running.

Do not continue if Hub says the device is missing. Check the USB cable and reopen Tangent Hub first.

## Part 2: Confirm Xcode is healthy

Your screenshot already shows **Build Succeeded**, which is good.

### Step 4 — Use the open Wave Explorer window

In Xcode, keep the project that looks like **WaveExplorer_V2** open. You should see folders similar to:

- `Sources`
- `WaveExplorerApp`
- `WaveExplorerCore`
- `Tests`

The important folder is `WaveExplorerCore`. This is the reusable part that Palette will eventually use.

### Step 5 — Run the existing tests before changing anything

1. In the Xcode menu at the very top, click **Product**.
2. Click **Test**.
3. Wait for Xcode to finish.

Expected result: a green check mark or a message saying the tests passed.

If you see red errors, take a screenshot and stop. Do not try random fixes.

## Part 3: Give Claude the right information

Claude needs the Tangent examples because the protocol must come from Tangent's own SDK, not guesses.

### Step 6 — Attach the reference files to Claude

In the Claude chat:

1. Click the **plus** button beside the message box.
2. Choose the option for adding files.
3. Attach the entire **SampleCode** folder from the extracted Tangent Developer Support Pack.
4. Also attach **ReadMe.txt**.
5. Do not attach the installers, TangentHub-Debug, or the large PDF manuals for this first coding task.

### Step 7 — Paste this message into Claude

Copy and paste this exact message:

> I am new to coding, so please make only the smallest safe change and explain every step. Read the attached Tangent SampleCode folder and ReadMe.txt first. Also read the repository handoff documents: MASTER_PLAN.md, KNOWN_FACTS.md, NEXT_STEPS.md, LATEST.md, and docs/sessions/2026-08-04.md.
>
> Work only on the Wave Explorer transport layer. Do not work on Resolve, DCTL, OFX, Capture One, UI redesign, or Palette product features.
>
> First inspect the existing Xcode project and tell me the exact file that owns packet encoding and parsing. The visible plan mentions a header plus a length-prefixed packet type, but do not assume the file is called TIPCPacket.swift; it may be TIPCFraming.swift or TIPCWireFormat.swift in this version.
>
> Then implement only the smallest encode/parse change needed for the documented TIPC header and length-prefixed packet type. Use the Tangent SDK examples as the source of truth. Add or update focused tests for valid packets, incomplete packets, and invalid lengths. Do not create a second competing packet format. Before changing anything, explain which file you will edit and why.

Claude should tell you the file name before making the change. That is normal and helpful.

## Part 4: Review Claude's proposed change

### Step 8 — Check Claude's answer before accepting it

Look for three things:

1. It names one existing transport file.
2. It explains where the packet format came from in the Tangent sample code.
3. It says which tests it will add or update.

If Claude starts talking about Resolve, DCTLs, OFX, Capture One, or redesigning the app, reply:

> Please stop and stay inside the Wave Explorer transport layer only. Do not change the architecture or add product features.

### Step 9 — Let Claude make the small code change

If the proposal stays inside the boundaries above, let Claude implement it in the Xcode project. Do not copy code manually unless Claude specifically tells you to.

## Part 5: Test the change in Xcode

### Step 10 — Build the project

In Xcode:

1. Press **Command-B**.
2. Wait for the result.

Expected result: **Build Succeeded**.

### Step 11 — Run the tests

1. Press **Command-U**.
2. Wait for the tests to finish.

Expected result: green tests.

If the build or tests fail:

1. Do not change anything else.
2. Copy the first red error message.
3. Send that error to Claude.
4. Ask Claude to explain the error in beginner language before fixing it.

## Part 6: Run Wave Explorer against the real hardware

Only do this after the build and tests are green.

### Step 12 — Run the app

1. Make sure Tangent Hub is still running.
2. Make sure the Wave is still connected.
3. In Xcode, press **Command-R**.
4. Wait for Wave Explorer to open.

If the app asks for permission, read the message carefully and allow only the permission needed for the app to communicate with the device.

### Step 13 — Look for a connection result

The app may show a status such as connected, disconnected, waiting, or an error. Write down the exact wording.

Then move one physical control on the Wave—one knob, button, or wheel—and see whether an event appears in the app's log or debug view.

Do not test every control yet. One successful event is enough for the first proof.

## What success looks like

You are successful when all four statements are true:

- Tangent Hub sees the Wave.
- Xcode builds Wave Explorer successfully.
- The Wave Explorer tests pass.
- Moving one Wave control produces a decoded event or a clear logged message.

At that point, save a screenshot and tell Claude exactly what happened. Then we can move to control enumeration and event logging.

## What to send back if something goes wrong

Send these four items:

1. The exact screen or error message.
2. Whether Tangent Hub says the Wave is connected.
3. Whether Xcode says Build Succeeded or failed.
4. The name of the file Claude was editing.

That information is enough to choose the next step. You do not need to diagnose the problem yourself.

## Tiny glossary

- **Build:** Xcode checks and prepares the app.
- **Test:** Xcode runs small checks that verify the code behaves correctly.
- **TIPC:** Tangent's communication language between an app and Tangent Hub.
- **Packet:** One small formatted message sent through that connection.
- **Framing:** The rule that tells the app where a packet starts and ends.
- **Handshake:** The first hello message used to establish a connection.
- **Transport layer:** The narrow code that sends and receives messages; this is the only part we are working on now.
