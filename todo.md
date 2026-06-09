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

- [x] **See-all toggle** — a "See all" / "Show less" button on the list footer
  line expands the limited recent view to every lawn (`sortedLawns`) and back.
- [ ] **Optional: search** a specific customer/date across all history, and
  adopt the same see-all approach for the future Expenses tab.

## A3. Weather (NWS forecast on Planning tab)

A 7-day NWS forecast strip is live at the top of the Planning tab
(`Views/WeatherForecastView.swift`, `Backend/WeatherService.swift`), using the
**device's current location** (`Backend/LocationProvider.swift` via CoreLocation;
`NSLocationWhenInUseUsageDescription` is set in the build settings). Each day is
split into AM/PM and color-coded by rain chance (green <5%, yellow 5–14%, red
15%+) from the NWS hourly forecast, with Tue/Thu highlighted, a go/no-go summary,
and a legend. Reload is via the Planning tab's top button only. Follow-ups:

- [ ] **Decide: extend the forecast to 10 days (needs a provider switch).** NWS
  only forecasts ~7 days (hourly ~6.5), so a true 10-day view requires changing
  the data source. Best free option: **Open-Meteo** (no API key, up to 16 days,
  global, has hourly `precipitation_probability` + `temperature_2m`, so the same
  AM/PM color split carries over). Caveat: Open-Meteo's free tier is
  non-commercial / fair-use — fine for a small internal tool, worth noting for a
  business app. Decision pending: keep NWS (~7 days) vs switch to Open-Meteo (10).
- [ ] **If/when this app is published to the App Store, look at switching to
  Apple WeatherKit.** Publishing requires a paid Apple Developer Program
  membership, which comes with an Apple Developer Team ID — and that same
  membership includes WeatherKit (500k calls/mo, better data, native Swift API).
  At that point WeatherKit becomes effectively free to use, so revisit replacing
  the NWS calls in `WeatherService` with it (also removes the US-only limit).
- [ ] **Optional: per-mowing-day detail** — tap a Tue/Thu card to see the NWS
  `detailedForecast` (e.g. "Rain likely, mainly after 2pm") for rain timing.

## A4. Planning — per-customer "Schedule" button (future)

**Goal:** a small schedule button on the right of each customer row in the
Planning tab. Tapping it lets you pick/clear the next mow date for that customer.
Scheduling is handled in the app (the UI + logic); the **Planning sheet is the
store** so it persists and stays shared. All achievable for free.

### Data model
- **Sheet:** add a **"Next Scheduled"** column to the Planning tab (column F).
  In `setupSpreadsheet`, add the header + a date number format.
