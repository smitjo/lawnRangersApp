# Lawn Rangers — TODO

> Only what's left to do. Finished work is in [`CHANGELOG.md`](CHANGELOG.md).

## Backend deploy (pending)
- [ ] Confirm the live Apps Script `/exec` is redeployed with the latest
  `backend/Code.gs` (Plan endpoints, error logging, Customers tab + Address,
  customers read). Manual for now — see the clasp decision below.

## Planning & weather
- [ ] **Forecast 7 → 10 days?** NWS only goes ~7 days; a true 10-day needs a
  switch to **Open-Meteo** (free, no key, up to 16 days, same AM/PM split).
  Caveat: its free tier is non-commercial/fair-use. Decision pending.
- [ ] **Per-mowing-day detail** — tap a Tue/Thu weather card for the NWS
  `detailedForecast` ("rain after 2pm").
- [ ] **Route polish** — optimize stop order (nearest-neighbor); option to start
  from current location.

## Voice planning + Tue/Thu auto-scheduling (BUILT — archived, reintegrate later)
Built 2026-06-20, then wound back off `main`. Archived on the GitHub branch
**`voice-features-june-20`** — restore from there, don't rebuild
(`git fetch origin` then `git checkout voice-features-june-20`).
- [ ] **Speak to plan** — mic button on the Planning tab (`VoicePlanView`): say
  "plan Johnson" or "schedule everyone"; **ElevenLabs Scribe** transcribes, the
  customer is matched, the mow is booked and added to the shared plan, and the
  confirmation is **spoken back** in an ElevenLabs voice.
- [ ] **Tue/Thu auto-scheduling** — dates snap to the next Tue/Thu; an
  "Auto-schedule due lawns" button (On-device / From-sheet toggle) does it in bulk.
  Both voice and the From-sheet button book the **soonest Tue/Thu from today**.
- [ ] **To make it run (the gotchas):** ElevenLabs key in Apps Script **Script
  Properties** (`ELEVENLABS_API_KEY`, optional `ELEVENLABS_VOICE_ID`), server-side
  only; **authorize the `script.external_request` scope** by running any function
  in the Apps Script editor and clicking Allow — redeploying alone does NOT grant
  it (that was the "no permission to call UrlFetchApp.fetch" error);
  `NSMicrophoneUsageDescription` build-setting string + a backend redeploy.
- [ ] **Bundled on that branch (separable):** the Customers-tab merge (folds the
  "Planning" tab into "Customers" — one row per customer with rate + address +
  mow-cycle — and renames "Plan" → "Job Queue"). The `RouteMapView` bug fixes
  (geocoder rate-limit throttle + retry, case/space-insensitive address match) were
  in a local stash and may need re-doing.
- [ ] **Sanity-check on reintegration:** the From-sheet button schedules *every*
  customer (not just overdue) onto the next mow day; voice name-matching is
  whole-name `contains`, so "Johnson" won't match a sheet name "Bob Johnson."

## Lawns & money
- [ ] **Make the app money-aware (high value).** `readEntries` returns only 7 of
  14 columns — it drops Rate / per-teammate splits / Overhead / Unpaid that the
  sheet already computes. Widen to 14, add fields to `SheetLawn`, show a
  per-customer outstanding balance + per-teammate owed total. Needs a redeploy.
  Prerequisite for the payment feature.
- [ ] **One-tap "Request payment"** — Venmo/Zelle deep link pre-filled with the
  customer + Unpaid amount. After money-aware lands.
- [ ] **Offline queue (only if ever wanted)** — DECIDED 2026-07-07: the sheet is
  the single source of truth; SwiftData and all local data were removed, and the
  app requires internet by design. Revisit only if offline logging becomes a
  real need in the field.
- [ ] **Optimistic insert** + drop the reload sleep; **auto-refresh on foreground**.
- [ ] **Search** lawns by customer/date across all history (and reuse for Expenses).

## Expenses
- [ ] **Edit/delete an expense** (needs an `expenseUpdate`/delete endpoint) — rows
  are read-only today.
- [ ] **Dedicated expenses fetch** (`?action=expenses`) so the tab doesn't pull
  lawn data; add an **expenses total** + grouping by month/category.

## Future feature ideas
- [ ] **Mower hours on the first lawn of the day** — log each mower's hour-meter
  reading into a "Mower Hours" tab.
- [ ] **Location-based job timing** — geofence each property to auto-time
  arrive→leave; store minutes per job (needs Always-location + property coords).

## Security / hardening (before any wider release)
- [ ] **Authenticate the `/exec` endpoint** — shared-secret token in
  PropertiesService; stop returning the PII note unauthenticated; rotate the
  baked-in URL.
- [ ] **Low-priority backend hardening** — UUID id per entry (vs same-second `ts`
  match), exact-match the teammate-split REGEXMATCH, optional LockService guard.

## Cleanup
- [x] **Remove dead code** — done 2026-07-07: `PlannedJob`, `CustomerDirectory`
  seed list, the SwiftData container, and all local persistence removed; the
  sheet is the only store.
- [ ] **Shared form components** — the two log forms duplicate the card-style
  helpers; factor them out.
- [ ] **App icon** — drop the real 1024×1024 lasso PNG into the AppIcon well
  (current is a code-drawn replica).
- [ ] **Field-readability pass** — bigger touch targets + larger money/Paid type;
  reconsider forced dark mode / add a high-contrast outdoor mode.

## Decisions pending
- [ ] **clasp one-command deploys** — scaffolded (`backend/deploy.sh`,
  `backend/DEPLOY.md`); blocked on installing Node (nodejs.org `.pkg`, no
  Homebrew). Discuss with Dad, then: install Node → `npm i -g @google/clasp` →
  enable the Apps Script API + `clasp login` → give Claude the Script ID +
  deployment ID.
- [ ] **WeatherKit** — if the app goes to the App Store (paid Apple Developer
  Program), switch `WeatherService` from NWS to WeatherKit (better data, no
  US-only limit).

## Spreadsheet (manual, in Google Sheets)
- [ ] **Filter views on the Lawn Log tab** — start the range at the header row
  (below the summary rows); prefer Filter Views (private/saved) over a basic
  filter. Useful views: Unpaid jobs, By customer, Per-teammate earnings, This month.
- [ ] **Confirm the `/exec` deployment is bound to the right spreadsheet**
  (Lawn Log / Planning / Customers).
