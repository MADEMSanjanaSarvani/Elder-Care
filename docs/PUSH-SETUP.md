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

## 2. `SUPABASE_SERVICE_ROLE_KEY` — so the sweep runs every 15 minutes

The reminder sweep is what notices a dose is due. Nothing was calling it.

1. Supabase dashboard → **Project Settings → API** → copy the
   **`service_role`** key (the secret one, *not* `anon`).
2. GitHub → your repo → **Settings → Secrets and variables → Actions** →
   **New repository secret**.
   - Name: `SUPABASE_SERVICE_ROLE_KEY`
   - Value: the key.

`SUPABASE_PROJECT_REF` is already set from the deploy workflow, so that's all.

**To check it worked:** GitHub → Actions → **Reminder sweep** → *Run workflow*.
It should finish green and print a JSON summary of what it dispatched.

---

## Why the service_role key and not the anon key

The sweep reads every pending reminder across every user and writes
notification rows for other people. That is precisely what RLS is there to
prevent, so it has to run as the service role.

Which is also why it lives in a GitHub secret and runs on GitHub's servers,
never in the app. **The service_role key must never appear in the Flutter
code, in `google-services.json`, or in anything shipped to a phone** — it
bypasses every row-level security policy in the database.

---

## What still is not built

**SMS fallback.** If a phone has no data connection, no notification arrives.
Real, named, not pretended otherwise.

**A "Taken" button in the notification shade.** Right now tapping the
notification opens the app. Tapping *Taken* without opening anything needs
`flutter_local_notifications` on the client, and is the next piece of work.
