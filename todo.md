# Lawn Rangers — TODO Queue

> Working backlog. The **Expenses tab** primary move is done (it now has its own
> tab mirroring Lawns). The items below are the deferred "secondary
> implementation" parity work plus the remaining open items from the project
> handoff.

---

## A. Expenses tab — secondary implementation (deferred)

The Expenses tab now lives in its own tab (`Views/ExpensesView.swift`) and
behaves like Lawns: live sheet read, `+` to log, refresh, settings, auto-refresh
after submit, and empty/error states. Remaining parity / polish:

- [ ] **Dedicated expenses fetch.** Both the Lawns and Expenses tabs call
  `EntriesService.fetch()`, which pulls *both* lawns and expenses every time.
  Add an expenses-only path (e.g. `?action=expenses`, or a separate service) so
  the Expenses tab doesn't over-fetch lawn data it ignores.
- [ ] **Expenses total / summary.** Show a running total (sum of amounts) at the
  top, similar to the sheet's "Total Earned" summary rows.
- [ ] **Swipe-to-delete (and keep in sync with the sheet).** Mirror whatever
  delete behavior Lawns gets; needs a backend delete endpoint in `Code.gs`.
- [ ] **Shared row/list components.** `HomeView` and `ExpensesView` duplicate the
  list scaffolding, the `currencyFormatted` helper, and the empty/error/loading
  states. Extract a shared row view + helpers to avoid drift.
- [ ] **Grouping / filtering.** Optionally group expenses by month or category
  once categories exist.
- [ ] **Build verification.** Confirm in Xcode that the new tab compiles, the
  `+` logs an expense, and the list refreshes after submit (cannot compile here —
  no Xcode in this environment).

---

## B. Remaining open items from the project handoff

- [ ] **Backend redeploy (#3).** Update `backend/Code.gs` in the app's
  spreadsheet, run `setupSpreadsheet` (adds the Planning tab), set each
  customer's mow interval, then redeploy via **Manage deployments → Edit → New
  version** (keeps the same `/exec` URL) so Planning and the Home `?action=entries`
  mirroring work.
- [ ] **Confirm the deployed `/exec` binding (#4).** Verify the deployed Web App
  is bound to the app's actual spreadsheet (the one with Lawn Log / Planning).
- [ ] **App icon (#5, optional).** Current icon is a code-generated LR-lasso
  replica; drag the exact original 1024×1024 PNG into the AppIcon well if
  preferred.
- [ ] **Remove unused SwiftData (#8, optional).** SwiftData is still wired up
  (`LawnRangersApp.swift` model container) but Home no longer reads it; could be
  removed entirely.

## Done (for reference)

- [x] Persist signing `DEVELOPMENT_TEAM` so it stops disappearing.
- [x] Reconcile local/remote `main`.
- [x] Delete redundant remote branches (`claude/...`, `experiment/load-from-sheet`).
- [x] Move Expenses into its own tab (primary implementation).
