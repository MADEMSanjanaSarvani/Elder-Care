# Publishing the SETU public site

Four static pages — home, privacy policy, terms, support. They exist because
**Google Play will not publish an app without a publicly reachable privacy
policy URL**, and because a family who has just been asked to trust a stranger
with their mother will look SETU up before they install anything.

Hosted on **Firebase Hosting**. Netlify was the other candidate and is not
used: it needs a paid plan here, and Firebase is already on a Pro plan for this
project.

## Deploy

```bash
npm install -g firebase-tools     # once
firebase login                    # once
firebase deploy --only hosting
```

`firebase.json` at the repo root points hosting at `docs/public-site` with
`cleanUrls` on, so `/privacy` serves `privacy.html` — the URL that goes in the
Play Store listing has no `.html` in it and stays stable if the file is ever
renamed.

The first deploy needs the project selected:

```bash
firebase use --add          # pick the Firebase project, alias it "default"
```

That writes `.firebaserc`, which is deliberately **not** committed — it names a
specific Firebase project and belongs to whoever is deploying.

## What goes in the Play Store listing

| Play Console field | URL |
|---|---|
| Privacy policy | `https://<your-site>.web.app/privacy` |
| Support / contact website | `https://<your-site>.web.app/support` |

Once a custom domain is attached in the Firebase console, swap the host and
update the two links — Play Console lets you change them after publishing.

## Regenerating the pages

The HTML is generated, not hand-edited:

```bash
python3 tools/build_public_site.py
```

Edit the copy in that script so a regeneration doesn't silently discard
changes. The privacy text must stay in step with what the app actually does —
if a new data type starts being collected, or the AI provider changes (see
`docs/business/SETU-ai-provider.md`), the policy has to say so before the
change ships.
