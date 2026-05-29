# Lawn Rangers

A SwiftUI iOS app for the Lawn Rangers lawn-care business. The home screen has a
**+** button (top-right) that opens a dropdown with two entry types, each a copy
of an existing Google Form:

- **Log a Lawn** — copies the *Lawn Mowing Wizard - 2025 Daily Log* form.
- **Log an Expense** — copies the *Overhead Expense* form.

Entries are saved on-device (SwiftData) and, once the backend is connected, also
posted to the Google Sheet.

## Requirements

- Xcode 16+
- iOS 18.6 deployment target

Open `LawnRangers.xcodeproj` and run on a simulator or device.

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

## Connecting the Google Sheets backend (do this last)

The app is wired to post each entry to a Google Apps Script Web App, but stays
in **local-only** mode until you give it a URL.

1. Open the target Google Sheet → **Extensions → Apps Script**.
2. Paste the contents of [`backend/Code.gs`](backend/Code.gs) into `Code.gs`.
3. Set `LAWN_TAB` and `EXPENSE_TAB` to your tab names.
4. **Deploy → New deployment → Web app**, *Execute as: Me*, *Who has access: Anyone*.
5. Copy the Web app `/exec` URL.
6. In the app, tap the **gear** (top-left) → paste the URL → **Save**.

After that, every submission is appended to the sheet in the same column order
the Forms use. The computed columns (Rate, splits, Overhead, Depreciation) are
spreadsheet formulas — make sure they fill down to new rows.