- **App:** add `scheduledDate: String?` to `PlanningCustomer`, and surface it on
  the row (e.g. "Scheduled: Jun 12", colored if it's today/overdue).

### Backend (Apps Script) — free, reuses the existing Web App
Add a `doPost` branch to write a customer's scheduled date, and include it in
`readPlanning`. Requires a redeploy (Manage deployments → Edit → New version) and
either re-running `setupSpreadsheet` or manually adding the column.

```js
// doPost(e): new branch
} else if (data.type === 'planSchedule') {
  var plan = ss.getSheetByName(PLANNING_TAB);
  if (!plan) throw new Error('No Planning tab');
  var n = Math.max(plan.getLastRow() - 1, 0);
  var names = plan.getRange(2, 1, n, 1).getValues();
  for (var i = 0; i < names.length; i++) {
    if (String(names[i][0]).trim().toLowerCase() ===
        String(data.customer).trim().toLowerCase()) {
      plan.getRange(i + 2, 6)   // column F = Next Scheduled
          .setValue(data.scheduledDate ? new Date(data.scheduledDate) : '');
      break;
    }
  }
  return json({ result: 'success' });
}

// readPlanning(): read 6 columns instead of 5, then add to each row:
//   scheduledDate: (r[5] instanceof Date) ? Utilities.formatDate(r[5], tz, 'MMM d') : str(r[5])
```

### App — button + scheduling sheet (SwiftUI)
```swift
// PlanningView.row(_:) — trailing button before the Spacer:
Button { scheduling = c } label: {
    Image(systemName: "calendar.badge.plus")
}
.buttonStyle(.borderless)
.tint(.lawnGreen)

// PlanningView state + sheet:
@State private var scheduling: PlanningCustomer?
// .sheet(item: $scheduling) { ScheduleSheet(customer: $0) { date in
//     await PlanningSubmitter.schedule(customer: $0.customer, date: date)
//     weatherRefreshTick += 0; await load()   // refresh after write
// } }
```
```swift
// New PlanningSubmitter.swift — mirrors SheetSubmitter, POSTs JSON to the Web App
enum PlanningSubmitter {
    static func schedule(customer: String, date: Date?) async {
        guard let url = BackendConfig.webAppURL else { return }
        let payload: [String: Any] = [
            "type": "planSchedule",
            "customer": customer,
            "scheduledDate": date.map { ISO8601DateFormatter().string(from: $0) } ?? ""
        ]
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        _ = try? await URLSession.shared.data(for: req)
    }
}
// ScheduleSheet = a DatePicker(.graphical) + Save / Clear buttons.
```

### Free reminder options (optional, pick one)
- **Local notifications (`UserNotifications`)** — simplest, free, offline, no
  server, no Info.plist string (just request authorization once). Fire a
  reminder at the scheduled date:
  ```swift
  import UserNotifications
  func remind(_ customer: String, at date: Date) {
      let c = UNMutableNotificationContent()
      c.title = "Mow \(customer)"; c.body = "Scheduled mow today."; c.sound = .default
      let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: date)
      let trig = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
      UNUserNotificationCenter.current().add(
          .init(identifier: "mow-\(customer)", content: c, trigger: trig))
  }
  // once: UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound]) { _,_ in }
  ```
- **EventKit (device Calendar)** — adds a real calendar event; also free but
  heavier (needs `INFOPLIST_KEY_NSCalendarsUsageDescription` + EventKit). Use
  only if a calendar entry is wanted over a simple reminder.

### Considerations
- **Match key:** find the customer by trimmed/lowercased name — same key the
  Planning formulas use. Names must match the Lawn Log "Where?" spelling.
- **Redeploy required** for the `doPost`/`readPlanning` changes; add the column.
- **Display/sort:** could sort the Planning list by scheduled date, or badge
  rows that are scheduled for today.
- **Permissions** (if adding reminders/calendar): add the usage strings as
  `INFOPLIST_KEY_*` build settings, like the location one.
- After a write, refresh via the top reload button (eventual consistency).

### Recommended MVP (all free)
1. Sheet: add "Next Scheduled" column + `doPost`/`readPlanning` support.
2. App: `calendar.badge.plus` button per row → graphical `DatePicker` sheet →
   `PlanningSubmitter.schedule(...)` → refresh.
3. Add a local notification reminder for the chosen date.
Defer EventKit/calendar unless a true calendar event is wanted.

## A5. Performance — scaling the Lawns list (only at higher capacity)

Not needed now. The SwiftUI `List` renders lazily (fine to 10k+ rows). The real
costs as data grows are: (1) every refresh fetches **all** lawns in one Apps
Script JSON blob (even the recent view fetches everything then filters), and
(2) `sortedLawns`/`displayedLawns` are computed properties, so they **re-sort on
every redraw**.

Rough thresholds (a lawn business logs ~600 mows/year, so these are years out):
- **< ~500:** nothing to do.
- **~500–2,000:** fine; memoize the sort if any lag appears.
- **~2,000–5,000:** **memoize the sort** — sort once into `@State` when data
  loads instead of recomputing every redraw. Cheap, low-risk win.
- **~5,000–10,000+:** **backend pagination** — fetch recent by default and load
  older rows as you scroll (range-based `readEntries`, e.g. `?action=entries&before=<ts>&limit=N`).

- [ ] **Memoize the Lawns sort** when we approach a few thousand entries (store
  the sorted array in state on load; don't re-sort in computed properties).
- [ ] **Add backend pagination** if we ever approach ~5k+ entries (load-as-you-
  scroll from the sheet instead of fetching everything each refresh).

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
- [x] Lawns tab "See all / Show less" toggle (always visible on the footer line).
- [x] Tap a lawn to edit all its fields; the change is written back to the sheet
  row (matched by timestamp) via a new `lawnUpdate` Apps Script endpoint.
  **Requires an Apps Script redeploy to take effect.**
- [x] Mowing-weather strip on the Planning tab: each day split AM/PM and
  color-coded by rain chance (green/yellow/red) with temp, Tue/Thu highlighted,
  using NWS hourly + the device's current location.
