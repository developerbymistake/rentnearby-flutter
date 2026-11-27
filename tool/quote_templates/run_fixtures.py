"""Template fixture run (BUILD_PLAN 6 / 7.1 Q12): renders every bundled A4 template with headless Chrome.

Usage: python -I tool/quote_templates/run_fixtures.py [--png] [--thumbs]  (--thumbs rewrites assets/quote_templates/thumbs/*.png)
Writes build/quote_fixtures/ (site copy, result json, optional screenshots) and exits 1 on any failed rule.
The JSON shape is the one QuoteDocBuilder produces (BUILD_PLAN 4.7). Dev tool only, not part of the app.
"""
import base64
import copy
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, 'assets', 'quote_templates')
FONTS = os.path.join(ROOT, 'assets', 'fonts')
OUT = os.path.join(ROOT, 'build', 'quote_fixtures')
FIX = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fixtures')
CHROME = os.environ.get('CHROME', r'C:\Program Files\Google\Chrome\Application\chrome.exe')
TEMPLATES = ['classic', 'band', 'modern']

LABELS = {
    'quotationNo': 'Quotation no', 'invoiceNo': 'Invoice no', 'quotationRef': 'Quotation ref', 'date': 'Date', 'validTill': 'Valid till',
    'to': 'To', 'preparedFor': 'Prepared for', 'guest': 'Guest', 'phone': 'Phone', 'bookedBy': 'Booked by', 'stay': 'Stay',
    'stayDetails': 'Stay details', 'checkIn': 'Check-in', 'checkOut': 'Check-out', 'nights': 'Nights', 'guests': 'Guests',
    'mealPlan': 'Meal plan', 'srNo': 'Sr. No', 'no': '#', 'description': 'Description', 'rate': 'Rate', 'rateInr': 'Rate (\u20b9)',
    'paxQty': 'Pax / Qty', 'qty': 'Qty', 'amount': 'Amount', 'totalInr': 'Total (\u20b9)', 'amountInr': 'Amount (\u20b9)',
    'subtotal': 'Subtotal', 'lessDiscount': 'Less discount', 'taxable': 'Taxable value', 'roundOff': 'Round off',
    'totalAmount': 'Total amount', 'total': 'Total', 'amountInWords': 'Amount in words', 'paymentsReceived': 'Payments received',
    'totalReceived': 'Total received', 'balanceBill': 'Balance bill amount', 'balanceInWords': 'Balance in words', 'balance': 'Balance',
    'terms': 'Terms', 'cancellation': 'Cancellation policy', 'cancellationShort': 'Cancellation', 'bankUpi': 'Bank and UPI',
    'payTo': 'Pay to', 'acName': 'A/c name', 'acNo': 'A/c no', 'account': 'Account', 'ifsc': 'IFSC', 'upi': 'UPI', 'gstin': 'GSTIN',
    'note': 'Note', 'preparedBy': 'Prepared by', 'authorisedSignatory': 'Authorised signatory', 'continued': 'Continued from page 1',
}

TERMS = ('Check-in from 12:00 pm, check-out by 11:00 am.\nRates are per night and include the meal plan shown.\n'
         'A valid photo ID is needed for every guest at check-in.\n50% advance confirms the booking; the balance is paid at check-in.')
CANCEL = ('15 days or more before check-in: full advance refunded.\n7 to 14 days before check-in: 50% of the advance refunded.\n'
          'Less than 7 days, or no-show: no refund.')


def inr(n):
    s = str(abs(int(n)))
    if len(s) > 3:
        head, tail = s[:-3], s[-3:]
        parts = []
        while len(head) > 2:
            parts.insert(0, head[-2:])
            head = head[:-2]
        if head:
            parts.insert(0, head)
        s = ','.join(parts) + ',' + tail
    return ('-' if n < 0 else '') + s


