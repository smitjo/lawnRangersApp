# Lawn Rangers — Documentation

Technical reference for the Lawn Rangers iOS app and its Google Sheets backend.
For the quick overview and setup steps, see [`README.md`](README.md).

---

## 1. Overview

Lawn Rangers is a SwiftUI iOS app for a lawn-care business. It replaces two
Google Forms with native entry screens:

- **Log a Lawn** — a copy of the *Lawn Mowing Wizard - 2025 Daily Log* form.
- **Log an Expense** — a copy of the *Overhead Expense* form.

Entries are saved on-device with SwiftData and, when a backend URL is configured,
also posted to a Google Apps Script Web App that appends them to a spreadsheet.

- **Platform:** iOS 18.6+, Xcode 16+
- **UI:** SwiftUI, forced dark mode
- **Persistence:** SwiftData (local), Google Sheets (remote, optional)
- **Bundle id:** `com.lawnrangers.LawnRangers`

---

## 2. App flow

```
LawnRangersApp (@main)
  └─ RootView                 splash → tabs transition
       ├─ SplashView          lasso + grass "Lawn Rangers", ~1.8s
       └─ MainTabView         tab bar
            ├─ HomeView       "Lawns": list of entries + toolbar
            │    ├─ "+" menu ─▶ LogLawnView    (sheet)
            │    ├─ "+" menu ─▶ LogExpenseView (sheet)
            │    └─ gear     ─▶ SettingsView   (sheet)
            └─ PlanningView   "Planning": customers + days since mowed (from sheet)
```

On launch `RootView` shows `SplashView` for ~1.8 seconds, then fades to
`MainTabView`. The **Lawns** tab is `HomeView` (top-right **`+`** menu →
**Log a Lawn** / **Log an Expense**; top-left **gear** → **Settings**). The
**Planning** tab is `PlanningView`.

---

## 3. File-by-file

### App / shell
| File | Responsibility |
|---|---|
| `LawnRangers/LawnRangersApp.swift` | `@main` entry. Builds the SwiftData `ModelContainer` for `LawnLog` + `Expense`, hosts `RootView`, forces dark mode via `.preferredColorScheme(.dark)`. |
| `LawnRangers/RootView.swift` | Drives the splash → home transition with a `Task`-based delay. |
| `LawnRangers/Views/SplashView.swift` | Brand splash: a lasso motif + "Lawn Rangers" on a green gradient, with a row of grass (`GrassView`, a `Canvas`) along the bottom — the lasso taming the grass. Defines the `Color.lawnGreen` extension (`#2E7D32`). |
| `LawnRangers/MainTabView.swift` | Tab bar hosting the **Lawns** (`HomeView`) and **Planning** (`PlanningView`) tabs. |
| `LawnRangers/HomeView.swift` | Home list of recent lawns/expenses, the `+` dropdown (`Menu`), the settings gear, and sheet presentation. |
| `LawnRangers/Views/PlanningView.swift` | Planning tab: customers + days since mowed, color-coded green→red by overdue (days vs. interval), with phone/next-date. Loads from the sheet; pull-to-refresh. |
| `LawnRangers/Backend/PlanningService.swift` | `async` GET of `?action=planning` from the Web App; decodes `PlanningResponse`. |
| `LawnRangers/Models/PlanningCustomer.swift` | Decodable row from the "Lawns due, 2025" sheet. |

### Entry screens
| File | Responsibility |
|---|---|
| `LawnRangers/Views/LogLawnView.swift` | The Log a Lawn form (see §4). Validates required fields and writes a `LawnLog`. |
| `LawnRangers/Views/LogExpenseView.swift` | The Log an Expense form: Expenses, Amount, Comment. Writes an `Expense`. |
| `LawnRangers/Views/SettingsView.swift` | Lets the user paste/save the Google Sheets Web App URL; shows Connected / Local-only status. |

### Models
| File | Responsibility |
|---|---|
| `LawnRangers/Models/LawnLog.swift` | `@Model` for a lawn entry. Fields map to sheet columns A–G. Has `sheetPayload()`. |
| `LawnRangers/Models/Expense.swift` | `@Model` for an overhead expense. Has `sheetPayload()`. |

### Data / backend
| File | Responsibility |
|---|---|
| `LawnRangers/Data/CustomerDirectory.swift` | Seed list of customers for the "Where?" dropdown. |
| `LawnRangers/Backend/BackendConfig.swift` | Stores the Web App URL in `UserDefaults`; exposes `webAppURL` / `isConfigured`. |
| `LawnRangers/Backend/SheetSubmitter.swift` | Best-effort `async` POST of a `sheetPayload()` to the Web App. No-ops if not configured. |
| `backend/Code.gs` | Google Apps Script: `setupSpreadsheet()` builder + `doPost()` receiver (see §6). Not part of the Xcode target. |
| `demo/lawn-rangers-demo.html` | Single-file web mock-up of the app for tapping through in a browser (see §9). Local-only; does not post to the sheet. |

---

## 4. Log a Lawn — fields

Mirrors the Google Form exactly; the timestamp is captured automatically.

| # | Question | Type | Required | Notes |
|---|---|---|---|---|
| 1 | Where? | Dropdown | ✅ | Seed customers ∪ previously used ∪ "New customer…" (free text). |
| 2 | Who? | Checkboxes | ✅ | Grantham, Gresham, Caleb, Oliver, + Other (free text). Stored as a comma-joined list. |
| 3 | How much? Enter 'Standard' or the actual rate. | Text | ✅ | Defaults to `"Standard"`. Blank ⇒ `"Standard"`. A number is used as the literal rate. |
| 4 | Customer paid? | Radio | ✅ | `Paid` / `Unpaid`. |
| 5 | Teammember paid? | Radio | ✅ | `Paid` / `Unpaid`. |
| 6 | Note. Include Address & Phone for new customers | Text | ❌ | Optional. |

