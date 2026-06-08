# Lawn Rangers — TODO Queue

> Working backlog. Expenses have been **removed from the Lawns tab** (Lawns is
> now lawns-only). The Expenses **tab itself is not built yet** — it's specced
> below as a future task. When the user asks to "add the expenses tab," build it
> from this spec rather than inventing a new design.

---

## A. Build the Expenses tab (NOT built yet — primary future task)

Add a third tab, **Expenses**, that behaves almost exactly like the Lawns tab
(`HomeView`). This is the deferred work the user asked to defer to this file.

**Current interim state to be aware of:** expenses were removed from the Lawns
tab, and the "Log an Expense" action went with them, so **there is currently no
in-app way to view or log expenses** until this tab is built. (`LogExpenseView`
and the `Expense` model still exist, unused, ready to be wired back in.)

### Spec (mirror `HomeView` / Lawns)

- **New file:** `LawnRangers/Views/ExpensesView.swift` (Xcode uses
  `PBXFileSystemSynchronizedRootGroup`, so no `project.pbxproj` edit needed).
- **Wire into `MainTabView`** between Lawns and Planning:
  `ExpensesView().tabItem { Label("Expenses", systemImage: "dollarsign.circle.fill") }`
- **Data:** read live from the sheet via `EntriesService.fetch()`, using only
  `result.expenses` (`[SheetExpense]`). (Lawns uses the same call's `.lawns`.)
- **Toolbar (same layout as `HomeView`):**
  - top-leading: gear → `SettingsView` (sheet)
  - top-trailing: refresh button (`arrow.clockwise`), disabled while loading
  - top-trailing: `+` button → `LogExpenseView` (sheet). Single button (not a
    menu) since this tab only logs expenses.
- **Navigation title:** `"Expenses"`.
- **States (mirror `HomeView.content`):** loading `ProgressView`; error
  `ContentUnavailableView` ("Couldn't load" + Try Again); empty
  `ContentUnavailableView` ("No expenses yet" — "Tap the + button…").
- **Order:** sort by `expense.ts` descending (newest first), the same way
  `HomeView` sorts lawns — do **not** rely on `reversed()` / sheet row order.
- **Row layout (per expense):**
  - headline: `expense.expenses` (fallback `"Expense"`)
  - subheadline row: `expense.date` on the left, `currencyFormatted(expense.amount)` on the right
  - caption (if present): `expense.comment`
- **`currencyFormatted` helper:** same as the one that used to live in
  `HomeView` — strip to digits/`.`, format `.currency(code: "USD")`, fall back to
  raw text if non-numeric.
- **Auto-refresh after submit:** on the log sheet dismissing, `Task.sleep(1.2s)`
  then reload (mirror `HomeView`'s `onChange` behavior).
- **`.task` initial load** when the list is empty, plus `.refreshable`.

### Secondary parity / polish (after the tab exists)

- [ ] **Dedicated expenses fetch** — add `?action=expenses` (or a separate
  service) so the tab doesn't pull lawn data it ignores.
- [ ] **Expenses total / summary** at the top (like the sheet's summary rows).
- [ ] **Swipe-to-delete**, kept in sync with the sheet (needs a backend delete).
- [ ] **Shared row/list components** — factor out the list scaffolding, the
  `currencyFormatted` helper, and the empty/error/loading states shared with
  `HomeView` to avoid drift.
- [ ] **Grouping / filtering** by month or category.
- [ ] **Build verification** in Xcode (cannot compile in the agent environment).

---

## A2. Lawns tab — "Show all history" (future)

- [ ] **Add a way to see *all* lawns in the app**, not just the limited recent
  view. The Lawns tab now shows the last 5 (or the full last-24h day when it has
  more than 5), so older history lives only in the sheet. Options to consider:
  - A toggle / segmented control at the top: **Recent** vs **All**.
  - A "Show all" button at the bottom of the list that expands to `sortedLawns`.
  - A search field to find a specific customer/date across all history.
  Whatever the entry point, "All" should display `sortedLawns` (already
  newest→oldest by `ts`), and ideally adopt the same approach for the future
  Expenses tab.

## A3. Weather (NWS forecast on Planning tab)

A 7-day NWS forecast strip is live at the top of the Planning tab
(`Views/WeatherForecastView.swift`, `Backend/WeatherService.swift`), using the
**device's current location** (`Backend/LocationProvider.swift` via CoreLocation;
`NSLocationWhenInUseUsageDescription` is set in the build settings). Each day is
split into AM/PM and color-coded by rain chance (green <5%, yellow 5–14%, red
15%+) from the NWS hourly forecast, with Tue/Thu highlighted, a go/no-go summary,
and a legend. Reload is via the Planning tab's top button only. Follow-ups:

- [ ] **If/when this app is published to the App Store, look at switching to
  Apple WeatherKit.** Publishing requires a paid Apple Developer Program
  membership, which comes with an Apple Developer Team ID — and that same
  membership includes WeatherKit (500k calls/mo, better data, native Swift API).
  At that point WeatherKit becomes effectively free to use, so revisit replacing
  the NWS calls in `WeatherService` with it (also removes the US-only limit).
- [ ] **Optional: per-mowing-day detail** — tap a Tue/Thu card to see the NWS
  `detailedForecast` (e.g. "Rain likely, mainly after 2pm") for rain timing.

## B. Remaining open items from the project handoff

- [ ] **Backend redeploy (#3) — REQUIRED for the newest→oldest sort.** The Lawns
  tab now sorts by a raw `ts` (epoch ms) field that `readEntries` in
  `backend/Code.gs` was just updated to send. Until the Web App is redeployed,
  the app receives no `ts` and the sort falls back to flat order. Update
  `backend/Code.gs` in the app's spreadsheet, run `setupSpreadsheet` (adds the
  Planning tab), set each customer's mow interval, then redeploy via **Manage
  deployments → Edit → New version** (keeps the same `/exec` URL) so the `ts`
  sort, Planning, and the Home `?action=entries` mirroring all work.
- [ ] **Confirm the deployed `/exec` binding (#4).** Verify the deployed Web App
  is bound to the app's actual spreadsheet (the one with Lawn Log / Planning).
- [ ] **App icon (#5, optional).** Current icon is a code-generated LR-lasso
  replica; drag the exact original 1024×1024 PNG into the AppIcon well if
  preferred.
- [ ] **Remove unused SwiftData (#8, optional).** SwiftData is still wired up
  (`LawnRangersApp.swift` model container) but Home no longer reads it; could be
  removed entirely.

## C. Spreadsheet (Google Sheets)

- [ ] **Set up filters / filter views on the Lawn Log tab** (like the 2025 lawn
  mowing sheet). Notes for when this comes up:
  - The Lawn Log tab has **Total Earned / Unpaid summary rows on top**, so the
    filter range must start at the **header row** (`Timestamp | Where? | …`), not
    the summary rows.
  - Prefer **Filter Views** (`Data → Filter views`) over a basic filter, since
    it's a shared sheet — a plain filter changes the view for everyone, a filter
    view is private and saved by name.
  - Suggested useful views to build: **"Unpaid jobs"** (Customer paid? = Unpaid),
    **"By customer"** (sort Where? A→Z), **"Per-teammate earnings"** (filter Who?
    / sum the per-person columns), **"This month"** (Timestamp condition).
  - Heads-up: the iOS app appends rows via Apps Script; if a freshly-logged job
    doesn't appear under a basic filter, remove and recreate the filter to
    refresh its range.

## Done (for reference)

- [x] Persist signing `DEVELOPMENT_TEAM` so it stops disappearing.
- [x] Reconcile local/remote `main`.
- [x] Delete redundant remote branches (`claude/...`, `experiment/load-from-sheet`).
- [x] Remove expenses from the Lawns tab (Lawns is now lawns-only).
- [x] Lawns tab sorts newest→oldest by in-app timestamp (`ts`), independent of
  the sheet's filter/sort.
- [x] Lawns tab shows the 5 most recent lawns by default, and the whole last-24h
  day's lawns when that day has more than 5 (app-side, by timestamp).
- [x] Mowing-weather strip on the Planning tab: each day split AM/PM and
  color-coded by rain chance (green/yellow/red) with temp, Tue/Thu highlighted,
  using NWS hourly + the device's current location.
