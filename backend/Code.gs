/**
 * Lawn Rangers — Google Sheets backend (Apps Script Web App)
 *
 * Receives submissions from the Lawn Rangers iOS app and appends rows to this
 * spreadsheet, matching how the Google Forms currently feed it.
 *
 * SETUP
 *   1. Open your Google Sheet → Extensions → Apps Script.
 *   2. Replace the default Code.gs contents with this file.
 *   3. Set LAWN_TAB and EXPENSE_TAB below to the exact tab (sheet) names
 *      that each form currently writes to.
 *   4. Deploy → New deployment → select type "Web app".
 *        • Description:      Lawn Rangers app
 *        • Execute as:       Me
 *        • Who has access:   Anyone
 *   5. Authorize when prompted, then copy the "Web app" URL
 *      (looks like https://script.google.com/macros/s/XXXX/exec).
 *   6. In the iOS app, open Settings (gear, top-left) and paste that URL.
 *
 * Lawn rows are appended in column order A–G:
 *   Timestamp | Where? | Who? | How much? | Customer paid? | Teammember paid? | Note
 * The computed columns (Rate, per-person splits, Overhead, Depreciation, etc.)
 * remain spreadsheet formulas — make sure those formulas fill down to new rows
 * (e.g. use ARRAYFORMULA, or keep a buffer of pre-filled formula rows).
 */

// >>> EDIT THESE to match your tab names <<<
var LAWN_TAB = 'Form Responses 1';
var EXPENSE_TAB = 'Overhead Expense';

function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var ts = data.timestamp ? new Date(data.timestamp) : new Date();

    if (data.type === 'expense') {
      var expenseSheet = ss.getSheetByName(EXPENSE_TAB);
      if (!expenseSheet) throw new Error('Tab not found: ' + EXPENSE_TAB);
      expenseSheet.appendRow([
        ts,
        data.expenses || '',
        data.amount || '',
        data.comment || ''
      ]);
    } else {
      var lawnSheet = ss.getSheetByName(LAWN_TAB);
      if (!lawnSheet) throw new Error('Tab not found: ' + LAWN_TAB);
      lawnSheet.appendRow([
        ts,
        data.where || '',
        data.who || '',
        data.howMuch || '',
        data.customerPaid || '',
        data.teammemberPaid || '',
        data.note || ''
      ]);
    }

    return ContentService
      .createTextOutput(JSON.stringify({ result: 'success' }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ result: 'error', error: String(err) }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

/** Optional: lets you confirm the deployment is live by opening the URL in a browser. */
function doGet() {
  return ContentService
    .createTextOutput(JSON.stringify({ result: 'ok', message: 'Lawn Rangers backend is live.' }))
    .setMimeType(ContentService.MimeType.JSON);
}
