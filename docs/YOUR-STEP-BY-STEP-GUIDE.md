# Your Step-by-Step Guide — From Code to Friends Testing to Play Store

Written for someone who has **not done this before**. Follow the parts in
order. Do **Part A** and your friends can install and use the app. Parts B
and C make it smarter and get it on the Play Store.

Your Supabase project is `Elder-Care`
(URL: `https://veumfexjpxqhxemjaaor.supabase.co`).

---

# PART A — Get a working app into your friends' hands

You must finish all 6 steps here. None of them need coding.

## Step 1 — Copy your two public Supabase values

The app needs to know *where* your backend is. These two values are **public**
(safe to put in an app — they are not passwords).

1. Open your Supabase dashboard → your **Elder-Care** project.
2. Click the **gear icon (Project Settings)** in the bottom-left.
3. Click **API** (or **API Keys / Data API**).
4. Copy and keep these two somewhere (a notepad):
   - **Project URL** → looks like `https://veumfexjpxqhxemjaaor.supabase.co`
   - **anon public** key → a long string starting with `eyJ...`

## Step 2 — Give those values to the APK builder (GitHub)

The app is built automatically on GitHub. It needs the two values from Step 1.

1. Open your repository on GitHub: `MADEMSanjanaSarvani/Elder-Care`.
2. Click **Settings** (top menu of the repo).
3. Left sidebar → **Secrets and variables** → **Actions**.
4. Click **New repository secret**, add the first one:
   - Name: `SUPABASE_URL`
   - Secret: paste the Project URL from Step 1. Click **Add secret**.
5. Click **New repository secret** again, add the second:
   - Name: `SUPABASE_ANON_KEY`
   - Secret: paste the anon public key. Click **Add secret**.

## Step 3 — Make login work (so friends can actually sign in) — FREE

The app signs in with a **phone number + a code (OTP)**. Normally that needs a
paid SMS service. For testing, Supabase lets you create **fake test numbers**
with fixed codes — no SMS, no cost. You give these to your friends.

1. Supabase dashboard → **Authentication** (left sidebar).
2. Go to **Providers** → click **Phone** → toggle it **ON** → **Save**.
   (If it insists on an SMS provider, that's fine — test numbers below still
   work without sending real SMS.)
3. Still in the Phone settings, find **Test phone numbers** (a small section
   for mapping a number to a fixed code). Add a few, for example:
   - `+919000000001` → code `123456`
   - `+919000000002` → code `123456`
   - `+919000000003` → code `123456`
4. Save. Now anyone can log in with, say, `+919000000001` and code `123456`
   — no real SIM needed.

> If you don't see a "Test phone numbers" option on your plan, set up **Twilio**
> (free trial) as the SMS provider instead — Authentication → Providers →
> Phone → choose Twilio and paste its credentials. Real SMS then works.

## Step 4 — Check your data is loaded (30 seconds)

The app needs a region and services to show, or booking screens look empty.

1. Supabase dashboard → **SQL Editor** → new query. Paste and **Run**:
   ```sql
   select
     (select count(*) from regions where code = 'vizag-ap-in') as regions,
     (select count(*) from service_catalog) as services,
     (select count(*) from care_plans) as care_plans;
   ```
2. You want **regions = 1**, and **services** and **care_plans** greater than 0.
3. If any is 0, open the file `supabase/seed.sql` in the repo, copy its whole
   contents into the SQL Editor, and **Run** it once.

## Step 5 — Build the APK

1. GitHub repo → **Actions** tab (top menu).
2. Left sidebar → click **Build APKs**.
3. Click the **Run workflow** button (right side) → pick the branch
   `claude/elder-care-platform-mx27jo` → **Run workflow**.
4. Wait ~10–15 minutes. When the run finishes (green tick), open it and scroll
   to **Artifacts** at the bottom. Download:
   - `setu-family-elder-apk` (the app for families & elders)
   - `setu-caregiver-apk` (the app for caregivers — optional for friends)
5. Unzip the download to get the `.apk` file.

## Step 6 — Test it yourself, then share

1. Copy `setu-family-elder.apk` to your Android phone (WhatsApp to yourself,
   Google Drive, or USB).
2. Tap it to install. Android will warn "install from unknown source" — allow
   it (Settings will offer a toggle). This is normal for an APK not from the
   Play Store.
