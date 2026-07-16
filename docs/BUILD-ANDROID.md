# Building for the Play Store — Signing Key & App Bundle

This is the **Part C** build path (from `docs/YOUR-STEP-BY-STEP-GUIDE.md`): how
to create your own signing key and produce the `.aab` file the Play Store
needs. You only need this when you're ready to **publish** — the CI-built test
APK (for sharing with friends) does **not** need any of this.

> **The signing key is the single most important secret you will own.** If you
> lose it, you can never update your app on the Play Store again — you'd have to
> publish a brand-new listing. Back it up in at least two safe places. It must
> live only on your machine; it is already git-ignored, so it will never be
> committed.

The repo is **already wired** for this: each app's `build.gradle.kts` signs the
release build with your key **if** `android/key.properties` exists, and falls
back to the debug key otherwise. So you only do the steps below once per app.

---

## 0. One-time setup on your computer

You need the tools installed locally (the cloud CI can't hold your private key):

1. **Flutter SDK** — https://docs.flutter.dev/get-started/install
2. **Android Studio** (installs the Android SDK) — https://developer.android.com/studio
3. **Java JDK 17** (Android Studio bundles one; `keytool` comes with it).

Confirm Flutter is happy: run `flutter doctor` — the "Android toolchain" line
should have a ✓.

---

## 1. Create your signing key (keystore)

Pick a folder **outside** the repo (e.g. your home folder) so it's never near
git. Run this once — it makes one key you'll use for **both** apps:

```bash
keytool -genkey -v -keystore ~/setu-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias setu
```

It will ask for:
- a **keystore password** and a **key password** (you can use the same one) —
  write these down and keep them safe;
- your name/organisation/location — fill in real values.

You now have `~/setu-upload-key.jks`. **Back it up** (password manager, encrypted
drive). Do not email it to yourself in plain form.

---

## 2. Point each app at the key

For **each** app (`apps/family_elder_app` and `apps/caregiver_app`), create a
file at `apps/<app>/android/key.properties` with these four lines (use your real
passwords and the real path to the `.jks`):

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=setu
storeFile=/absolute/path/to/setu-upload-key.jks
```

This file is **git-ignored** (`android/.gitignore` already lists
`key.properties`, `*.jks`, `*.keystore`) — it stays on your machine only.

That's the only wiring needed; the Gradle config already reads it.

---

## 3. Build the upload file (`.aab`)

The Play Store wants an **Android App Bundle** (`.aab`), not an APK. Build each
app with your Supabase values (same public URL + anon key from Part A):

```bash
# Family & Elder app
cd apps/family_elder_app
flutter build appbundle --release \
  --dart-define=SUPABASE_URL="https://veumfexjpxqhxemjaaor.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="YOUR_ANON_KEY"
# -> build/app/outputs/bundle/release/app-release.aab

# Caregiver app
cd ../caregiver_app
flutter build appbundle --release \
  --dart-define=SUPABASE_URL="https://veumfexjpxqhxemjaaor.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="YOUR_ANON_KEY"
# -> build/app/outputs/bundle/release/app-release.aab
```

If you'd rather hand someone a directly-installable file instead of uploading,
swap `appbundle` for `apk` to get `build/app/outputs/flutter-apk/app-release.apk`
— now signed with **your** key.

---

## 4. Bump the version for every new upload

The Play Store rejects an upload whose `versionCode` isn't higher than the last.
Before each new build, edit the app's `pubspec.yaml`:

```yaml
version: 0.1.1+2   # name is before +, versionCode is the number after +
```

Increase the number after `+` every single upload (2, 3, 4, …).

---

## 5. Upload to Google Play

1. Create a **Google Play Console** account (one-time US$25):
   https://play.google.com/console
2. **Create app** → fill the name (**Setu**), default language, app/game =
   App, free/paid.
3. Complete the required sections (Play walks you through them):
   - **Store listing** — short & full description, screenshots (phone), an app
     icon (512×512), a feature graphic (1024×500), category **Medical** or
     **Health & Fitness**.
   - **Privacy Policy URL** — host `docs/legal/PRIVACY-POLICY.md` (filled in) at
     a public link and paste it here. **Required.**
   - **Data safety** — declare what data you collect (account, health, location
     for emergencies) and how it's used; answer truthfully from the Privacy
     Policy.
   - **Content rating**, **Target audience** (adults), **Ads** (none).
4. **Production → Create new release** → **Play App Signing**: accept it (Google
   holds the final release key; your `.jks` becomes your *upload* key). Upload
   `app-release.aab`, add release notes, review, and **roll out**.

> **Tip:** start with a **Closed testing** track and add your friends'
> Google-account emails as testers — they install from the Play Store with no
> "unknown sources" warning, and you catch issues before public launch.

---

## Quick reference

| Task | Command |
|---|---|
| Make key (once) | `keytool -genkey -v -keystore ~/setu-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias setu` |
| Point app at key | create `apps/<app>/android/key.properties` (Section 2) |
| Build bundle | `flutter build appbundle --release --dart-define=...` |
| New version | bump `+N` in `pubspec.yaml` before each upload |

Keep the two apps as **separate** Play Console listings (Setu for families,
Setu Care for caregivers) — they have different application IDs already
(`com.projectsetu.family_elder_app`, `com.projectsetu.caregiver_app`).
