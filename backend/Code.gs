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
 *   4. Open the "Customers" tab and fill in each customer's Standard rate + address
 *      (this is what "Standard" in the form looks up).
 *   5. Deploy → New deployment → type "Web app"
 *        • Execute as:     Me
 *        • Who has access: Anyone
 *      Copy the /exec URL it gives you.
 *   6. In the app: gear (top-left) → Settings → paste the URL → Save.
 *
 * Calculation rules (derived from the existing sheet):
 *   • Rate (H):           the number in "How much?", or the customer's Standard
 *                         rate from the Customers tab when it says "Standard".
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
var CUSTOMERS_TAB = 'Customers';   // one row per customer: Rate, Address + mow-cycle tracking (the old "Planning" tab is merged in)
var ERROR_TAB = 'Errors';               // created on demand when the app's debug error logging is on
var PLAN_TAB = 'Job Queue';             // the shared job backlog (was the "Plan" tab); created on demand

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

    if (data.type === 'lawnUpdate') {
      // Edit an existing Lawn Log row, found by matching its timestamp (epoch ms).
      var sheet = ss.getSheetByName(LAWN_TAB);
      if (!sheet) throw new Error('Tab not found: ' + LAWN_TAB + ' (run setupSpreadsheet first)');
      var lastRow = sheet.getLastRow();
      if (lastRow < FIRST_DATA_ROW) throw new Error('No lawn rows to edit.');
      var target = Number(data.ts);
      var n = lastRow - FIRST_DATA_ROW + 1;
      var stamps = sheet.getRange(FIRST_DATA_ROW, 1, n, 1).getValues();
      var row = -1;
      for (var i = 0; i < stamps.length; i++) {
        var cell = stamps[i][0];
        if (cell instanceof Date && Math.abs(cell.getTime() - target) < 1000) {
          row = FIRST_DATA_ROW + i;
          break;
        }
      }
      if (row === -1) throw new Error('Entry not found (ts ' + target + ').');
      // Update columns B–G (timestamp in A stays), then recompute H–N.
      sheet.getRange(row, 2, 1, 6).setValues([[
        data.where || '', data.who || '', data.howMuch || '',
        data.customerPaid || '', data.teammemberPaid || '', data.note || ''
      ]]);
      writeCalculatedColumns(sheet, row);
      return json({ result: 'success' });
    } else if (data.type === 'error') {
      // Debug error logging from the app — append to an "Errors" tab, created on demand.
      var errSheet = ss.getSheetByName(ERROR_TAB);
      if (!errSheet) {
        errSheet = ss.insertSheet(ERROR_TAB);
        errSheet.getRange(1, 1, 1, 4)
          .setValues([['Timestamp', 'Context', 'Message', 'Device']])
          .setFontWeight('bold').setBackground('#e6b8b8');
        errSheet.setFrozenRows(1);
      }
      errSheet.appendRow([ts, data.context || '', data.message || '', data.device || '']);
      return json({ result: 'success' });
    } else if (data.type === 'planAdd') {
      var ps = planSheet_();
      ps.appendRow([
        data.id || '',
        data.customer || '',
        data.scheduled ? new Date(data.scheduled) : new Date(),
        data.notes || '',
        data.address || '',
        new Date()
      ]);
      return json({ result: 'success' });
    } else if (data.type === 'planUpdate') {
      var ps2 = planSheet_();
      var prow = planFindRow_(ps2, data.id);
      if (prow === -1) throw new Error('Plan item not found (' + data.id + ').');
      if (data.scheduled) ps2.getRange(prow, 3).setValue(new Date(data.scheduled));
      ps2.getRange(prow, 4).setValue(data.notes || '');
      ps2.getRange(prow, 5).setValue(data.address || '');
      return json({ result: 'success' });
    } else if (data.type === 'planDelete') {
      var ps3 = planSheet_();
      var drow = planFindRow_(ps3, data.id);
      if (drow !== -1) ps3.deleteRow(drow);
      return json({ result: 'success' });
    } else if (data.type === 'customerAdd') {
      // Add a customer to the Customers tab (name, rate, address, mow interval).
      var cs = ss.getSheetByName(CUSTOMERS_TAB);
      if (!cs) throw new Error('Tab not found: ' + CUSTOMERS_TAB + ' (run setupSpreadsheet first)');
      var cname = String(data.customer || '').trim();
      if (!cname) throw new Error('Customer name is required.');
      // Scan column A: reject duplicates (case-insensitive) and find the first
      // blank row. (The tab has formula columns pre-filled down to row 300, so
      // appendRow would land BELOW them — write into the first empty A instead.)
      var lastA = cs.getLastRow();
      var cnames = lastA >= 2 ? cs.getRange(2, 1, lastA - 1, 1).getValues() : [];
      var blankRow = -1;
      for (var ci = 0; ci < cnames.length; ci++) {
        var cell = String(cnames[ci][0]).trim();
        if (cell && cell.toLowerCase() === cname.toLowerCase()) {
          throw new Error('Customer "' + cell + '" already exists.');
        }
        if (!cell && blankRow === -1) blankRow = ci + 2;
      }
      if (blankRow === -1) blankRow = lastA + 1;
      cs.getRange(blankRow, 1, 1, 4).setValues([[
        cname,
        (data.rate === 0 || data.rate) ? data.rate : '',
        data.address || '',
        data.mowEvery || 14
      ]]);
      return json({ result: 'success' });
    } else if (data.type === 'expense') {
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

// Read endpoint. ?action=planning (default) returns the Planning rows;
// ?action=entries returns the current Lawn Log + Overhead Expense rows so the
// app can mirror the sheet (reflecting adds and deletions).
function doGet(e) {
  var action = (e && e.parameter && e.parameter.action) ? e.parameter.action : 'planning';
  var out = (action === 'entries')   ? readEntries()
          : (action === 'plan')      ? readPlan()
          : (action === 'customers') ? readCustomers()
          : readPlanning();

  var payload = JSON.stringify(out);
  var cb = (e && e.parameter) ? e.parameter.callback : null;
  if (cb) {
    return ContentService.createTextOutput(cb + '(' + payload + ')')
      .setMimeType(ContentService.MimeType.JAVASCRIPT);
  }
  return ContentService.createTextOutput(payload).setMimeType(ContentService.MimeType.JSON);
}

function readPlanning() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var out = { planning: [] };
  try {
    var sh = ss.getSheetByName(CUSTOMERS_TAB);
    if (sh && sh.getLastRow() >= 2) {
      var n = sh.getLastRow() - 1;
      var rows = sh.getRange(2, 1, n, 7).getValues();   // A customer … G due in
      var tz = ss.getSpreadsheetTimeZone();
      rows.forEach(function (r) {
        if (!r[0]) return;
        var dsm = asNumber(r[5]);
        var due = asNumber(r[6]);
        out.planning.push({
          customer: str(r[0]),
          interval: asNumber(r[3]),
          lastMowed: (r[4] instanceof Date) ? Utilities.formatDate(r[4], tz, 'MMM d') : str(r[4]),
          daysSinceMowed: (dsm === null) ? null : Math.round(dsm),
          dueIn: (due === null) ? null : Math.round(due)
        });
      });
    }
  } catch (err) {
    out.error = String(err);
  }
  return out;
}

