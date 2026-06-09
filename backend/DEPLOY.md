# One-command backend deploys (clasp)

Push `backend/Code.gs` to the Apps Script project and redeploy the **same
`/exec` Web App URL** with a single command — no copy-paste, no Deploy menu.

> Note: this doesn't *remove* the redeploy (the `/exec` URL always serves a
> pinned version), it **automates** it. `./backend/deploy.sh` does the push +
> redeploy for you.

## One-time setup

1. **Install Node** (no Homebrew needed): download the macOS `.pkg` from
   <https://nodejs.org> and run it. Verify: `node -v` and `npm -v`.
2. **Install clasp:** `npm install -g @google/clasp`
3. **Enable the Apps Script API** for your Google account (one click):
   <https://script.google.com/home/usersettings> → turn **Google Apps Script API** ON.
4. **Log clasp in:** `clasp login` (opens a browser; sign in as the account that
   owns the sheet's script). This stores a token in `~/.clasprc.json` (outside the repo).
5. **Link the project:**
   - In the Apps Script editor: **Project Settings (gear)** → copy the **Script ID**.
   - In the repo: `cp .clasp.json.example .clasp.json` and paste your Script ID in.
6. **Record the deployment id** (so we redeploy the existing Web App, keeping the
   same `/exec` URL):
   - Run `clasp deployments` — copy the Web App deployment id (starts with `AKfyc…`).
   - Save just that id into `backend/.deployment-id`.

`.clasp.json`, `.clasprc.json`, and `backend/.deployment-id` are git-ignored
(they hold your IDs/login).

## Every deploy after that

```sh
./backend/deploy.sh
```

That pushes `backend/Code.gs` + `appsscript.json` and redeploys the same URL.

## Notes / gotchas

- `appsscript.json` here mirrors the current deployment (**Execute as: Me**,
  **Who has access: Anyone**). If your sheet's time zone isn't US Eastern, change
  `timeZone` in `appsscript.json`.
- clasp pushes the whole `rootDir` (`backend/`), i.e. `Code.gs` + `appsscript.json`.
- First push may warn it will overwrite the online code — that's expected; the
  repo is the source of truth.