**Log an Expense:** Expenses (text, required), Amount (text, required), Comment (text, optional).

---

## 5. Data model & payloads

`LawnLog` → sheet columns A–G:

| Property | Column | JSON key (`sheetPayload`) |
|---|---|---|
| `timestamp` | A Timestamp | `timestamp` (ISO 8601) |
| `whereLocation` | B Where? | `where` |
| `who: [String]` | C Who? | `who` (joined with `", "`) |
| `howMuch` | D How much? | `howMuch` |
| `customerPaid` | E Customer paid? | `customerPaid` |
| `teammemberPaid` | F Teammember paid? | `teammemberPaid` |
| `note` | G Note | `note` |

Lawn payloads also include `"type": "lawn"`. Expense payloads use
`"type": "expense"` with keys `expenses`, `amount`, `comment`.

Submission is best-effort: the local SwiftData copy is always written first;
`SheetSubmitter.submit(_:)` then POSTs and silently returns on failure or when
no URL is configured.

---

## 6. Google Sheets backend (`backend/Code.gs`)

### `setupSpreadsheet()` — run once
Builds three tabs:

- **Lawn Log** — columns A–N. Rows 1–2 hold **Total Earned** and **Unpaid
  amount** summaries, row 3 is the header, data starts at row 4.
- **Overhead Expense** — Timestamp, Expenses, Amount, Comment.
- **Rates** — `Customer | Standard Rate` lookup, seeded with known customers
  (fill in the rates yourself).

### `doPost(e)` — receives app submissions
Routes by `type`, appends the answer columns, and for lawn rows writes the
calculated columns H–N.

### `doGet(e)` — feeds the Planning tab
Reads the **"Lawns due, 2025"** tab (columns A–I: Customer, Days Since Mowed,
Next date, Address, Notes, Interval, Loop, Price, Phone) and returns
`{ planning: [...] }` as JSON. Requires the deployed script to be bound to the
spreadsheet that contains that tab; redeploy (Manage deployments → new version)
after adding it so the same `/exec` URL serves it.

### Calculated columns (the math)
Let **Rate** be the number in "How much?", or the customer's Standard Rate from
the **Rates** tab when the value is exactly `"Standard"`.

| Column | Formula | Meaning |
|---|---|---|
| H Rate | `Rate` | Resolved rate for the job. |
| I–L (per mower) | `Rate × 0.8 ÷ headcount` | Remaining 80% split equally among the people in "Who?". |
| M Overhead | `Rate × 0.1` | 10% of revenue. |
| N Depreciation | `Rate × 0.1` | 10% of revenue. |

`headcount = COUNTA(SPLIT("Who?", ","))`. Per-mower columns exist only for the
four named teammates; an "Other" mower still counts toward the headcount but has
no dedicated column.

Summary rows: **Total Earned** = column sum; **Unpaid amount** = column sum
limited to rows where `Customer paid? = "Unpaid"`.

---

## 7. Connecting & deploying

1. Create a Google Sheet → **Extensions → Apps Script** → paste `backend/Code.gs`.
2. Run **`setupSpreadsheet`** (authorize when prompted).
3. Fill in the **Rates** tab.
4. **Deploy → New deployment → Web app** — *Execute as: Me*, *Who has access: Anyone*.
5. Copy the `/exec` URL → in the app, **gear → Settings → paste → Save**.

The app stays in local-only mode until a valid URL is saved.

### URL persistence

- **In the app:** the app ships with a **built-in default URL**
  (`BackendConfig.defaultWebAppURLString`) baked in, so every install is connected
  out of the box. A per-device **override** can be saved in Settings; it's stored
  in `UserDefaults` (the app's preferences plist) and persists across launches,
  restarts, and updates. Clearing the override reverts to the built-in default.
  To change the baked-in URL for everyone, edit `defaultWebAppURLString` and ship
  a new build.
- **In Apps Script:** keep the same `/exec` URL when updating the script by using
  **Deploy → Manage deployments → Edit (✏️) → Version: New version → Deploy**.
  Using *New deployment* instead would mint a different URL and require
  re-pasting it into the app.

---

## 8. Known follow-ups

- **App icon** — currently a placeholder green "LR". Replace `AppIcon` with the
  lasso artwork (drag the 1024×1024 PNG into the AppIcon well in Xcode).
- **Standard-rate accuracy** — verify the Rates tab values against the original
  sheet after the first live entries.
- **"Other" mower payouts** — not tracked in a dedicated column (by design);
  can be added if needed.

---

## 9. Interactive web demo

`demo/lawn-rangers-demo.html` is a standalone, single-file mock-up of the app for
quick tapping/testing — no Xcode required. It mirrors the splash, dark mode, the
`+` dropdown, both forms (including the "Standard" rate default), and the split
math, persisting entries in `localStorage`. It is **local-only** and never posts
to the Google Sheet.

Run it on a phone:

- **Instant (public repo):**
  `https://raw.githack.com/smitjo/lawnRangersApp/main/demo/lawn-rangers-demo.html`
- **GitHub Pages:** enable at *Settings → Pages → Deploy from a branch →
  `main` / root*, then open
  `https://smitjo.github.io/lawnRangersApp/demo/lawn-rangers-demo.html`

The demo seeds "Standard" rates from the original sheet for illustration; the
real app resolves them from the **Rates** tab.
