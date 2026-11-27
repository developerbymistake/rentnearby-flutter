// Fills the bundled A4 template from the app's JSON and runs the fit rules. Layout only: every value arrives as a
// final display string. Data is written with textContent only; images only from two fixed same-origin paths.
(function () {
  'use strict';

  var MAX_SINGLE_LINES = 18;
  var MAX_LEVEL = 2;
  var data = null;

  function get(path) {
    var parts = path.split('.');
    var o = data;
    for (var i = 0; i < parts.length; i++) {
      if (o === null || o === undefined) return undefined;
      o = o[parts[i]];
    }
    return o;
  }

  function empty(v) {
    return v === undefined || v === null || v === '' || v === false || (Array.isArray(v) && v.length === 0);
  }

  function each(root, sel, fn) {
    var list = root.querySelectorAll(sel);
    for (var i = 0; i < list.length; i++) fn(list[i]);
  }

  function clear(el) {
    while (el.firstChild) el.removeChild(el.firstChild);
  }

  function hideRow(el) {
    var row = el.hasAttribute('data-self') ? null : el.closest('[data-row]');
    (row || el).hidden = true;
  }

  function visible(el) {
    return el.getClientRects().length > 0;
  }

  function label(key) {
    var l = data.labels || {};
    return typeof l[key] === 'string' ? l[key] : '';
  }

  function cloneTemplate(id) {
    var t = document.getElementById(id);
    if (!t || !t.content || !t.content.firstElementChild) return null;
    return t.content.firstElementChild.cloneNode(true);
  }

  function setText(el, v) {
    el.textContent = String(v);
  }

  function fillCells(row, item) {
    each(row, '[data-c]', function (c) {
      var v = item[c.getAttribute('data-c')];
      if (empty(v)) c.textContent = '';
      else setText(c, v);
    });
  }

  function fillList(el) {
    var raw = get(el.getAttribute('data-list'));
    clear(el);
    if (typeof raw === 'string') {
      var lines = raw.split('\n');
      for (var i = 0; i < lines.length; i++) {
        var s = lines[i].trim();
        if (!s) continue;
        var li = document.createElement('li');
        li.textContent = s;
        el.appendChild(li);
      }
    }
    if (!el.firstChild) hideRow(el);
  }

  function fillRows(page) {
    each(page, 'tbody[data-lines]', function (body) {
      var filler = body.querySelector('[data-filler]');
      var lines = data.lines || [];
      for (var i = 0; i < lines.length; i++) {
        var row = cloneTemplate(body.getAttribute('data-lines'));
        if (!row) continue;
        fillCells(row, lines[i]);
        body.insertBefore(row, filler);
      }
    });
    each(page, 'tbody[data-pays]', function (body) {
      var anchor = body.querySelector('[data-pays-end]');
      var pays = data.payments || [];
      for (var i = 0; i < pays.length; i++) {
        var row = cloneTemplate(body.getAttribute('data-pays'));
        if (!row) continue;
        fillCells(row, pays[i]);
        body.insertBefore(row, anchor);
      }
    });
  }

  function fillImages(page) {
    each(page, 'img[data-img]', function (img) {
      var name = img.getAttribute('data-img');
      if ((name !== 'logo' && name !== 'signature') || data[name] !== true) {
        hideRow(img);
        return;
      }
      img.addEventListener('error', function () { hideRow(img); });
      img.src = '/img/' + name + '.jpg?v=' + encodeURIComponent(String(data.assetsVersion || 0));
    });
  }

  function contLine() {
    var g = get('guest.name');
    var proforma = data.kind === 'Proforma';
    return [
      label('continued'),
      empty(g) ? '' : label('guest') + ' ' + g,
      get('stay.range') || '',
      proforma ? (empty(data.balance) ? '' : label('balance') + ' ' + data.balance) : label('total') + ' ' + get('totals.total'),
    ].filter(function (s) { return !!s; }).join(' · ');
  }

  function fill(page) {
    each(page, '[data-kind]', function (el) {
      if (el.getAttribute('data-kind') !== data.kind) el.hidden = true;
    });
    each(page, '[data-l]', function (el) { el.textContent = label(el.getAttribute('data-l')); });
    each(page, '[data-k]', function (el) {
      var v = get(el.getAttribute('data-k'));
      if (empty(v)) hideRow(el);
      else setText(el, v);
    });
    each(page, '[data-cont]', function (el) { el.textContent = contLine(); });
    each(page, '[data-list]', fillList);
    fillRows(page);
    fillImages(page);
    each(page, '[data-any]', function (el) {
      var keys = el.getAttribute('data-any').split(',');
      var all = true;
      for (var i = 0; i < keys.length; i++) if (!empty(get(keys[i].trim()))) all = false;
      if (all) el.hidden = true;
    });
  }

  function pagesEl() {
    return document.getElementById('pages');
  }

  function setLevel(level) {
    each(pagesEl(), '.a4', function (p) {
      p.classList.toggle('fit', level === 1);
      p.classList.toggle('fit2', level === 2);
    });
  }

  function bottomOf(flow) {
    var b = flow.getBoundingClientRect().top;
    for (var i = 0; i < flow.children.length; i++) {
      var c = flow.children[i];
      if (!visible(c)) continue;
      var r = c.getBoundingClientRect();
      if (r.bottom > b) b = r.bottom;
    }
    return b;
  }

  // Content must end above the first bottom block (signature strip, footer line) of the page.
  function excess(page) {
    var top = page.getBoundingClientRect().top;
    var height = page.clientHeight;
    var floor = height - 24;
    each(page, '[data-floor]', function (f) {
      if (!visible(f) || f.closest('[data-flow]')) return;
      var t = f.getBoundingClientRect().top - top - 8;
      if (t < floor) floor = t;
    });
    var over = 0;
    each(page, '[data-flow]', function (f) {
      var limit = f.hasAttribute('data-limit-page') ? height - 20 : floor;
      over = Math.max(over, bottomOf(f) - top - limit);
      if (f.scrollWidth > f.clientWidth + 1) over = Math.max(over, f.scrollWidth - f.clientWidth);
    });
    return over;
  }

  function overflow(page) {
    return excess(page) > 0.5;
  }

  function section(page, name) {
    return page.querySelector('[data-sec="' + name + '"]');
  }

  function slot(page, name) {
    return page.querySelector('[data-slot="' + name + '"]');
  }

  function rows(body) {
    var out = [];
    for (var i = 0; i < body.children.length; i++) {
      var r = body.children[i];
      if (r.tagName === 'TR' && !r.hasAttribute('data-filler')) out.push(r);
    }
    return out;
  }

  function onePage() {
    var root = pagesEl();
    clear(root);
    var p1 = cloneTemplate('p1');
    root.appendChild(p1);
    fill(p1);
    return [p1];
  }

  // Two pages: terms, bank and signature go to page 2; then totals, then line rows move until page 1 fits.
  // The table header repeats, a row never splits, the totals block moves whole.
  function twoPages() {
    var root = pagesEl();
    clear(root);
    var p1 = cloneTemplate('p1');
    var p2 = cloneTemplate('p2');
    root.appendChild(p1);
    root.appendChild(p2);
    fill(p1);
    fill(p2);
    each(p1, '[data-filler]', function (f) { f.parentNode.removeChild(f); });
    ['rest', 'sign'].forEach(function (name) {
      var s = section(p1, name);
      var to = slot(p2, name);
      if (s && to) to.appendChild(s);
    });
    return [p1, p2];
  }

  function balance(p1, p2) {
    if (!overflow(p1)) return;
    var tot = section(p1, 'totals');
    if (tot) slot(p2, 'totals').appendChild(tot);
    if (!overflow(p1)) return;
    var table = section(p1, 'items');
    if (!table || !table.tBodies.length) return;
    var body = table.tBodies[0];
    var cont = table.cloneNode(false);
    if (table.tHead) cont.appendChild(table.tHead.cloneNode(true));
    var body2 = document.createElement('tbody');
    cont.appendChild(body2);
    slot(p2, 'items').appendChild(cont);
    var list = rows(body);
    while (overflow(p1) && list.length > 1) {
      body2.insertBefore(list.pop(), body2.firstChild);
    }
  }

  function footers(list) {
    var pattern = get('footer.pagePattern') || '';
    for (var i = 0; i < list.length; i++) {
      var p = list[i];
      p.classList.toggle('last', i === list.length - 1);
      each(p, '[data-page]', function (el) {
        el.textContent = pattern.replace('{x}', String(i + 1)).replace('{y}', String(list.length));
      });
    }
  }

  function layout(minLevel) {
    var lines = (data.lines || []).length;
    var single = 0;
    var level;
    var list;
    if (lines <= MAX_SINGLE_LINES) {
      for (level = minLevel; level <= MAX_LEVEL; level++) {
        list = onePage();
        if (level > 0) each(list[0], '[data-filler]', function (f) { f.parentNode.removeChild(f); });
        setLevel(level);
        if (!overflow(list[0])) {
          footers(list);
          return { ok: true, pages: 1, fit: level };
        }
      }
      single = Math.round(excess(list[0]));
    }
    for (level = minLevel; level <= MAX_LEVEL; level++) {
      list = twoPages();
      setLevel(level);
      balance(list[0], list[1]);
      if (!overflow(list[0]) && !overflow(list[1])) {
        footers(list);
        return { ok: true, pages: 2, fit: level, over: single };
      }
    }
    footers(list);
    return { ok: false, pages: 2, fit: MAX_LEVEL, reason: 'TooLong', over: Math.round(Math.max(excess(list[0]), excess(list[1]))) };
  }

  function decode(b64) {
    var bin = atob(b64);
    var bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return JSON.parse(new TextDecoder('utf-8').decode(bytes));
  }

  function fontsReady() {
    document.body.getBoundingClientRect();
    return document.fonts ? document.fonts.ready : Promise.resolve();
  }

  // Image boxes have fixed sizes in quote.css, so the fit never depends on them; draw and print wait for them.
  function imagesReady() {
    var waits = [];
    each(pagesEl(), 'img[src]', function (img) {
      if (!visible(img)) return;
      waits.push(img.decode ? img.decode().catch(function () { hideRow(img); }) : Promise.resolve());
    });
    return Promise.all(waits);
  }

  function done(id, result) {
    result.id = id;
    window.__quoteState = JSON.stringify(result);
  }

  window.__quote = {
    render: function (b64, minLevel, id) {
      window.__quoteState = '';
      try {
        data = decode(b64);
      } catch (e) {
        done(id, { ok: false, pages: 0, fit: 0, reason: 'RenderFailed' });
        return true;
      }
      document.title = data && typeof data.number === 'string' ? data.number.slice(0, 40) : '';
      var start = Math.max(0, Math.min(MAX_LEVEL, minLevel | 0));
      try {
        onePage();
      } catch (e) {
        done(id, { ok: false, pages: 0, fit: 0, reason: 'RenderFailed' });
        return true;
      }
      fontsReady()
        .then(function () {
          var result = layout(start);
          return imagesReady().then(function () { done(id, result); });
        })
        .catch(function () {
          done(id, { ok: false, pages: 0, fit: 0, reason: 'RenderFailed' });
        });
      return true;
    },
  };
})();
