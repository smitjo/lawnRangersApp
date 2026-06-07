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

## Notes

- The Xcode project uses `PBXFileSystemSynchronizedRootGroup`, so **new source
  files do not require editing `project.pbxproj`** — just add the `.swift` file.
- Open backlog lives in [`todo.md`](todo.md).