def line(i, desc, rate, qty, nights):
    return {'no': str(i), 'no2': '%02d' % i, 'description': desc, 'detail': '%s \u00d7 %d \u00d7 %d night%s' % (inr(rate), qty, nights, '' if nights == 1 else 's'),
            'rate': inr(rate), 'qty': str(qty), 'nights': str(nights), 'amount': inr(rate * qty * nights)}


def base():
    return {
        'kind': 'Quotation', 'title': 'Quotation', 'number': 'Q-0042', 'numberLabel': 'Quotation no', 'quotationRef': '',
        'date': '12 Nov 2026', 'validTill': '19 Nov 2026', 'businessName': 'The Banyan Retreat',
        'slogan': 'Riverside stays on the edge of the forest', 'address': 'Village Dhikuli, Ramnagar\nNainital, Uttarakhand 244715',
        'phone': '+91 98370 41122', 'email': 'stay@banyanretreat.in', 'gstin': '05ABCDE1234F1Z5', 'logo': False, 'signature': False,
        'assetsVersion': 0, 'owner': '', 'preparedBy': 'Meena Bisht',
        'guest': {'name': 'Harshit & Mansi', 'phone': '+91 99100 23456', 'bookedBy': 'Rahul (agent)'},
        'stay': {'checkIn': 'Mon, 23 Nov 2026', 'checkOut': 'Wed, 25 Nov 2026', 'nights': '2 nights', 'guests': '12 adults, 2 kids \u00b7 5 rooms',
                 'rooms': '5 rooms', 'mealPlan': 'AP \u00b7 Breakfast, lunch and dinner', 'mealCode': 'AP', 'range': '23 Nov 2026 \u2013 25 Nov 2026'},
        'lines': [line(1, '5 rooms, double occupancy', 10000, 5, 2), line(2, 'Extra person', 3500, 4, 2), line(3, 'Extra breakfast', 885, 6, 1),
                  line(4, 'Bonfire package', 6000, 1, 1)],
        'totals': {'subtotal': '1,39,310', 'discount': '-5,000', 'taxable': '1,34,310', 'gstLabel': 'GST @ 5%', 'gst': '6,715.50', 'roundOff': '+0.50',
                   'total': '\u20b9 1,41,026', 'words': 'Rupees One Lakh Forty-One Thousand Twenty-Six Only'},
        'payments': [], 'received': '', 'balance': '', 'balanceWords': '', 'note': '', 'terms': TERMS, 'cancellation': CANCEL,
        'bank': {'holder': 'The Banyan Retreat', 'accountNo': '30987654521', 'ifsc': 'SBIN0001234', 'bank': 'State Bank of India, Ramnagar', 'branch': '',
                 'upi': 'banyanretreat@sbi'},
        'labels': LABELS,
        'footer': {'preparedBy': 'Prepared by The Banyan Retreat.', 'pagePattern': 'Page {x} of {y}', 'notTaxInvoice': '',
                   'forBusiness': 'For The Banyan Retreat', 'thankYou': 'Thank you for choosing The Banyan Retreat', 'kindLabel': 'Quotation'},
    }


def proforma():
    d = base()
    d.update({'kind': 'Proforma', 'title': 'Proforma invoice', 'number': 'PI-0042', 'numberLabel': 'Invoice no', 'quotationRef': 'Q-0042',
              'date': '23 Nov 2026', 'validTill': '',
              'payments': [{'label': 'Advance cash', 'date': '10 Nov 2026', 'amount': '20,000'},
                           {'label': 'Bank transfer', 'date': '14 Nov 2026', 'amount': '50,000'},
                           {'label': 'Cash', 'date': '23 Nov 2026', 'amount': '30,000'}],
              'received': '1,00,000', 'balance': '\u20b9 41,026', 'balanceWords': 'Rupees Forty-One Thousand Twenty-Six Only'})
    d['footer'].update({'notTaxInvoice': 'This is not a tax invoice.', 'kindLabel': 'Proforma invoice'})
    return d


