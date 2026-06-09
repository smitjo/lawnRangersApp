# Lawn Rangers — Project Rules

## Always sync after a change

**Any time you make a change to this repo, sync it.** After completing a set of
edits, do not leave work sitting only in the working tree:

1. Stage and commit the change with a clear message.
2. Push to `origin/main` so local and remote stay in sync.
3. Confirm sync (e.g. `git status` shows `ahead 0, behind 0` against
   `origin/main`).

Keep work on `main` (single source of truth). If a push to the shared repo is
blocked or prompts for confirmation (it is `smitjo`'s repo), surface that to the
user rather than silently skipping the sync.

## Deploy the backend after changing Code.gs

`backend/Code.gs` runs in Google Apps Script, **not** in the app — edits don't
take effect until the code is pushed and the Web App is redeployed. After
changing `Code.gs`, deploy it:

```sh
./backend/deploy.sh
```

This pushes `backend/` and redeploys the **same `/exec` URL** via clasp (one-time
setup: [`backend/DEPLOY.md`](backend/DEPLOY.md)). If clasp isn't set up on this
machine, fall back to pasting `Code.gs` into the Apps Script editor → **Deploy →
Manage deployments → Edit → New version**. Either way, tell the user a backend
change needs deploying — don't assume `Code.gs` edits are live.

## Notes

- The Xcode project uses `PBXFileSystemSynchronizedRootGroup`, so **new source
  files do not require editing `project.pbxproj`** — just add the `.swift` file.
- Open backlog lives in [`todo.md`](todo.md).
