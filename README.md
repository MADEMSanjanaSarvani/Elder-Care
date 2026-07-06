# Project Setu

Working codename for the AI-powered elder care platform — see
`docs/prd/` for the full product/architecture rationale before changing
anything here. Start with Part 1 if you're new to the project.

## Layout

```
docs/prd/                    the three-part PRD (strategy, architecture, execution)
supabase/                    schema, RLS, seed data, Edge Functions — see supabase/README.md
packages/setu_core/          shared Flutter package: models, consent logic, design tokens
apps/family_elder_app/       family-mode / elder-mode Flutter app
apps/caregiver_app/          caregiver Flutter app
apps/admin-dashboard/        internal ops console (Next.js — not Flutter; see its README for why)
melos.yaml                   Flutter monorepo tooling (packages + the two Flutter apps only)
```

## Why this structure

`setu_core` exists so consent-gating and trust-tier logic can't fork
between the two apps (PRD Part 3 §18) — a bug fixed in one app is fixed
in both, because it's the same code. Every table that would otherwise
hardcode "India"/"₹" carries a `region_id` instead (PRD Part 2 §11, Part 3
§22), so Phase 2-6 city/country expansion is new config, not a rewrite.

## Getting this running locally

The Flutter side (`packages/`, `apps/family_elder_app`, `apps/caregiver_app`)
was scaffolded in a container without the Flutter SDK, Dart, or the
Supabase CLI installed — none of it has been run, only written to spec.
The admin dashboard is different: it was built with Node available, so
`npm install`, `tsc --noEmit`, and `next build` have all actually been
run against it and pass clean.

```bash
# Backend (not yet run against a real project — see supabase/README.md)
cd supabase && supabase db reset && supabase functions serve

# Admin dashboard (this one's actually been built and typechecked)
cd apps/admin-dashboard && npm install && npm run build

# Each Flutter app (see each app's own README for the flutter create step — unverified)
cd apps/family_elder_app && flutter pub get && flutter analyze
cd apps/caregiver_app && flutter pub get && flutter analyze
```

## Deliberately not yet built

See `supabase/README.md` and each app's README for what's scoped out of
this pass — notably: `payouts-run` automation (also blocked on caregiver
bank/UPI details not being modeled yet), DPDP data-subject-rights
endpoints, write-side instrumentation for the audit log (the table and
viewer exist; nothing populates it), live caregiver GPS tracking, push
notifications, and the full 10-language rollout. These were left as
documented gaps rather than filled with placeholder logic — check the
relevant PRD section before implementing them.
