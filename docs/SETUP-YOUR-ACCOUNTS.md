# CareHive — Your Setup Checklist (accounts & credentials)

This is **your part**: the external accounts to create and the values to hand
over so the app becomes a real, production website + mobile app. Work top to
bottom — each section says exactly what to do, what to send me, and what I do
with it.

## How to share credentials safely

- **Public values** (project URL, anon key, publishable/Key ID, OAuth *client
  ID*, domain): fine to paste to me in chat.
- **Secret values** (API *secret* keys, auth tokens, service accounts): **you**
  paste these into the dashboard yourself (Supabase → Project Settings → Edge
  Functions → **Secrets**, or GitHub → repo → Settings → Secrets). Tell me the
  **name** you saved it under; my code reads it by name and never sees the value.
- Never commit secrets to the repo.

---

## 1. Supabase — backend, database, auth  *(you likely already have this)*

**Website:** https://supabase.com

- [ ] Confirm your project is linked (migrations already auto-apply on push).
- [ ] Project Settings → API → copy **Project URL** and **anon public key** →
      send me (so I confirm the app points at the right project).
- [ ] Auth → Providers → **Email**: for a smooth pilot, turn **"Confirm email"
      OFF** (instant signup). For public launch, turn it ON *after* you set up
      custom email (section 7).
- [ ] Nothing to run by hand — `supabase/seed.sql` creates the region, the
      service catalogue *and* the demo caregivers, so the marketplace is
      never empty after a deploy.

**Send me:** Project URL + anon key. **You set as secrets later:** payment & SMS keys.

---

## 2. Razorpay — payments (India, UPI/cards)  *(you said you have keys)*

**Website:** https://razorpay.com

- [ ] Sign up; complete **KYC** (business/PAN/bank) to enable **Live** mode.
      (Test mode works immediately for development.)
- [ ] Dashboard → Settings → **API Keys** → Generate keys. You get:
  - **Key ID** (starts `rzp_test_` / `rzp_live_`) — public.
  - **Key Secret** — secret.
- [ ] In Supabase → Edge Functions → **Secrets**, add:
  - `RAZORPAY_KEY_ID` = your Key ID
  - `RAZORPAY_KEY_SECRET` = your Key Secret
- [ ] Later I'll give you a **Webhook URL** → add it in Razorpay → Settings →
      Webhooks (event: `payment.captured`) and set a webhook secret
      `RAZORPAY_WEBHOOK_SECRET` in Supabase secrets.

**Send me:** the **Key ID** (public) for the app. **I build:** real checkout →
signature verification → then activate the plan/booking.

---

## 3. Google Cloud + Firebase — Google Sign-In & Push (FCM)

**Websites:** https://console.cloud.google.com and https://console.firebase.google.com

### Google Sign-In
- [ ] Cloud Console → create/select a project → **OAuth consent screen**
      (External, add app name, support email, logo).
- [ ] Credentials → Create **OAuth client ID**:
  - a **Web** client (Supabase uses this) → gives a Client ID + Secret.
  - an **Android** client → needs your app **package name**
    (`in.carehive.app` or whatever we set) + **SHA-1 fingerprint** of your
    signing key (from section 6 keystore; I'll show the command).
- [ ] Supabase → Auth → Providers → **Google** → paste the Web Client ID + Secret.

**Send me:** the **Web client ID**. **You set in Supabase:** Google provider on.

### Push notifications (FCM)
- [ ] Firebase Console → create project → add an **Android app** with the same
      package name → download **`google-services.json`**.
- [ ] Project Settings → Cloud Messaging → note the setup (I'll wire the app +
      a send function).

**Send me:** the `google-services.json` file (commit it or share it). **You set
as secret:** the FCM service account / server key (name: `FCM_SERVICE_ACCOUNT`).

---

## 4. SMS provider — phone OTP login

Pick one (India-friendly first):
- **MSG91** — https://msg91.com  (best for India)
- **Twilio** — https://twilio.com

- [ ] Sign up; get an API key / sender ID (MSG91) or Account SID + Auth Token +
      a phone number (Twilio).
- [ ] Supabase → Auth → Providers → **Phone** → enable → select provider →
      paste the credentials there.

**You set in Supabase directly** (I don't need the raw values). Once it's on,
the phone-OTP login already in the app starts working. **Tell me:** "phone auth
is enabled" so I switch the UI copy from "SMS setup pending" to live.

---

## 5. Hosting + domain — the real website

- [ ] **Domain:** register one (e.g. `carehive.in`) at Namecheap / GoDaddy /
      Google Domains.
- [ ] **Hosting:** create a **Vercel** account (https://vercel.com) and connect
      this GitHub repo. Vercel hosts the **admin dashboard** (Next.js) and, if
      you want, the **family web app** (Flutter web build).
- [ ] Point your domain's DNS at Vercel (Vercel gives exact records).

**Send me:** the domain name, and add me/your account as a Vercel project.
**I set up:** build config for the admin dashboard (and Flutter-web if you want
families to use it in a browser too — see the question at the bottom).

---

## 6. Google Play Console — publish the Android app

**Website:** https://play.google.com/console

- [ ] Pay the **one-time $25**, create a developer account (needs ID
      verification, can take ~2 days).
- [ ] Create the app; fill the store listing (I already drafted copy + graphics
      in `docs/store/`).
- [ ] You'll need a **release keystore** (I'll walk you through
      `keytool` — see `docs/BUILD-ANDROID.md`). Keep it safe; it signs every
      update. Its SHA-1 also feeds Google Sign-In (section 3).
- [ ] **Privacy Policy URL** (required): host `docs/legal/PRIVACY-POLICY.html`
      on your domain and paste the URL in the listing + Data Safety form.

**Send me:** your package name choice and the SHA-1 once the keystore exists.

---

## 7. Transactional email  *(optional but recommended for launch)*

Supabase's built-in email is rate-limited. For real signup/confirmation emails:
- [ ] Create a **Resend** (https://resend.com) or SendGrid / AWS SES account.
- [ ] Verify your domain there (DNS records).
- [ ] Supabase → Auth → **SMTP settings** → paste the SMTP host/user/pass.

**You set in Supabase directly.**

---

## Priority order (my suggestion)

1. **Razorpay** (you have keys) → I wire real payments.
2. **Domain + Vercel** → the admin dashboard goes live on a real URL.
3. **Google Sign-In + Phone OTP** (Supabase config) → richer login.
4. **FCM** → real push notifications.
5. **Play Console** → publish the Android app.
6. **Custom email** → production-grade signup.

Send me each section's **public values** as you finish it and I'll wire that
integration immediately. Secrets you drop into Supabase/GitHub yourself — just
tell me the names you used.
