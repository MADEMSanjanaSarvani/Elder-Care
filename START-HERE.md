# Start Here — Setu

Everything is built. This page is your map: what each document is for, in the
order you'll actually use them. You don't need to read all of it — follow the
path for where you are.

## The apps
- **Setu** (`apps/family_elder_app`) — families & elders.
- **Setu Care** (`apps/caregiver_app`) — caregivers.
- **Admin dashboard** (`apps/admin-dashboard`) — your ops team's web console.
- **Backend** (`supabase/`) — database, security rules, and server functions
  (already deployed to your live project).

---

## Your path, step by step

### 1. Get a test app into your friends' hands (free, no coding)
Follow **`docs/YOUR-STEP-BY-STEP-GUIDE.md` → Part A.**
It covers: copying your Supabase values, adding them to GitHub, setting up free
test logins, building the APK from the Actions tab, and sharing it.

### 2. Turn on the smart features (cheap)
**`docs/YOUR-STEP-BY-STEP-GUIDE.md` → Part B.**
An OpenAI key switches on the AI assistant; Razorpay **test** keys switch on
payments (with test cards, no real money).

### 3. Turn on the automatic background jobs (when you have real users)
**`docs/GO-LIVE-CHECKLIST.md`.**
Lists every scheduled job (reminders, daily medicine doses, weekly summaries),
the secret each needs, and a suggested schedule. Skippable for a short test.

### 4. Publish to the Google Play Store (when ready)
In order:
1. **`docs/legal/`** — fill in the placeholders in `PRIVACY-POLICY.md` and
   `TERMS-OF-SERVICE.md` (have a lawyer review them — it's a health app), then
   host the pages (see "Hosting your privacy policy" below).
2. **`docs/store/STORE-LISTING.md`** — ready-to-paste app names, descriptions,
   and the tricky **Data Safety** answers. Graphics are in `docs/store/`
   (app icons + feature graphics; you add phone screenshots).
3. **`docs/BUILD-ANDROID.md`** — create your signing key and build the `.aab`
   upload file. **Read the "never lose this key" warning.**

---

## Hosting your privacy policy (Play requires a public URL)

The easiest free option is **GitHub Pages**:
1. In your repo → **Settings** → **Pages**.
2. Under "Build and deployment", Source = **Deploy from a branch**; pick your
   branch and folder **/docs**; Save.
3. After a minute your files are live at
   `https://<your-username>.github.io/<repo>/legal/privacy-policy.html`
   (and `.../legal/terms-of-service.html`).
4. Put those URLs in the Play Console listing and in the apps if asked.

(The HTML versions — `docs/legal/privacy-policy.html` and
`terms-of-service.html` — are already generated from the markdown and styled to
read well on a phone.)

---

## Reference docs (you won't usually need these)
- `docs/prd/` — the 7 product-requirement documents the whole app was built from.
- `docs/roadmap*` / architecture notes — the original plan and module breakdown.
- `supabase/README.md`, `supabase/tests/README.md` — backend and test details.
- `docs/store/` — all Play Store graphics and listing copy.

---

## The one thing to remember
Everything left to do needs **your accounts** (Supabase, GitHub, OpenAI,
Razorpay, Google Play) — none of it needs more code. Start with Part A of
`docs/YOUR-STEP-BY-STEP-GUIDE.md` and you'll have a working app on a phone
within the hour.