function readEntries() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var out = { lawns: [], expenses: [] };
  var tz = ss.getSpreadsheetTimeZone();
  try {
    var lawn = ss.getSheetByName(LAWN_TAB);
    if (lawn && lawn.getLastRow() >= FIRST_DATA_ROW) {
      var n = lawn.getLastRow() - FIRST_DATA_ROW + 1;
      var rows = lawn.getRange(FIRST_DATA_ROW, 1, n, 7).getValues();
      rows.forEach(function (r) {
        // Only real entries: column A is an actual date. This skips the header
        // row and any summary rows regardless of where they sit in the sheet.
        if (!(r[0] instanceof Date)) return;
        out.lawns.push({
          date: (r[0] instanceof Date) ? Utilities.formatDate(r[0], tz, 'MMM d, yyyy') : str(r[0]),
          ts: (r[0] instanceof Date) ? r[0].getTime() : 0,   // raw epoch ms so the app can sort newest→oldest itself
          where: str(r[1]),
          who: str(r[2]),
          howMuch: str(r[3]),
          customerPaid: str(r[4]),
          teammemberPaid: str(r[5]),
          note: str(r[6])
        });
      });
    }

    var ex = ss.getSheetByName(EXPENSE_TAB);
    if (ex && ex.getLastRow() >= 2) {
      var m = ex.getLastRow() - 1;
      var er = ex.getRange(2, 1, m, 4).getValues();
      er.forEach(function (r) {
        // Only real entries (column A is an actual date) — skip header/summary rows.
        if (!(r[0] instanceof Date)) return;
        out.expenses.push({
          date: (r[0] instanceof Date) ? Utilities.formatDate(r[0], tz, 'MMM d, yyyy') : str(r[0]),
          ts: (r[0] instanceof Date) ? r[0].getTime() : 0,   // raw epoch ms so the app can sort newest→oldest itself
          expenses: str(r[1]),
          amount: str(r[2]),
          comment: str(r[3])
        });
      });
    }
  } catch (err) {
    out.error = String(err);
  }
  return out;
}

