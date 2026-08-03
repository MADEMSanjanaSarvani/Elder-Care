# Getting CareHive onto the Play Store

*Everything left between build 17 and a live listing, in the order to do it.*

Steps 1–4 are yours (they need accounts, money, or secrets only you should
hold). Steps 5–7 are already built and just need running.

---

## Before anything: is it worth submitting yet?

Honest answer — **put the APK in five real families' hands first.** A store
listing for an app nobody has used yet gets you nothing; a week of watching
five families use it will change what you build next.
`docs/business/SETU-first-five-families.md` covers finding them. (The rest of
`docs/business/` was written for the caregiver marketplace and is history now —
see the README in that folder.)

For CareHive the test is specific and easy to run: give it to somebody who
takes three or more long-term medicines, and after a week ask them what the
last seven days looked like. If they can answer from the app instead of from
memory, it works. If they stopped marking doses after day two, find out why —
that is the only failure mode that matters.

Everything below will still be here when you're ready. If you'd rather
submit now, carry on.

---

## 1. Create your signing key ⚠️ do this once, never lose it

This key **is** your app's identity on Google Play. Lose it and you can
never update CareHive again — you'd have to publish a new listing and abandon
every install. Back it up in two places.

On your Windows machine:

```
keytool -genkey -v -keystore %USERPROFILE%\setu-upload-key.jks ^
  -keyalg RSA -keysize 2048 -validity 10000 -alias setu
```

It asks for a password and some details (name, city, country — your own are
fine). Then:

- **Back up `setu-upload-key.jks`** to Google Drive *and* a USB stick.
- **Write the passwords down** somewhere that isn't your laptop.
- **Never commit it.** `.gitignore` already blocks `*.jks` and
  `key.properties`.

Then put it into GitHub so CI can sign release builds:

```
certutil -encode %USERPROFILE%\setu-upload-key.jks keystore.b64
```

Open `keystore.b64`, copy everything **between** the BEGIN/END lines, and add
these four secrets at **GitHub → Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the text you just copied |
| `ANDROID_KEYSTORE_PASSWORD` | your keystore password |
| `ANDROID_KEY_ALIAS` | `setu` |
| `ANDROID_KEY_PASSWORD` | your key password |

The build workflow picks these up automatically and prints the SHA-1 you'll
need for Google Sign-In. Full detail: `docs/BUILD-ANDROID.md`.

---

## 2. Publish the privacy policy 🔗 required, or the listing is rejected

The pages are built and ready in `docs/public-site/` — privacy, terms,
support, and a small landing page, all styled and mobile-friendly.

⚠️ **Do not point GitHub Pages at the whole `docs/` folder.** It also holds
your business plans, feasibility model and credentials checklist, and Pages
would publish every one of them.

Publish **only** `docs/public-site/`, on its own branch:

```
git subtree push --prefix docs/public-site origin gh-pages
```

Then **GitHub → Settings → Pages → Source: `gh-pages` branch, `/` root**.

A minute later your URLs are live:

- Privacy: `https://mademsanjanasarvani.github.io/Elder-Care/privacy.html`
- Terms: `https://mademsanjanasarvani.github.io/Elder-Care/terms.html`
- Support: `https://mademsanjanasarvani.github.io/Elder-Care/support.html`

Re-run `python3 tools/build_public_site.py .` and push again whenever the
legal text changes.

**A lawyer should read the privacy policy before you publish.** CareHive
handles health data, which is sensitive personal data under the DPDP Act. The
draft reflects what the app genuinely does, but it isn't legal advice. (There
is no money involved — the app is free and takes no payments — but the health
data alone is reason enough.)

---

## 3. Switch Razorpay to live keys 💰

You're on `rzp_test_` — no real money moves. When you're ready:

1. Razorpay Dashboard → **Settings → API Keys → Generate Live Key**
2. Supabase → **Project Settings → Edge Functions → Secrets**, replace:
   - `RAZORPAY_KEY_ID` → your `rzp_live_…` key
   - `RAZORPAY_KEY_SECRET` → the matching secret
3. Razorpay → **Settings → Webhooks** → point at the same
   `payments-webhook` URL, and set `RAZORPAY_WEBHOOK_SECRET` in Supabase to
   match.
4. **Test with ₹1 to yourself** before telling anyone the app is live.

---

## 4. Google Play Console account

₹2,000 one-off (about $25), at <https://play.google.com/console>. Identity
verification takes a few days, so start it early — it's the step most likely
to stall you.

---

## 5. Build the release bundle

Play wants an `.aab`, not an `.apk`:

```
cd apps/family_elder_app
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

(If Flutter isn't installed locally, add an `appbundle` step to the build
workflow and download it from Actions instead.)

---

## 6. Screenshots

Capture 4–8 screens on your phone from the current build, put the PNGs in a
folder, then:

```
python3 tools/frame_screenshots.py ~/shots ~/play-shots
```

That produces 1242×2208 listing images with a headline over each capture.
Edit `CAPTIONS` at the top of the script to match your screens.

Capture these, in this order — they tell the story a worried daughter cares
about:

1. **Today** — a couple of doses due, Taken buttons visible. This is the app;
   lead with it.
2. **Last 30 days** — the adherence history, with the "no record" legend
   showing. It is what makes CareHive different from every other pill app.
3. **Medical ID** — the screen a paramedic reads.
4. Add a medicine (the dose-time grid)  5. Family dashboard  6. Timeline
7. SOS  8. Consent/privacy

---

## 7. Fill in the listing

Copy from `docs/store/STORE-LISTING.md` — title, short and full description
are written and use the "Know what you took" positioning.

Assets ready in `docs/store/`:

- App icon 512×512 — `icon-512-family-elder.png`
- Feature graphic 1024×500 — `feature-graphic-family.png`

Play will also ask you to declare:

- **Data safety form** — the filled-in answers are in
  `docs/store/STORE-LISTING.md`. In short: you collect health data, contact
  details, and location *only at the moment an SOS is raised*; no payment
  data at all; encrypted in transit; deletion can be requested in-app.
- **Health apps declaration** — CareHive is a personal health record and a
  medication reminder. It does not diagnose and offers no clinical decision
  support. Say so plainly.
- **USE_EXACT_ALARM** — expect a question. The app's core user-facing function
  is an alarm at a specific time, which is exactly the justification Google
  asks for.
- **Target audience** — adults, not children.

---

## Order to actually do it

1. **Play Console account** — start now, verification is slow
2. **Signing key** — 10 minutes, do it carefully, back it up twice
3. **Publish the policy pages** — one command
4. **Screenshots** from build 17
5. **Fill the listing**, upload the `.aab`, submit
6. **Live Razorpay keys** — only once you're ready to take real money

First review usually takes a few days. Rejections are normal and almost
always about the data-safety form or a missing privacy URL — both covered
above.
