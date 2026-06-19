# Changelog

What changed, newest first. Grouped by day (we don't cut version numbers yet).
`git log` has the authoritative per-commit detail.

## 2026-06-09
- Renamed the **"Rates" sheet tab to "Customers"** everywhere (code + docs); added
  an **Address** column and a `?action=customers` read.
- **Route mapping** — an address per stop, a map of the planned route, and
  turn-by-turn handoff to Apple Maps.
- **Planning backlog is sheet-backed** (shared across devices) via a new Plan tab
  + `PlanStore`; the Planned list collapses into one tappable bar on both tabs.
- **Planning** — "+plan" a customer on the Planning tab; tap it on the Lawns tab
  to log it with the customer pre-selected.
- Auto-focus the "Other" / new-customer text fields when chosen.
- Expense form: **100% Gas / Other** choice + a **$** amount field; faster reload.
- Tabs reordered to **Expenses | Lawns | Planning**, opening on Lawns.
- Added the **Expenses tab** + a shared **"+" dropdown** (Log a Lawn / Log an
  Expense) on both tabs.
- "How much?" shows a grayed **"Standard"** placeholder, one tap to type a rate.
- **Redesigned Log a Lawn** with a modern card UI (no data-entry change).
- **Debug error logging** — Settings toggle posts errors to an "Errors" sheet tab.
- **Audit quick-fixes** — reliable save (no silent loss), stable list identity,
  growing customer dropdown, exact filter match, Settings test-connection.
- Added **clasp** one-command deploy scaffolding + a CLAUDE.md deploy rule.

## 2026-06-08
- **Lawns filter** (top-right) across all lawns: customer, paid status, team
  member, and a date range.
- **Tap a lawn to edit** all its fields, written back to the sheet by timestamp.
- **"See all / Show less"** toggle on the Lawns list.
- Backend reads only real dated rows (skips header/summary rows); coerces
  day-counts that Sheets auto-formatted as dates.
- Planning badge shows **N/A** until the first mow, then days since the most recent.
- Weather: simpler **AM/PM green/yellow/red** mowing colors, horizontal-only,
  reload via the top button, "Tue, 9" labels.

## 2026-06-07
- **7-day NWS weather** strip on the Planning tab, following current location.
- Lawns **sort newest-first by timestamp**, independent of the sheet's sort.
- Lawns show the **5 most recent** (or the full last-24h day when busier).
- Moved Expenses out of the Lawns tab; added the CLAUDE.md "always sync" rule.
- Persisted the signing **DEVELOPMENT_TEAM** so it stops disappearing.

## 2026-06-04
- App reads **live from the sheet** (mirrors adds/deletes); lasso app icon;
  currency-formatted expenses.
- Added the **Planning tab** (customers + days since mowed).

## 2026-05-29
- First app: SwiftUI home with the **+dropdown logging**, forms matching the
  Google Forms, and the Sheets backend layer.
- Forced dark mode, green/lasso splash, built-in backend URL, one-click sheet
  setup, HTML demo/preview tools, and docs.

## 2026-05-27
- Initial commit.