// ── Per-row formulas for the calculated columns (H–N) ───────────────────────
function writeCalculatedColumns(sheet, r) {
  // H — Rate: a number from "How much?", else look up the customer's Standard rate.
  sheet.getRange(r, 8).setFormula(
    '=IF($D' + r + '="Standard", IFERROR(VLOOKUP($B' + r + ", " + CUSTOMERS_TAB + '!$A:$B, 2, FALSE), 0), ' +
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

  // --- Customers tab (one row per customer: Rate, Address + mow-cycle tracking) ---
  // A Customer | B Standard Rate | C Address | D Mow Every (days) |
  // E Last Mowed | F Days Since Mowed | G Due In (days)
  var customers = ss.getSheetByName(CUSTOMERS_TAB) || ss.insertSheet(CUSTOMERS_TAB);
  var custHeaders = ['Customer', 'Standard Rate', 'Address',
                     'Mow Every (days)', 'Last Mowed', 'Days Since Mowed', 'Due In (days)'];
  customers.getRange(1, 1, 1, custHeaders.length).setValues([custHeaders])
    .setFontWeight('bold').setBackground('#b7a7e0').setFontColor('#000000');
  customers.setFrozenRows(1);

  // Seed the customer names we know about (first run only); rates + addresses
  // are filled in by hand, default interval 14 days.
  var seed = [
    'Adam', 'Anderson', 'Beverly', 'Brian', 'Corbit', 'Eldridge', 'Harrington',
    'Helen Lee', 'Holland', 'Hunter', 'Johnson', 'King', 'Larry', 'Matthews',
    'Nancy Patton', 'Retzer', 'Schreck', 'Yatish'
  ];
  if (customers.getLastRow() < 2) {
    var rows = seed.map(function (name) { return [name, '', '', 14]; });
    customers.getRange(2, 1, rows.length, 4).setValues(rows);
  }

  // Formulas down to row LAST so newly added customers auto-calculate.
  //   E Last Mowed       = most recent Lawn Log date for this customer
  //   F Days Since Mowed = today − Last Mowed
  //   G Due In (days)    = Mow Every − Days Since Mowed
  var LAST = 300;
  var eF = [], fF = [], gF = [];
  for (var r = 2; r <= LAST; r++) {
    eF.push(["=IF($A" + r + "=\"\",\"\",IF(COUNTIF('" + LAWN_TAB + "'!$B:$B,$A" + r +
             ")=0,\"\",MAXIFS('" + LAWN_TAB + "'!$A:$A,'" + LAWN_TAB + "'!$B:$B,$A" + r + ")))"]);
    fF.push(["=IF($E" + r + "=\"\",\"\",TODAY()-INT($E" + r + "))"]);
    gF.push(["=IF($E" + r + "=\"\",\"\",$D" + r + "-$F" + r + ")"]);
  }
  customers.getRange(2, 5, LAST - 1, 1).setFormulas(eF).setNumberFormat('mmm d');
  // Force plain-number format so these day-count formulas aren't auto-formatted
  // as dates (which would make getValues() return Dates, breaking the app read).
  customers.getRange(2, 6, LAST - 1, 1).setFormulas(fF).setNumberFormat('0');
  customers.getRange(2, 7, LAST - 1, 1).setFormulas(gF).setNumberFormat('0');

  // Green → yellow → red gradient on Days Since Mowed (col F), like the old sheet.
  var grad = SpreadsheetApp.newConditionalFormatRule()
    .setGradientMinpointWithValue('#57bb8a', SpreadsheetApp.InterpolationType.NUMBER, '0')
    .setGradientMidpointWithValue('#ffd666', SpreadsheetApp.InterpolationType.NUMBER, '10')
    .setGradientMaxpointWithValue('#e67c73', SpreadsheetApp.InterpolationType.NUMBER, '21')
    .setRanges([customers.getRange('F2:F' + LAST)])
    .build();
  customers.setConditionalFormatRules([grad]);

  // Done. (Logged instead of a popup so the run never waits on a dialog.)
  Logger.log('Setup complete. Next: fill in the Customers tab (rates + addresses), then Deploy → New deployment → Web app, and paste the /exec URL into the app Settings.');
}

// ── helper ──────────────────────────────────────────────────────────────────
function json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function str(v) { return (v === null || v === undefined) ? '' : String(v); }

// ── Planning backlog (shared "Plan" tab) ────────────────────────────────────
// Columns: A id, B customer, C scheduled (date+time), D notes, E created.
function planSheet_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(PLAN_TAB);
  if (!sh) {
    sh = ss.insertSheet(PLAN_TAB);
    sh.getRange(1, 1, 1, 6)
      .setValues([['ID', 'Customer', 'Scheduled', 'Notes', 'Address', 'Created']])
      .setFontWeight('bold').setBackground('#b7a7e0');
    sh.setFrozenRows(1);
  }
  return sh;
}

