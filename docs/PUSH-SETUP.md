# Turning on push notifications

Two secrets. Ten minutes. Until both are set, CareHive writes reminder rows
that only appear while the app is open — which for a medicine reminder is the
same as no reminder at all.

Nothing here breaks if you skip it: every function fails soft and logs. But the
core promise of the app does not work until you do it.

---

## 1. `FIREBASE_SERVICE_ACCOUNT` — so the backend can send

This is what actually delivers the notification to a locked phone.

1. Open the [Firebase console](https://console.firebase.google.com/) and pick
   the CareHive project — the same one the app's `google-services.json` came
   from. If it is a different project, the tokens will not match and every send
   will fail with `UNREGISTERED`.
2. **Project settings → Service accounts → Generate new private key.**
   A `.json` file downloads. Treat it like a password: it can send
   notifications to every user of your app.
3. Supabase dashboard → **Project Settings → Edge Functions → Secrets** →
   **Add new secret**.
   - Name: `FIREBASE_SERVICE_ACCOUNT`
   - Value: the **entire contents** of that JSON file, pasted as-is —
     `{` through `}`, including the `private_key` with its `\n` sequences.
     Do not reformat it, do not strip the newlines.
4. Redeploy the functions (any push to the branch does this).

**To check it worked:** raise a test SOS from a second device, or use the
Practice button. Supabase → Edge Functions → `sos-trigger` → Logs. You want to
see nothing from `[fcm]`. A line reading `[fcm] FIREBASE_SERVICE_ACCOUNT not
set` means the secret did not save; `[fcm] token exchange failed` means the JSON
is for the wrong project or was mangled on paste.

---

## 2. Two sweep secrets — so the reminders actually run

Two Edge Functions do the work, and **nothing was calling either of them**:

- `medications-generate-doses` turns each medicine's schedule into dated doses
  and queues a reminder for each new one
- `reminders-dispatch-sweep` finds reminders that have come due and sends them

Neither uses a Supabase API key. Both are `verify_jwt = false` and check their
own header instead, so you invent these two values yourself.

**Pick two random strings.** Anything long and unguessable — mash the keyboard,
or run `openssl rand -hex 32`. They don't have to mean anything, and the two
should be different.

**Put each one in two places:**

| Secret name | Supabase (Edge Functions → Secrets) | GitHub (Settings → Secrets → Actions) |
|---|---|---|
| `MEDICATIONS_SWEEP_SHARED_SECRET` | ✅ | ✅ |
| `REMINDERS_SWEEP_SHARED_SECRET` | ✅ | ✅ |

The value must be **identical in both places** — Supabase checks the header
against its copy, GitHub sends its copy. A mismatch is a 401 and a red workflow
run, which is exactly the loud failure you want.

`SUPABASE_PROJECT_REF` is already set on the GitHub side from the deploy
workflow, so that's everything.

**To check it worked:** GitHub → Actions → **Medicine sweep** → *Run workflow*.
Green means both functions accepted the call. A 401 means one of the four
copies doesn't match.

---

## Why not the service_role key

An earlier draft of the workflow sent the `service_role` key. It was wrong on
both counts: these functions don't check it, and it would have handed a key
that bypasses **every RLS policy in the database** to CI for no reason.

The shared secrets are scoped to one function each and can be rotated by
changing two values. That's the whole reason they exist.

Either way, the rule that does not bend: **a service_role or `sb_secret_` key
must never appear in the Flutter code, in `google-services.json`, or in
anything shipped to a phone.**

---

## What the push path is now for

**Not the dose reminder.** That moved onto the phone. The GitHub Actions cron
above is best-effort and was observed drifting past ninety minutes between
runs, and FCM needs a data connection the phone may not have — so dose
reminders are exact alarms scheduled on the device itself
(`lib/core/local_reminders.dart`). They fire on the minute, in flight mode,
and carry the **Taken** button that records the dose without opening the app.

Push is still what tells *other people*: the SOS alert and its stand-down, and
family notifications. Those genuinely cannot happen on the elder's own phone,
which is why `FIREBASE_SERVICE_ACCOUNT` above still matters.

The sweep is kept because the server is still what generates dose rows from
each medicine's schedule — the phone schedules alarms *from* those rows.

## What still is not built

**SMS fallback.** If a phone has no data connection, family are not notified
of an SOS. The elder's own reminders are unaffected — they are local alarms.

**Reminders can only be armed two days ahead.** Android caps how many alarms
one app may hold, so CareHive schedules the next 48 doses and re-arms on every
open. A phone that is never opened for several days runs out of scheduled
alarms. (A reboot is fine — `RECEIVE_BOOT_COMPLETED` and
`ScheduledNotificationBootReceiver` are declared in the manifest, so the alarms
are restored on restart.)

**A refused permission is silent.** If notification permission or exact-alarm
permission is denied, `LocalReminders.init()` logs and carries on. The app
works; it just never rings, and nothing in the UI says so yet.
