# The original Stitch designs

All 32 exported frames (28 unique screens — some designs have two frames),
kept here as the reference the app is built against.

**These are not bundled into the app.** They used to live in
`apps/family_elder_app/assets/stitch/` and were shown through a "Design
Preview" entry in Settings, which meant every user carried 6.5 MB of
mockups in their APK and could tap into a gallery of pictures of the app
they were already using. That gallery is gone; the designs stay here.

## Using them

Open any PNG to compare against the live screen. The mapping from design to
the Dart file that implements it is in `docs/STITCH-CONVERSION-QUEUE.md`.

If a screen doesn't match its design, that's a bug worth reporting — say
which screen and what's different, and it can be corrected against the file
listed in the queue.

## Where the designs actually live

The source of truth is the Stitch project itself ("Setu AI Elder Care
Ecosystem"). These PNGs are a snapshot. If a design changes in Stitch,
re-export it here so the reference doesn't drift.
