# SETU — Credentials & Data Needed to Go Production

*How to read this: **[TELL ME]** = a non-secret value you can send in chat. **[YOU ADD]** =
a secret you put into a vault yourself (never paste secrets in chat). Vaults:*
- **GH** = GitHub → repo Settings → Secrets and variables → Actions
- **SB** = Supabase → Project → Edge Functions → Secrets (Manage secrets)
- **FILE** = a file you upload to me (safe: config files, not raw secrets)

---

## 1. Payments — Razorpay (Priority 1)
- [YOU ADD → SB] `RAZORPAY_KEY_ID`
- [YOU ADD → SB] `RAZORPAY_KEY_SECRET`
- [YOU ADD → SB] `RAZORPAY_WEBHOOK_SECRET`
- [TELL ME] Razorpay account type: **Route** (marketplace split) enabled? yes/no
- [TELL ME] Business legal name, **GSTIN**, registered address, support email + phone → for invoices
- (You need a Razorpay merchant account + KYC approved first — https://razorpay.com)

## 2. Subscriptions — Google Play Billing
- [TELL ME] Final **package name** (e.g. `com.setu.care`) — must be decided before first Play upload
- [TELL ME] Subscription **product IDs + prices** you want (e.g. care_plus_monthly ₹499, care_pro_monthly ₹1499) — or say "use my suggestions"
- [YOU ADD → SB] Play **service-account JSON** (for server-side purchase verification) — from Play Console → API access
- Requires a **Google Play Console account** ($25 one-time) with the app created.

## 3. Video calls — Agora
- [TELL ME] `AGORA_APP_ID` (public — a default is already in the app; confirm or replace)
- [YOU ADD → SB] `AGORA_APP_CERTIFICATE` (secret — enables secure token auth)
- (Agora console → your project → App ID + primary certificate. https://console.agora.io)

## 4. AI Companion — LLM
- [TELL ME] Provider: **OpenAI** or **Anthropic**?
- [YOU ADD → SB] `OPENAI_API_KEY` or `ANTHROPIC_API_KEY`
- [TELL ME] Monthly budget cap you want enforced (optional)

## 5. Maps & location
- [TELL ME] Provider: **Google Maps** or **Mappls (MapmyIndia)**?
- [YOU ADD → GH] `MAPS_API_KEY` (baked into the build)
- (Google: console.cloud.google.com → Maps Platform. Mappls: about.mappls.com/api)

## 6. Push notifications — Firebase (FCM)
- [FILE] `google-services.json` — from Firebase Console → your Android app
- [TELL ME] Firebase project ID
- (This same Firebase project also powers Crashlytics — item 8.)

## 7. SMS / OTP (for phone login + SOS alerts)
- [TELL ME] Provider: **MSG91** / **Gupshup** / other
- [YOU ADD → SB] `SMS_API_KEY` (+ `SMS_SENDER_ID` [TELL ME])
- [TELL ME] Approved DLT sender ID + template IDs (India requires DLT registration)

## 8. Email (receipts, invites, invoices)
- [TELL ME] Provider: **Resend** / **SendGrid** / SMTP
- [YOU ADD → SB] `EMAIL_API_KEY`
- [TELL ME] From-address (e.g. care@setu.app) — domain must be verified with the provider

## 9. Crash + analytics
- Crashlytics: comes free with the `google-services.json` (item 6) — just confirm you want it on
- [TELL ME] (optional) **Sentry DSN** if you prefer Sentry, [YOU ADD → GH] `SENTRY_DSN`

## 10. Supabase (backend) — mostly done ✅
Already provided: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_ACCESS_TOKEN`,
`SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD`.
- [YOU ADD → SB] `SERVICE_ROLE_KEY` confirm it's set for edge functions (usually auto)

## 11. Android release signing (for Play upload) — likely already set ✅
Already present in GH: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Keep these safe — losing them means you
can never update the app on Play.

## 12. Play Store listing (you fill in the Console, tell me if you want me to draft)
- [TELL ME] App name, short description (80 chars), full description
- [TELL ME] Support email, website, **privacy-policy URL** (I can host the policy text; you need a public URL)
- Screenshots + feature graphic (I can generate from the app once it's final)
- Data-safety form answers (I'll give you the exact answers from our data map)

## 13. Business/legal facts (for disclaimers, invoices, policies) [TELL ME]
- Legal entity name + type (Pvt Ltd?), city of registration
- Support phone number (shown in-app for SOS ops / help)
- Emergency ops on-call number (for SOS escalation), if any
- Refund window you want (default: 2 hours free-cancel — tell me if different)

---

### The 5 that unblock the most, if you want to start small
1. Razorpay keys (payments)
2. `google-services.json` (push + Crashlytics)
3. Agora App Certificate (video)
4. LLM API key (AI companion)
5. Package name + business/GST details (invoices + Play upload)

Send the **[TELL ME]** values in chat; add the **[YOU ADD]** secrets to the vaults and just tell me
"added X". Upload the **[FILE]** items. I'll wire each the moment it's available, one at a time.
