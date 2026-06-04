/**
 * Lawn Rangers — Google Sheets backend (Apps Script Web App)
 *
 * Does two jobs:
 *   1. setupSpreadsheet()  — run ONCE to build the tabs, headers, summary rows,
 *      and formulas so the sheet looks like the existing one (Total Earned /
 *      Unpaid amount on top, per-person + Overhead + Depreciation columns).
 *   2. doPost(e)           — receives entries from the iOS app and appends rows,
 *      filling in the calculated columns for each new lawn row.
 *
 * ── HOW TO SET UP ────────────────────────────────────────────────────────────
 *   1. Create a new Google Sheet (or open the one you want to use).
 *   2. Extensions → Apps Script. Delete the sample code, paste THIS file in.
 *   3. In the toolbar function dropdown choose `setupSpreadsheet`, click Run.
 *      Authorize when prompted. This builds the three tabs.
 *   4. Open the "Rates" tab and fill in each customer's Standard rate
 *      (this is what "Standard" in the form looks up).
 *   5. Deploy → New deployment → type "Web app"
 *        • Execute as:     Me
 *        • Who has access: Anyone
 *      Copy the /exec URL it gives you.
 *   6. In the app: gear (top-left) → Settings → paste the URL → Save.
 *
 * Calculation rules (derived from the existing sheet):
 *   • Rate (H):           the number in "How much?", or the customer's Standard
 *                         rate from the Rates tab when it says "Standard".
 *   • Each teammate (I–L): Rate × 0.8 ÷ (number of people in "Who?"), but only
 *                         for the people listed in that row.
 *   • Overhead (M):        Rate × 0.1
 *   • Depreciation (N):    Rate × 0.1
 *   • Total Earned (row 1): column sum.
 *   • Unpaid amount (row 2): column sum limited to rows where Customer paid? = Unpaid.
 */

// ── Tab names ───────────────────────────────────────────────────────────────
var LAWN_TAB = 'Lawn Log';
var EXPENSE_TAB = 'Overhead Expense';
var RATES_TAB = 'Rates';
var PLANNING_TAB = 'Lawns due, 2025';   // read by the app's Planning tab

// Lawn tab layout
var HEADER_ROW = 3;        // row 1 = Total Earned, row 2 = Unpaid amount, row 3 = headers
var FIRST_DATA_ROW = 4;

var TEAM = ['Grantham', 'Gresham', 'Caleb', 'Oliver']; // columns I, J, K, L

var LAWN_HEADERS = [
  'Timestamp',
  'Where?',
  'Who?',
  "How much? Enter 'Standard' or the actual rate.",
  'Customer paid?',
  'Teammember paid?',
  'Note. Include Address & Phone for new customers',
  'Rate',
  'Grantham',
  'Gresham',
  'Caleb',
  'Oliver',
  'Overhead',
  'Depreciation'
];

// ── Receiving entries from the app ──────────────────────────────────────────
function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var ts = data.timestamp ? new Date(data.timestamp) : new Date();

    if (data.type === 'expense') {
      var ex = ss.getSheetByName(EXPENSE_TAB);
      if (!ex) throw new Error('Tab not found: ' + EXPENSE_TAB + ' (run setupSpreadsheet first)');
      ex.appendRow([ts, data.expenses || '', data.amount || '', data.comment || '']);
    } else {
      var sheet = ss.getSheetByName(LAWN_TAB);
      if (!sheet) throw new Error('Tab not found: ' + LAWN_TAB + ' (run setupSpreadsheet first)');
      sheet.appendRow([
        ts,
        data.where || '',
        data.who || '',
        data.howMuch || '',
        data.customerPaid || '',
        data.teammemberPaid || '',
        data.note || ''
      ]);
      writeCalculatedColumns(sheet, sheet.getLastRow());
    }

    return json({ result: 'success' });
  } catch (err) {
    return json({ result: 'error', error: String(err) });
  }
}

// Read endpoint for the app's Planning tab: returns the rows of the
// "Lawns due, 2025" sheet (Customer, Days Since Mowed, Next date, Address,
// Notes, Interval, Loop, Price, Phone — columns A–I).
function doGet(e) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var out = { planning: [] };
  try {
    var sh = ss.getSheetByName(PLANNING_TAB);
    if (sh && sh.getLastRow() >= 2) {
      var n = sh.getLastRow() - 1;
      var rows = sh.getRange(2, 1, n, 9).getValues();
      var tz = ss.getSpreadsheetTimeZone();
      rows.forEach(function (r) {
        if (!r[0]) return;
        out.planning.push({
          customer: str(r[0]),
          daysSinceMowed: (typeof r[1] === 'number') ? Math.round(r[1]) : null,
          nextDate: (r[2] instanceof Date) ? Utilities.formatDate(r[2], tz, 'MMM d') : str(r[2]),
          address: str(r[3]),
          notes: str(r[4]),
          interval: (typeof r[5] === 'number') ? r[5] : null,
          loop: str(r[6]),
          price: (typeof r[7] === 'number') ? '$' + r[7] : str(r[7]),
          phone: str(r[8])
        });
      });
    }
  } catch (err) {
    out.error = String(err);
  }

  var payload = JSON.stringify(out);
  var cb = (e && e.parameter) ? e.parameter.callback : null;
  if (cb) {
    return ContentService.createTextOutput(cb + '(' + payload + ')')
      .setMimeType(ContentService.MimeType.JAVASCRIPT);
  }
  return ContentService.createTextOutput(payload).setMimeType(ContentService.MimeType.JSON);
}