def with_lines(n, long_terms=False):
    d = base()
    names = ['Room, double occupancy', 'Extra person', 'Breakfast', 'Dinner', 'Bonfire package', 'Deluxe room, triple occupancy']
    d['lines'] = [line(i + 1, names[i % len(names)], 2500 + i * 10, 1 + i % 3, 2) for i in range(n)]
    if long_terms:
        d['terms'] = '\n'.join('Term %d: guests must follow the house rules and quiet hours after 10 pm at the property.' % i for i in range(1, 15))
        d['cancellation'] = '\n'.join('Rule %d: cancellation charges apply as per the days left before check-in.' % i for i in range(1, 9))
    return d


def hostile():
    d = base()
    d['guest']['name'] = '<script>alert(1)</script><img src=x onerror=alert(2)>"</style>Ali\u202efdp.exe'
    d['note'] = '<img src="https://evil.example/x.png"> \u202e reversed'
    d['lines'] = [line(i + 1, ('\u0915\u092e\u0930\u093e \U0001F600 ' * 8)[:80], 1000, 1, 1) for i in range(30)]
    return d


# name -> (doc, expected pages; 0 = any page count, TooLong allowed, only the safety rules are checked)
FIXTURES = {
    'sample_quotation': (base(), 1),
    'sample_proforma': (proforma(), 1),
    'lines_1': (with_lines(1), 1),
    'lines_18': (with_lines(18), 1),
    'lines_19': (with_lines(19), 2),
    'lines_30': (with_lines(30), 2),
    'lines_30_long_terms': (with_lines(30, True), 2),
    'hostile': (hostile(), 0),
}

RUNNER_JS = r"""
(function () {
  var b64 = document.currentScript.getAttribute('data-b64');
  function go() {
    window.__quote.render(b64, 0, 1);
    var t = setInterval(function () {
      if (!window.__quoteState) return;
      clearInterval(t);
      var s = JSON.parse(window.__quoteState);
      var pages = document.querySelectorAll('#pages .a4');
      var bodyMin = 99;
      document.querySelectorAll('#pages td, #pages li, #pages p').forEach(function (e) {
        if (!e.getClientRects().length || !e.textContent.trim()) return;
        var f = parseFloat(getComputedStyle(e).fontSize);
        if (f < bodyMin) bodyMin = f;
      });
      s.minBodyPx = bodyMin;
      s.domPages = pages.length;
      s.debug = Array.prototype.map.call(pages, function (pg) {
        var top = pg.getBoundingClientRect().top, floor = pg.clientHeight - 24;
        pg.querySelectorAll('[data-floor]').forEach(function (f) { if (!f.getClientRects().length || f.closest('[data-flow]')) return; var t = f.getBoundingClientRect().top - top - 8; if (t < floor) floor = t; });
        return Array.prototype.map.call(pg.querySelectorAll('[data-flow]'), function (f) {
          var b = 0; for (var i = 0; i < f.children.length; i++) { var c = f.children[i]; if (c.getClientRects().length) b = Math.max(b, c.getBoundingClientRect().bottom - top); }
          return Math.round(b) + '/' + Math.round(f.hasAttribute('data-limit-page') ? pg.clientHeight - 20 : floor);
        }).join(' ');
      });
      s.scripts = document.querySelectorAll('#pages script').length;
      s.imgs = Array.prototype.map.call(document.querySelectorAll('#pages img[src]'), function (i) { return i.getAttribute('src'); });
      document.title = 'RESULT:' + JSON.stringify(s);
    }, 20);
  }
  if (document.readyState === 'complete') go(); else window.addEventListener('load', go);
})();
"""


def build_site():
    site = os.path.join(OUT, 'site')
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(os.path.join(site, 'fonts'))
    for f in os.listdir(SRC):
        p = os.path.join(SRC, f)
        if os.path.isfile(p):
            shutil.copy(p, site)
    for f in os.listdir(FONTS):
        if f.endswith('.ttf'):
            shutil.copy(os.path.join(FONTS, f), os.path.join(site, 'fonts'))
    with open(os.path.join(site, 'runner.js'), 'w', encoding='utf-8') as fh:
        fh.write(RUNNER_JS)
    return site


