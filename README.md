# Lawn Rangers

A SwiftUI iOS app for the Lawn Rangers lawn-care business. The home screen has a
**+** button (top-right) that opens a dropdown with two entry types, each a copy
of an existing Google Form:

- **Log a Lawn** — copies the *Lawn Mowing Wizard - 2025 Daily Log* form.
- **Log an Expense** — copies the *Overhead Expense* form.

Entries are saved on-device (SwiftData) and posted to the Google Sheet through a
built-in backend URL baked into the app.

## Requirements

- Xcode 16+
- iOS 18.6 deployment target

Open `LawnRangers.xcodeproj` and run on a simulator or device.

## Try the interactive demo (no Xcode needed)

`demo/lawn-rangers-demo.html` is a single-file web mock-up of the app — green
splash, dark mode, the `+` dropdown, both forms (with the "Standard" rate
default), and the live split math. It saves entries in the browser only and does
**not** post to the Google Sheet, so it's safe to tap around.

Run it on a phone via either:

- **Instant (public repo):**
  `https://raw.githack.com/smitjo/lawnRangersApp/main/demo/lawn-rangers-demo.html`
- **GitHub Pages (permanent link):** enable Pages at
  *Settings → Pages → Deploy from a branch → `main` / root → Save*, then open
  `https://smitjo.github.io/lawnRangersApp/demo/lawn-rangers-demo.html`

On iOS, **Share → Add to Home Screen** gives it a full-screen, app-like feel.

## Forms

**Log a Lawn** (writes sheet columns A–G; timestamp is automatic):
1. Where? — dropdown (customers + "New customer…") — required
2. Who? — checkboxes: Grantham, Gresham, Caleb, Oliver, Other — required
3. How much? Enter 'Standard' or the actual rate. — text — required
4. Customer paid? — Paid / Unpaid — required
5. Teammember paid? — Paid / Unpaid — required
6. Note. Include Address & Phone for new customers — text — optional

**Log an Expense**:
1. Expenses — text — required
2. Amount — text — required
3. Comment — text — optional

The "Where?" dropdown is seeded from `LawnRangers/Data/CustomerDirectory.swift`
and also grows automatically with any customer you enter in the app.

## Google Sheets backend

The app already ships connected: the deployed Apps Script Web App `/exec` URL is
baked into `BackendConfig.defaultWebAppURLString`, so every install posts to the
sheet out of the box. The steps below are only needed to (re)create the sheet or
point the app at a different backend.

1. Create (or open) the Google Sheet you want to use.
2. **Extensions → Apps Script**; delete the sample, paste in [`backend/Code.gs`](backend/Code.gs).
3. In the function dropdown pick **`setupSpreadsheet`** and click **Run** (authorize
   when asked). This builds three tabs:
   - **Lawn Log** — Timestamp, Where?, Who?, How much?, Customer paid?,
     Teammember paid?, Note, then the calculated columns Rate, Grantham, Gresham,
     Caleb, Oliver, Overhead, Depreciation, with **Total Earned** / **Unpaid
     amount** summary rows on top (like the original sheet).
   - **Overhead Expense** — Timestamp, Expenses, Amount, Comment.
   - **Rates** — Customer → Standard Rate lookup (seeded with customer names).
4. Open the **Rates** tab and fill in each customer's standard rate. This is what
   the form's "Standard" value looks up.
5. **Deploy → New deployment → Web app**, *Execute as: Me*, *Who has access: Anyone*.
6. Copy the Web app `/exec` URL.
7. To make it the default for everyone, paste it into
   `BackendConfig.defaultWebAppURLString` and ship a new build. To point just
   *this* device at it, tap the **gear** (top-left) → paste the URL → **Save**;
   that override is stored in `UserDefaults` and clearing it reverts to the
   built-in default.

After that, every submission is appended to the right tab. For lawn rows the
script fills in the calculated columns automatically using:
Rate × 0.8 ÷ headcount per teammate, Rate × 0.1 overhead, Rate × 0.1 depreciation.

### Keeping the deployment URL stable

The `/exec` URL must stay the same so the app keeps working. When you edit
`Code.gs` later, **do not** use *New deployment* (that mints a new URL).
Instead update the existing one:

1. Apps Script → **Deploy → Manage deployments**.
2. Select your Web app deployment → click the ✏️ (Edit).
3. Set **Version → New version** → **Deploy**.

This publishes your changes under the **same** `/exec` URL, so the app never
needs to be reconfigured.

## Appearance

The app runs in **dark mode** (forced via `.preferredColorScheme(.dark)` in
`LawnRangersApp.swift`). The splash is the brand green with a lasso motif over
the "Lawn Rangers" wordmark and a row of grass along the bottom — the lasso
reining in the unruly grass, left nicely trimmed by The Lawn Rangers. The grass
is drawn in `GrassView` (a SwiftUI `Canvas`) in `SplashView.swift`.

**App icon:** the repo currently has a placeholder green "LR" icon. The final
lasso icon ("LR" inside a lasso on green) should be dropped into
`Assets.xcassets/AppIcon` (drag the 1024×1024 PNG into the AppIcon well in
Xcode).