function planFindRow_(sh, id) {
  if (sh.getLastRow() < 2) return -1;
  var ids = sh.getRange(2, 1, sh.getLastRow() - 1, 1).getValues();
  for (var i = 0; i < ids.length; i++) {
    if (String(ids[i][0]) === String(id)) return i + 2;
  }
  return -1;
}

// Customer directory (Customers tab): customer → Standard Rate + Address.
function readCustomers() {
  var out = { customers: [] };
  try {
    var sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(CUSTOMERS_TAB);
    if (sh && sh.getLastRow() >= 2) {
      var rows = sh.getRange(2, 1, sh.getLastRow() - 1, 3).getValues();
      rows.forEach(function (r) {
        if (!r[0]) return;
        out.customers.push({
          customer: str(r[0]),
          rate: asNumber(r[1]),
          address: str(r[2])
        });
      });
    }
  } catch (err) {
    out.error = String(err);
  }
  return out;
}

function readPlan() {
  var out = { plan: [] };
  try {
    var sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(PLAN_TAB);
    if (sh && sh.getLastRow() >= 2) {
      var rows = sh.getRange(2, 1, sh.getLastRow() - 1, 5).getValues();
      rows.forEach(function (r) {
        if (!r[0]) return;   // need an id
        out.plan.push({
          id: str(r[0]),
          customer: str(r[1]),
          scheduled: (r[2] instanceof Date) ? r[2].getTime() : 0,
          notes: str(r[3]),
          address: str(r[4])
        });
      });
    }
  } catch (err) {
    out.error = String(err);
  }
  return out;
}

/// Coerce a sheet cell to a number. Handles plain numbers, numeric strings, and
/// the case where a day-count formula (e.g. TODAY()-lastMowed) gets auto-
/// formatted as a date — in which case getValues() returns a Date that we map
/// back to its day-count (serial offset from the 1899-12-30 sheet epoch).
function asNumber(v) {
  if (typeof v === 'number') return v;
  if (v instanceof Date) {
    var epoch = new Date(1899, 11, 30);
    return Math.round((v.getTime() - epoch.getTime()) / 86400000);
  }
  if (typeof v === 'string' && v.trim() !== '' && !isNaN(Number(v))) return Number(v);
  return null;
}