def page_for(site, template, name, doc):
    html = open(os.path.join(site, template + '.html'), encoding='utf-8').read()
    html = re.sub(r'<meta http-equiv="Content-Security-Policy"[^>]*>', '', html)
    b64 = base64.b64encode(json.dumps(doc, ensure_ascii=False).encode('utf-8')).decode('ascii')
    html = html.replace('</body>', '<script src="runner.js" data-b64="%s"></script>\n</body>' % b64)
    path = os.path.join(site, '%s__%s.html' % (template, name))
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(html)
    return path


def run(path, png):
    url = 'file:///' + path.replace('\\', '/')
    args = [CHROME, '--headless=new', '--disable-gpu', '--allow-file-access-from-files', '--hide-scrollbars', '--virtual-time-budget=8000',
            '--window-size=794,2244', '--dump-dom', url]
    out = subprocess.run(args, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=120).stdout
    m = re.search(r'<title>RESULT:(.*?)</title>', out, re.S)
    if png:
        subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--allow-file-access-from-files', '--hide-scrollbars', '--virtual-time-budget=8000',
                        '--window-size=794,2244', '--screenshot=' + path[:-5] + '.png', url], capture_output=True, timeout=120)
    if not m:
        return None
    return json.loads(m.group(1).replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>').replace('&quot;', '"'))


def main():
    png = '--png' in sys.argv
    os.makedirs(FIX, exist_ok=True)
    site = build_site()
    failures = []
    report = {}
    for name, (doc, expect) in FIXTURES.items():
        with open(os.path.join(FIX, name + '.json'), 'w', encoding='utf-8') as fh:
            json.dump(doc, fh, ensure_ascii=False, indent=1)
        for t in TEMPLATES:
            r = run(page_for(site, t, name, copy.deepcopy(doc)), png)
            key = '%s/%s' % (t, name)
            report[key] = r
            if r is None:
                failures.append('%s: no result' % key)
                continue
            if expect == 0:
                if not r.get('ok') and r.get('reason') != 'TooLong':
                    failures.append('%s: failed with %s' % (key, r.get('reason')))
            elif not r.get('ok'):
                failures.append('%s: not ok (%s)' % (key, r.get('reason')))
            if expect and (r.get('pages') != expect or r.get('domPages') != expect):
                failures.append('%s: pages %s, expected %s' % (key, r.get('pages'), expect))
            if r.get('minBodyPx', 99) < 10.6:
                failures.append('%s: body text %.2f px is under 8 pt' % (key, r['minBodyPx']))
            if r.get('scripts'):
                failures.append('%s: script element inside the document' % key)
            bad = [s for s in r.get('imgs', []) if not s.startswith('/img/')]
            if bad:
                failures.append('%s: image outside the whitelist %s' % (key, bad))
    if '--thumbs' in sys.argv:
        thumbs = os.path.join(SRC, 'thumbs')
        os.makedirs(thumbs, exist_ok=True)
        for t in TEMPLATES:
            url = 'file:///' + os.path.join(site, '%s__sample_quotation.html' % t).replace(os.sep, '/')
            subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--allow-file-access-from-files', '--hide-scrollbars', '--virtual-time-budget=8000',
                            '--window-size=794,1122', '--force-device-scale-factor=%.4f' % (360 / 794.0), '--screenshot=' + os.path.join(thumbs, t + '.png'), url],
                           capture_output=True, timeout=120)
    with open(os.path.join(OUT, 'result.json'), 'w', encoding='utf-8') as fh:
        json.dump({'report': report, 'failures': failures}, fh, ensure_ascii=False, indent=1)
    for k, v in report.items():
        print(k, v and {x: v.get(x) for x in ('ok', 'pages', 'fit', 'minBodyPx', 'debug')})
    if failures:
        print('FAILED')
        for f in failures:
            print(' -', f)
        sys.exit(1)
    print('ALL PASS')


if __name__ == '__main__':
    main()