// ── Per-row formulas for the calculated columns (H–N) ───────────────────────
function writeCalculatedColumns(sheet, r) {
  // H — Rate: a number from "How much?", else look up the customer's Standard rate.
  sheet.getRange(r, 8).setFormula(
    '=IF($D' + r + '="Standard", IFERROR(VLOOKUP($B' + r + ", " + RATES_TAB + '!$A:$B, 2, FALSE), 0), ' +
    'IFERROR(VALUE(REGEXREPLACE(TO_TEXT($D' + r + '), "[^0-9.]", "")), 0))'
  );

  // I–L — each teammate's share: Rate * 0.8 / headcount, only if listed in "Who?".
  for (var i = 0; i < TEAM.length; i++) {
    var col = 9 + i; // I=9 … L=12
    sheet.getRange(r, col).setFormula(
      '=IF(REGEXMATCH($C' + r + ', "' + TEAM[i] + '"), ' +
      '$H' + r + ' * 0.8 / COUNTA(SPLIT($C' + r + ', ",")), "")'
    );
  }

  // M — Overhead, N — Depreciation: 10% each.
  sheet.getRange(r, 13).setFormula('=$H' + r + ' * 0.1');
  sheet.getRange(r, 14).setFormula('=$H' + r + ' * 0.1');
}

// ── One-time spreadsheet builder ────────────────────────────────────────────
function setupSpreadsheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();

  // --- Lawn Log tab ---
  var lawn = ss.getSheetByName(LAWN_TAB) || ss.insertSheet(LAWN_TAB);

  // Summary rows (top of sheet).
  lawn.getRange('G1').setValue('Total Earned');
  lawn.getRange('G2').setValue('Unpaid amount');
  var cols = ['H', 'I', 'J', 'K', 'L', 'M', 'N'];
  for (var c = 0; c < cols.length; c++) {
    var L = cols[c];
    lawn.getRange(L + '1').setFormula('=SUM(' + L + FIRST_DATA_ROW + ':' + L + ')');
    lawn.getRange(L + '2').setFormula(
      '=SUMIF($E' + FIRST_DATA_ROW + ':$E, "Unpaid", ' + L + FIRST_DATA_ROW + ':' + L + ')'
    );
  }

  // Header row.
  lawn.getRange(HEADER_ROW, 1, 1, LAWN_HEADERS.length).setValues([LAWN_HEADERS]);
  lawn.getRange(HEADER_ROW, 1, 1, LAWN_HEADERS.length)
    .setFontWeight('bold')
    .setBackground('#b7a7e0')   // purple header, like the original
    .setFontColor('#000000');
  lawn.getRange('G1:G2').setFontWeight('bold');
  lawn.getRange('H1:N2').setNumberFormat('$#,##0.00');
  lawn.setFrozenRows(HEADER_ROW);

  // --- Overhead Expense tab ---
  var ex = ss.getSheetByName(EXPENSE_TAB) || ss.insertSheet(EXPENSE_TAB);
  ex.getRange(1, 1, 1, 4).setValues([['Timestamp', 'Expenses', 'Amount', 'Comment']]);
  ex.getRange(1, 1, 1, 4).setFontWeight('bold').setBackground('#b7a7e0');
  ex.setFrozenRows(1);

  // --- Rates tab (customer → Standard rate lookup) ---
  var rates = ss.getSheetByName(RATES_TAB) || ss.insertSheet(RATES_TAB);
  rates.getRange(1, 1, 1, 2).setValues([['Customer', 'Standard Rate']]);
  rates.getRange(1, 1, 1, 2).setFontWeight('bold').setBackground('#b7a7e0');
  rates.setFrozenRows(1);
  // Seed the customer names we know about; fill in the rates yourself.
  var seed = [
    'Adam', 'Anderson', 'Beverly', 'Brian', 'Corbit', 'Eldridge', 'Harrington',
    'Helen Lee', 'Holland', 'Hunter', 'Johnson', 'King', 'Larry', 'Matthews',
    'Nancy Patton', 'Retzer', 'Schreck', 'Yatish'
  ];
  if (rates.getLastRow() < 2) {
    var rows = seed.map(function (name) { return [name, '']; });
    rates.getRange(2, 1, rows.length, 2).setValues(rows);
  }

  // Done. (Logged instead of a popup so the run never waits on a dialog.)
  Logger.log('Setup complete. Next: fill in the Rates tab, then Deploy → New deployment → Web app, and paste the /exec URL into the app Settings.');
}

// ── helper ──────────────────────────────────────────────────────────────────
function json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function str(v) { return (v === null || v === undefined) ? '' : String(v); }
