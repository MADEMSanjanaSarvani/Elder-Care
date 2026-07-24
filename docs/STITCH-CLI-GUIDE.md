# How to convert your Stitch screens to Dart (Claude Code CLI + Stitch MCP)

*Step-by-step, Windows-friendly. Do it once; then it's easy.*

> ⚠️ FIRST: **rotate your Google/Stitch API key** (you pasted the old one in chat).
> Google Cloud Console → APIs & Services → Credentials → regenerate the key. Use the
> NEW key everywhere below.

---

## What you're setting up
You'll run **Claude Code on your own computer** (a terminal app), connect it to **Stitch**,
open this project, and ask it to turn each Stitch design into Flutter/Dart — then push the
result to the same branch so it flows back into everything we've built.

---

## Step 1 — Install the tools (once)
1. **Install Node.js** (needed for Claude Code): https://nodejs.org → download the LTS installer → next-next-finish.
2. Open **PowerShell** (press Start, type "PowerShell", Enter).
3. Install Claude Code:
   ```
   npm install -g @anthropic-ai/claude-code
   ```
4. Also make sure **Git** is installed: https://git-scm.com/download/win (next-next-finish).

## Step 2 — Get the project onto your computer
```
git clone https://github.com/MADEMSanjanaSarvani/Elder-Care.git
cd Elder-Care
git checkout claude/elder-care-platform-mx27jo
```
*(This is the same branch we've been working on, so your CLI work and my work stay in one place.)*

## Step 3 — Start Claude Code + log in
```
claude
```
Follow the prompt to log in with your Claude account (same one you use here). Type `/exit` to leave anytime.

## Step 4 — Add the Stitch connector (once)
Inside the project folder, run (use your **NEW** key):
```
claude mcp add stitch --transport http --header "X-Goog-Api-Key: YOUR_NEW_KEY" https://stitch.googleapis.com/mcp
```
Then start Claude again (`claude`) and check it connected:
```
/mcp
```
You should see **stitch** listed as connected. If not, re-check the key.

## Step 5 — Convert screens, ONE at a time (the easy way)
Don't say "convert all 26 screens" — that's how things break. Do **one screen per request**.
Paste a prompt like this (change the screen name each time):

> Using the Stitch MCP, take the **family_dashboard** design and convert it to a Flutter
> screen that matches it as closely as possible. Replace the existing
> `apps/family_elder_app/lib/features/family_home/presentation/family_home_screen.dart`
> **but keep all the existing data providers, navigation, and functionality** — only change
> the visual layout to match Stitch. Then run `flutter analyze` and make sure it passes.

After it finishes and analyze passes, tell it:
> Commit this and push to the branch.

Then move to the next screen (elder_home, timeline, wellness_summary, …).

## Step 6 — Keep it flowing back to me
Because you're pushing to the **same branch**, every screen you convert in the CLI shows up
here too. So the workflow is:
- **You (CLI + Stitch):** convert the *visuals* of each screen, one at a time.
- **Me (here):** everything else — backend, payments, integrations, audits, business, fixes.

---

## Tips that make it much easier
- **One screen at a time.** Convert → check it looks right → commit → next. Never batch.
- **Always keep functionality.** Tell Claude "keep the data/providers/navigation, change only the visuals" — otherwise buttons stop working.
- **Run `flutter analyze` after each screen** (Claude can do it) so you catch errors immediately.
- **Test on your phone** after every 2–3 screens, not at the very end.
- **Commit often** with clear messages ("family dashboard: Stitch conversion").
- If a conversion looks worse than what's there, **just don't commit it** — `git checkout .` throws it away.
- Start with the screens you care most about (dashboard, elder home, timeline).

## The screen → file map (so you know what to point it at)
| Stitch design | File to replace |
|---|---|
| family_dashboard | `features/family_home/presentation/family_home_screen.dart` |
| elder_home_screen | `features/elder_home/presentation/elder_home_screen.dart` |
| daily_timeline | `features/timeline/presentation/timeline_screen.dart` |
| wellness_summary | `features/wellness/presentation/wellness_summary_screen.dart` |
| add_medication | `features/medications/presentation/medications_screen.dart` |
| emergency_medical_profile | `features/health_profile/presentation/health_profile_screen.dart` |
| notification_center | `features/notifications/presentation/notification_inbox_screen.dart` |
| settings_dashboard | `features/settings/presentation/settings_screen.dart` |
| premium_plans | `features/care_plans/presentation/care_plans_screen.dart` |
| ai_companion | `features/assistant/presentation/assistant_screen.dart` |
| caregiver_dashboard | `features/job_queue/presentation/job_queue_screen.dart` |
| login / role_selection / onboarding | `features/auth/...`, `features/onboarding/...` |

*(All under `apps/family_elder_app/lib/`.)*

---

**That's it.** Install once, then it's: `claude` → point it at one screen → let Stitch convert
→ analyze → commit → push → repeat. Slow and steady beats one big risky batch.