3. Open **Setu**, log in with a test number from Step 3 (e.g. `+919000000001`
   / `123456`), and click through: create a profile, browse services, open the
   timeline, try SOS (it will offer to call 108 — you can cancel).
4. Once **you** are happy it works, send the same `.apk` file + one test
   number + code to each friend. Tell them to install the same way.

**After Part A:** friends can log in and use the whole app. The AI chat will
say "still being set up" until you do Part B, and paying for a booking needs
Part B's Razorpay step — everything else works.

---

# PART B — Turn on the smart features (recommended, cheap)

These use outside services. Set them as **Edge Function secrets** in Supabase:
dashboard → **Project Settings** → **Edge Functions** → **Add new secret**
(name + value → Save). After adding secrets they take effect within a minute.

## Step 7 — AI features (the assistant, visit summaries) — a few dollars

1. Go to `platform.openai.com` → sign in → **API keys** → **Create new secret
   key**. Copy it (starts with `sk-...`). Add a small amount of billing credit.
2. In Supabase Edge Function secrets, add:
   - Name: `OPENAI_API_KEY`  Value: your `sk-...` key.
3. Done — the AI assistant and summaries now work. (Until this is set they show
   a friendly "still being set up" message, never an error.)

## Step 8 — Payments (booking payment, plans) — FREE in test mode

Use Razorpay **Test Mode** so no real money moves; test cards simulate payment.

1. Go to `dashboard.razorpay.com` → sign up / log in.
2. Switch to **Test Mode** (toggle near the top).
3. **Settings** → **API Keys** → **Generate Test Key**. Copy the **Key ID**
   and **Key Secret**.
4. In Supabase Edge Function secrets, add:
   - `RAZORPAY_KEY_ID` = the test Key ID
   - `RAZORPAY_KEY_SECRET` = the test Key Secret
5. (Optional, for payment confirmations) **Settings** → **Webhooks** → add a
   webhook pointing to
   `https://veumfexjpxqhxemjaaor.supabase.co/functions/v1/payments-webhook`,
   set a secret, and add that same secret in Supabase as `RAZORPAY_WEBHOOK_SECRET`.
6. In the app, pay with Razorpay's **test card** `4111 1111 1111 1111`, any
   future expiry, any CVV.

## Step 9 — Background jobs (reminders, daily doses) — optional for a short test

These are the automatic tasks (send reminders, generate the day's medicine
doses, weekly summaries). For a **short** friends test you can skip them. To
turn them on, follow `docs/GO-LIVE-CHECKLIST.md` sections 1e and 2 — it lists
every job, the secret it needs, and a suggested schedule.

---

# PART C — Publish to the Google Play Store (when you're ready)

This is a separate, bigger stage. Do it only after friends' feedback.

## Step 10 — Branding polish
- A real **app icon** (replace the default Flutter icon) and a final app name.
  Tell me and I'll wire this in with the `flutter_launcher_icons` tool.

## Step 11 — A real signing key (required by Play, kept only by you)
- The Play Store needs the app signed with **your own** key (not the debug key
  the test APK uses). This key is a secret that must live on your machine —
  I cannot generate or hold it for you.
- I'll write `docs/BUILD-ANDROID.md` with the exact commands to create the key
  and build the upload file (`.aab`) when you reach this step.

## Step 12 — Legal pages (Play will not publish without them)
- A **Privacy Policy** (mandatory) and **Terms of Service**, hosted at a public
  URL. For an elder **health** app under India's DPDP law this matters. I can
  draft both from how the app actually handles data — just ask.

## Step 13 — Play Console + submit
- Create a **Google Play Console** account (one-time US$25).
- Create the app, fill the store listing (description, screenshots, category
  "Medical"/"Health & Fitness"), complete the Data Safety form, upload the
  `.aab`, and submit for review.

---

## Quick reference — the shortest path to "my friends are testing it"

1. Copy Supabase **URL** + **anon key** (Part A, Step 1).
2. Add them as GitHub **repository secrets** (Step 2).
3. Add **test phone numbers** in Supabase Auth (Step 3).
4. Confirm seed data (Step 4).
5. **Actions → Build APKs → Run workflow** → download the APK (Step 5).
6. Install, test, share with the test numbers (Step 6).

That's it — everything else (AI, payments, Play Store) is optional and can come
after your friends have had a look.
