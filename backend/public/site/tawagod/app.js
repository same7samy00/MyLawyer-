// Where I'll be: lawyers say which courts they'll be at, and anyone finds them and calls.
(function () {
  'use strict';

  const API = '/api/v1/presence';
  const TOKEN_KEY = 'tawagod.token';
  const ACCOUNT_KEY = 'tawagod.account';
  const view = document.getElementById('view');
  const barActions = document.getElementById('barActions');

  const CITIES = [
    'القاهرة', 'الجيزة', 'الإسكندرية', 'الزقازيق', 'المنصورة', 'طنطا', 'شبين الكوم', 'بنها', 'دمنهور',
    'كفر الشيخ', 'دمياط', 'بورسعيد', 'الإسماعيلية', 'السويس', 'الفيوم', 'بني سويف', 'المنيا', 'أسيوط',
    'سوهاج', 'قنا', 'الأقصر', 'أسوان', 'الغردقة', 'مرسى مطروح', 'العريش', 'الطور', 'الخارجة',
    'شبرا الخيمة', '6 أكتوبر', 'العاشر من رمضان', 'المحلة الكبرى', 'القليوبية', 'الشرقية', 'الدقهلية',
    'الغربية', 'المنوفية', 'البحيرة',
  ];

  const icons = {
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>',
    phone: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8 9.9a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2z"/></svg>',
    whatsapp: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 0 0-8.6 15.1L2 22l5-1.3A10 10 0 1 0 12 2zm0 18.2a8.2 8.2 0 0 1-4.2-1.2l-.3-.2-3 .8.8-2.9-.2-.3A8.2 8.2 0 1 1 12 20.2zm4.5-6.1c-.2-.1-1.5-.7-1.7-.8-.2-.1-.4-.1-.6.1l-.8 1c-.1.2-.3.2-.5.1a6.7 6.7 0 0 1-3.3-2.9c-.3-.4.2-.4.7-1.4.1-.2 0-.3 0-.4l-.8-1.8c-.2-.5-.4-.4-.6-.4h-.5a1 1 0 0 0-.7.3 3 3 0 0 0-.9 2.2c0 1.3 1 2.6 1.1 2.8.1.2 1.9 2.9 4.6 4 1.7.7 2.4.8 3.2.7.5-.1 1.5-.6 1.8-1.2.2-.6.2-1.1.1-1.2l-.5-.3z"/></svg>',
    pin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/></svg>',
    clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></svg>',
    court: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"><path d="M3 10h18L12 4 3 10zM5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 21h18M4 18h16"/></svg>',
    share: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="m8.6 13.5 6.8 4M15.4 6.5l-6.8 4"/></svg>',
    x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" width="12" height="12"><path d="M6 6l12 12M18 6 6 18"/></svg>',
  };

  // ---------- Helpers ----------

  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  // Same rules as the server: أ إ آ ٱ = ا، ؤ = و، ئ ى = ي، ة = ه، no hamza, tashkeel or tatweel
  const FROM = 'أإآٱؤئىة٠١٢٣٤٥٦٧٨٩';
  const TO = 'ااااوييه0123456789';
  const DROP = /[ءـً-ْٰ]/;
  function normalizeChar(ch) {
    const lower = ch.toLowerCase();
    if (DROP.test(lower)) return '';
    const at = FROM.indexOf(lower);
    return at < 0 ? lower : TO[at];
  }
  function searchWords(q) {
    return [...q].map(normalizeChar).join('')
      .split(/[\s,،.\-/]+/)
      .map((w) => (w.length > 3 && w.startsWith('ال') ? w.slice(2) : w))
      .filter(Boolean);
  }

  /// Marks the searched words inside the original text, whatever spelling was used
  function highlight(text, words) {
    const source = String(text ?? '');
    if (!words.length) return esc(source);
    let norm = '';
    const map = [];
    [...source].forEach((ch, i) => {
      const n = normalizeChar(ch);
      for (const c of n) { norm += c; map.push(i); }
    });
    const chars = [...source];
    const marked = new Array(chars.length).fill(false);
    for (const w of words) {
      let from = 0;
      while (w && (from = norm.indexOf(w, from)) !== -1) {
        for (let k = from; k < from + w.length; k++) marked[map[k]] = true;
        from += w.length;
      }
    }
    // A mark inside a word would split its joined Arabic letters, so the whole word is marked
    for (let i = 0; i < chars.length; i++) {
      if (!marked[i] || /\s/.test(chars[i])) continue;
      let s = i, e = i;
      while (s > 0 && !/\s/.test(chars[s - 1])) s--;
      while (e < chars.length - 1 && !/\s/.test(chars[e + 1])) e++;
      for (let k = s; k <= e; k++) marked[k] = true;
      i = e;
    }
    let out = '';
    let open = false;
    chars.forEach((ch, i) => {
      if (marked[i] && !open) { out += '<mark>'; open = true; }
      if (!marked[i] && open) { out += '</mark>'; open = false; }
      out += esc(ch);
    });
    return open ? out + '</mark>' : out;
  }

  const latin = (s) => String(s).replace(/[٠-٩]/g, (d) => d.charCodeAt(0) - 0x0660).replace(/[۰-۹]/g, (d) => d.charCodeAt(0) - 0x06f0).replace(/[\s-]/g, '');

  function cairoDate(offset = 0) {
    const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
    const d = new Date(today + 'T12:00:00Z');
    d.setUTCDate(d.getUTCDate() + offset);
    return d.toISOString().slice(0, 10);
  }

  function dayLabel(day) {
    if (day === cairoDate(0)) return 'النهارده';
    if (day === cairoDate(1)) return 'بكره';
    if (day === cairoDate(2)) return 'بعد بكره';
    return new Intl.DateTimeFormat('ar-EG', { weekday: 'long', timeZone: 'UTC' }).format(new Date(day + 'T12:00:00Z'));
  }
  const dayDate = (day) => new Intl.DateTimeFormat('ar-EG-u-nu-latn', { weekday: 'long', day: 'numeric', month: 'long', timeZone: 'UTC' }).format(new Date(day + 'T12:00:00Z'));

  function time12(t) {
    if (!t) return '';
    const [h, m] = t.split(':').map(Number);
    const period = h < 12 ? 'ص' : 'م';
    const hour = h % 12 === 0 ? 12 : h % 12;
    return `${hour}:${String(m).padStart(2, '0')} ${period}`;
  }
  function timeRange(e) {
    if (e.timeFrom && e.timeTo) return `من ${time12(e.timeFrom)} لـ ${time12(e.timeTo)}`;
    if (e.timeFrom) return `من ${time12(e.timeFrom)}`;
    if (e.timeTo) return `لحد ${time12(e.timeTo)}`;
    return '';
  }

  const waNumber = (n) => '2' + latin(n);
  const firstLetter = (name) => ([...String(name).replace(/^(أ\.|ا\.|الأستاذ|الاستاذ|أستاذ|استاذ)\s*/, '').trim()][0] || '؟');

  let toastTimer;
  function toast(message) {
    const el = document.getElementById('toast');
    el.textContent = message;
    el.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove('show'), 2600);
  }

  const loading = () => '<div class="loading" aria-label="جاري التحميل"><i></i><i></i><i></i></div>';

  // ---------- Session and requests ----------

  const session = {
    get token() { return localStorage.getItem(TOKEN_KEY); },
    get account() { try { return JSON.parse(localStorage.getItem(ACCOUNT_KEY) || 'null'); } catch { return null; } },
    save(token, account) { localStorage.setItem(TOKEN_KEY, token); localStorage.setItem(ACCOUNT_KEY, JSON.stringify(account)); },
    clear() { localStorage.removeItem(TOKEN_KEY); localStorage.removeItem(ACCOUNT_KEY); },
  };

  async function api(method, path, body) {
    const headers = {};
    if (body) headers['Content-Type'] = 'application/json';
    if (session.token) headers.Authorization = 'Bearer ' + session.token;
    let res;
    try {
      res = await fetch(API + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
    } catch {
      throw new Error('مفيش اتصال بالإنترنت، جرب تاني');
    }
    const data = await res.json().catch(() => ({}));
    if (res.status === 401 && session.token && path !== '/login') {
      session.clear();
      renderBar();
    }
    if (!res.ok || data.success === false) throw Object.assign(new Error(data.error || 'حصلت مشكلة، جرب تاني'), { status: res.status });
    return data.data;
  }

  // ---------- Top bar ----------

  function renderBar() {
    const route = location.hash.replace(/^#/, '') || '/';
    if (session.token) {
      barActions.innerHTML = `
        ${route === '/add' ? '' : `<a class="btn sm" href="#/add">${icons.plus}<span class="label">أضف تواجدك</span></a>`}
        <a class="btn sm outline" href="#/mine" aria-label="تواجدي">${icons.user}<span class="label">تواجدي</span></a>`;
    } else {
      barActions.innerHTML = route === '/login' ? '' : `<a class="btn sm" href="#/login">${icons.plus}<span class="label">أضف تواجدك</span></a>`;
    }
  }

  // ---------- The public list ----------

  const state = { q: '', city: '', day: '', suggestions: null };
  let listRequest = 0;
  let searchTimer;

  function entryCard(e, words, mine) {
    const time = timeRange(e);
    const message = `السلام عليكم أ. ${e.name}، شفت على «أماكن التواجد» إنك متواجد ${dayLabel(e.day)} في ${e.places.join(' و')} (${e.city}).`;
    const actions = mine
      ? `<button class="btn sm outline" data-share="${esc(e.id)}">${icons.share}شارك</button>
         <button class="btn sm red" data-delete="${esc(e.id)}">امسح</button>`
      : `<a class="btn sm green" href="https://wa.me/${waNumber(e.whatsapp)}?text=${encodeURIComponent(message)}" target="_blank" rel="noopener">${icons.whatsapp}واتساب</a>
         <a class="btn sm outline" href="tel:${esc(latin(e.phone))}">${icons.phone}اتصال</a>`;
    return `
      <article class="card">
        <div class="card-top">
          <div class="avatar" aria-hidden="true">${esc(firstLetter(e.name))}</div>
          <div class="who">
            <b>${highlight(e.name, words)}</b>
            <div class="meta">
              <span>${icons.pin}${highlight(e.city, words)}</span>
              ${time ? `<span>${icons.clock}${esc(time)}</span>` : ''}
              ${mine ? `<span>${esc(dayDate(e.day))}</span>` : ''}
            </div>
          </div>
        </div>
        <div class="places">${e.places.map((p) => `<span class="place">${highlight(p, words)}</span>`).join('')}</div>
        ${e.note ? `<p class="note">${highlight(e.note, words)}</p>` : ''}
        <div class="card-actions">${actions}</div>
      </article>`;
  }

  function groupByDay(entries, words, mine) {
    const groups = new Map();
    for (const e of entries) {
      if (!groups.has(e.day)) groups.set(e.day, []);
      groups.get(e.day).push(e);
    }
    return [...groups].map(([day, list]) => `
      <h2 class="day-head">${esc(dayLabel(day))} <small>${esc(dayDate(day))} · ${list.length}</small></h2>
      <div class="grid">${list.map((e) => entryCard(e, words, mine)).join('')}</div>`).join('');
  }

  async function renderList() {
    const dayChips = [['', 'كل الأيام'], [cairoDate(0), 'النهارده'], [cairoDate(1), 'بكره'], [cairoDate(2), 'بعد بكره']];
    view.innerHTML = `
      <div class="search-box">
        <div class="search-row">
          <div class="field-icon">
            ${icons.search}
            <input class="input" id="q" type="search" placeholder="دوّر باسم المحكمة أو المدينة أو المحامي" value="${esc(state.q)}" autocomplete="off" enterkeyhint="search">
          </div>
          <select class="input" id="city" aria-label="المدينة"><option value="">كل المدن</option></select>
        </div>
        <div class="chips" id="days">
          ${dayChips.map(([d, l]) => `<button class="chip ${state.day === d ? 'on' : ''}" data-day="${d}">${l}</button>`).join('')}
        </div>
        <p class="count" id="count"></p>
      </div>
      <div id="results">${loading()}</div>`;

    const q = document.getElementById('q');
    q.addEventListener('input', () => {
      state.q = q.value;
      clearTimeout(searchTimer);
      searchTimer = setTimeout(loadResults, 250);
    });
    document.getElementById('city').addEventListener('change', (ev) => { state.city = ev.target.value; loadResults(); });
    document.getElementById('days').addEventListener('click', (ev) => {
      const chip = ev.target.closest('[data-day]');
      if (!chip) return;
      state.day = chip.dataset.day;
      document.querySelectorAll('#days .chip').forEach((c) => c.classList.toggle('on', c === chip));
      loadResults();
    });
    fillCities();
    loadResults();
  }

  async function fillCities() {
    try {
      const entries = await api('GET', '/entries');
      const select = document.getElementById('city');
      if (!select) return;
      const cities = [...new Set(entries.map((e) => e.city))].sort((a, b) => a.localeCompare(b, 'ar'));
      select.innerHTML = '<option value="">كل المدن</option>' + cities.map((c) => `<option ${c === state.city ? 'selected' : ''}>${esc(c)}</option>`).join('');
    } catch { /* the list still works without the city filter */ }
  }

  async function loadResults() {
    const id = ++listRequest;
    const results = document.getElementById('results');
    const count = document.getElementById('count');
    if (!results) return;
    const params = new URLSearchParams();
    if (state.q.trim()) params.set('q', state.q.trim());
    if (state.city) params.set('city', state.city);
    if (state.day) params.set('day', state.day);
    try {
      const entries = await api('GET', '/entries' + (params.toString() ? '?' + params : ''));
      if (id !== listRequest) return;
      const words = searchWords(state.q);
      count.textContent = entries.length ? `${entries.length} تواجد` : '';
      results.innerHTML = entries.length ? groupByDay(entries, words, false) : emptyList();
    } catch (err) {
      if (id !== listRequest) return;
      results.innerHTML = `<div class="empty"><b>مقدرناش نجيب التواجد</b>${esc(err.message)}<br><button class="btn outline" id="retry">جرب تاني</button></div>`;
      document.getElementById('retry').onclick = loadResults;
    }
  }

  function emptyList() {
    const filtered = state.q.trim() || state.city || state.day;
    return `<div class="empty">${icons.court}
      <b>${filtered ? 'مفيش حد متواجد بالبحث ده' : 'لسه محدش ضاف تواجده'}</b>
      ${filtered ? 'جرب كلمة تانية أو يوم تاني' : 'كن أول واحد يضيف المحاكم اللي هيكون فيها'}<br>
      <a class="btn" href="${session.token ? '#/add' : '#/login'}">${icons.plus}أضف تواجدك</a></div>`;
  }

  // ---------- Sign in and sign up ----------

  function renderLogin(mode = 'login') {
    if (session.token) { location.hash = '#/add'; return; }
    view.innerHTML = `
      <section class="panel">
        <h1>${mode === 'login' ? 'أهلاً بيك' : 'حساب جديد'}</h1>
        <p class="lead">${mode === 'login' ? 'سجل دخولك عشان تضيف أماكن تواجدك.' : 'رقمك والواتساب هيظهروا للي بيدوّر عليك عشان يكلمك.'}</p>
        <div class="tabs" role="tablist">
          <button class="${mode === 'login' ? 'on' : ''}" data-mode="login" role="tab">تسجيل دخول</button>
          <button class="${mode === 'register' ? 'on' : ''}" data-mode="register" role="tab">حساب جديد</button>
        </div>
        <form class="form" id="authForm" novalidate>
          ${mode === 'register' ? `
          <label><span>الاسم</span><input class="input" name="fullName" autocomplete="name" placeholder="مثال: أ. محمد أحمد" required></label>` : ''}
          <label><span>رقم الهاتف</span><input class="input" name="phone" type="tel" inputmode="numeric" autocomplete="tel" placeholder="01xxxxxxxxx" maxlength="14" required></label>
          ${mode === 'register' ? `
          <label><span>رقم الواتساب <small>(لو نفس الرقم سيبه زي ما هو)</small></span><input class="input" name="whatsapp" type="tel" inputmode="numeric" placeholder="01xxxxxxxxx" maxlength="14" required></label>` : ''}
          <label><span>كلمة السر</span><input class="input" name="password" type="password" autocomplete="${mode === 'login' ? 'current-password' : 'new-password'}" placeholder="${mode === 'login' ? '' : '6 حروف أو أرقام على الأقل'}" required></label>
          <div class="error" id="authError" hidden></div>
          <button class="btn block" type="submit">${mode === 'login' ? 'دخول' : 'إنشاء الحساب'}</button>
        </form>
      </section>`;

    view.querySelectorAll('[data-mode]').forEach((b) => b.addEventListener('click', () => renderLogin(b.dataset.mode)));
    const form = document.getElementById('authForm');
    if (mode === 'register') {
      // WhatsApp follows the phone until it is typed by hand
      const phone = form.phone, wa = form.whatsapp;
      let waTouched = false;
      wa.addEventListener('input', () => { waTouched = true; });
      phone.addEventListener('input', () => { if (!waTouched) wa.value = phone.value; });
    }
    form.addEventListener('submit', async (ev) => {
      ev.preventDefault();
      const error = document.getElementById('authError');
      const button = form.querySelector('button[type="submit"]');
      error.hidden = true;
      button.disabled = true;
      const body = Object.fromEntries(new FormData(form));
      try {
        const data = await api('POST', mode === 'login' ? '/login' : '/register', body);
        session.save(data.token, data.account);
        toast(mode === 'login' ? 'أهلاً ' + data.account.fullName : 'اتعمل حسابك');
        location.hash = '#/add';
      } catch (err) {
        error.textContent = err.message;
        error.hidden = false;
        if (err.status === 409) setTimeout(() => renderLogin('login'), 1400);
      } finally {
        button.disabled = false;
      }
    });
  }

  // ---------- Add where I'll be ----------

  async function suggestions() {
    if (!state.suggestions) {
      try { state.suggestions = await api('GET', '/suggestions'); } catch { state.suggestions = []; }
    }
    return state.suggestions;
  }

  function renderAdd() {
    if (!session.token) { location.hash = '#/login'; return; }
    const places = [];
    const quick = [[cairoDate(0), 'النهارده'], [cairoDate(1), 'بكره'], [cairoDate(2), 'بعد بكره']];
    view.innerHTML = `
      <section class="panel">
        <h1>أضف تواجدك</h1>
        <p class="lead">اختار اليوم والمدينة، وضيف كل المحاكم أو الأماكن اللي هتكون فيها.</p>
        <form class="form" id="addForm" novalidate>
          <label><span>اليوم</span>
            <div class="chips" id="quickDays" style="padding-top:0">
              ${quick.map(([d, l], i) => `<button type="button" class="chip ${i === 1 ? 'on' : ''}" data-day="${d}">${l}</button>`).join('')}
            </div>
            <input class="input" name="day" type="date" value="${cairoDate(1)}" min="${cairoDate(0)}" max="${cairoDate(60)}" required>
          </label>
          <label><span>المدينة</span>
            <input class="input" name="city" list="cityList" placeholder="مثال: الزقازيق" autocomplete="off" required>
            <datalist id="cityList"></datalist>
          </label>
          <label><span>المحكمة أو المكان</span>
            <div class="add-place">
              <input class="input" id="placeInput" list="placeList" placeholder="مثال: محكمة الزقازيق الابتدائية" autocomplete="off" enterkeyhint="done">
              <datalist id="placeList"></datalist>
              <button type="button" class="btn outline" id="addPlace">${icons.plus}ضيف</button>
            </div>
            <span class="hint">تقدر تضيف أكتر من مكان في نفس اليوم.</span>
            <div class="picked" id="picked"></div>
          </label>
          <div class="row2">
            <label><span>من الساعة <small>(اختياري)</small></span><input class="input" name="timeFrom" type="time"></label>
            <label><span>لحد الساعة <small>(اختياري)</small></span><input class="input" name="timeTo" type="time"></label>
          </div>
          <label><span>ملاحظة <small>(اختياري)</small></span><textarea class="input" name="note" maxlength="200" placeholder="مثال: متاح لأي اطلاع أو صورة حكم"></textarea></label>
          <div class="error" id="addError" hidden></div>
          <button class="btn block" type="submit">نشر التواجد</button>
        </form>
      </section>`;

    const form = document.getElementById('addForm');
    const placeInput = document.getElementById('placeInput');
    const picked = document.getElementById('picked');
    const error = document.getElementById('addError');

    document.getElementById('quickDays').addEventListener('click', (ev) => {
      const chip = ev.target.closest('[data-day]');
      if (!chip) return;
      form.day.value = chip.dataset.day;
      syncDayChips();
    });
    const syncDayChips = () => document.querySelectorAll('#quickDays .chip').forEach((c) => c.classList.toggle('on', c.dataset.day === form.day.value));
    form.day.addEventListener('change', syncDayChips);

    function drawPicked() {
      picked.innerHTML = places.map((p, i) => `<span class="place">${esc(p)}<button type="button" data-remove="${i}" aria-label="شيل ${esc(p)}">${icons.x}</button></span>`).join('');
    }
    function addPlace() {
      const value = placeInput.value.trim().replace(/\s+/g, ' ');
      if (value.length < 2) { placeInput.focus(); return; }
      if (!places.some((p) => searchWords(p).join(' ') === searchWords(value).join(' '))) places.push(value);
      placeInput.value = '';
      drawPicked();
      placeInput.focus();
    }
    document.getElementById('addPlace').addEventListener('click', addPlace);
    placeInput.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); addPlace(); } });
    picked.addEventListener('click', (ev) => {
      const b = ev.target.closest('[data-remove]');
      if (b) { places.splice(Number(b.dataset.remove), 1); drawPicked(); }
    });

    // Cities from the list and from what others wrote, and the places already used in the chosen city
    suggestions().then((list) => {
      const cities = [...new Set([...CITIES, ...list.map((s) => s.city)])];
      document.getElementById('cityList').innerHTML = cities.map((c) => `<option value="${esc(c)}">`).join('');
      const fillPlaces = () => {
        const city = searchWords(form.city.value).join(' ');
        const used = list.filter((s) => !city || searchWords(s.city).join(' ') === city).map((s) => s.place);
        document.getElementById('placeList').innerHTML = [...new Set(used)].slice(0, 80).map((p) => `<option value="${esc(p)}">`).join('');
      };
      form.city.addEventListener('input', fillPlaces);
      fillPlaces();
    });

    form.addEventListener('submit', async (ev) => {
      ev.preventDefault();
      if (placeInput.value.trim().length >= 2) addPlace();
      error.hidden = true;
      const button = form.querySelector('button[type="submit"]');
      button.disabled = true;
      try {
        await api('POST', '/entries', {
          day: form.day.value,
          city: form.city.value.trim(),
          places,
          timeFrom: form.timeFrom.value || null,
          timeTo: form.timeTo.value || null,
          note: form.note.value.trim() || null,
        });
        state.suggestions = null;
        toast('اتنشر تواجدك');
        location.hash = '#/mine';
      } catch (err) {
        error.textContent = err.message;
        error.hidden = false;
      } finally {
        button.disabled = false;
      }
    });
  }

  // ---------- My entries ----------

  async function renderMine() {
    if (!session.token) { location.hash = '#/login'; return; }
    const account = session.account || {};
    view.innerHTML = `
      <div class="mine-head">
        <div>
          <h1>تواجدي</h1>
          <p>${esc(account.fullName || '')} · <span class="ltr">${esc(account.phone || '')}</span></p>
        </div>
        <button class="btn sm ghost" id="logout">خروج</button>
      </div>
      <div id="mineList">${loading()}</div>`;

    document.getElementById('logout').addEventListener('click', async () => {
      try { await api('POST', '/logout'); } catch { /* signing out here is enough */ }
      session.clear();
      toast('خرجت من حسابك');
      location.hash = '#/';
    });

    let entries = [];
    const list = document.getElementById('mineList');
    async function load() {
      try {
        entries = await api('GET', '/mine');
        list.innerHTML = entries.length ? groupByDay(entries, [], true) : `<div class="empty">${icons.court}<b>مفيش تواجد جاي</b>ضيف المحاكم اللي هتكون فيها، وهتظهر لكل اللي بيدوّر.<br><a class="btn" href="#/add">${icons.plus}أضف تواجدك</a></div>`;
      } catch (err) {
        if (err.status === 401) { location.hash = '#/login'; return; }
        list.innerHTML = `<div class="empty"><b>مقدرناش نجيب تواجدك</b>${esc(err.message)}</div>`;
      }
    }

    list.addEventListener('click', async (ev) => {
      const del = ev.target.closest('[data-delete]');
      const share = ev.target.closest('[data-share]');
      if (del) {
        if (!confirm('تمسح التواجد ده؟')) return;
        del.disabled = true;
        try { await api('DELETE', '/entries/' + del.dataset.delete); toast('اتمسح'); load(); } catch (err) { toast(err.message); del.disabled = false; }
      }
      if (share) {
        const e = entries.find((x) => x.id === share.dataset.share);
        if (!e) return;
        const time = timeRange(e);
        const text = `متواجد ${dayLabel(e.day)} (${dayDate(e.day)}) في ${e.city}:\n${e.places.map((p) => '• ' + p).join('\n')}${time ? '\n' + time : ''}${e.note ? '\n' + e.note : ''}\n\nأي حد محتاج حاجة يكلمني، أو شوف مين متواجد فين:\n${location.origin}/tawagod/`;
        if (navigator.share) {
          navigator.share({ text }).catch(() => {});
        } else {
          window.open('https://wa.me/?text=' + encodeURIComponent(text), '_blank', 'noopener');
        }
      }
    });
    load();
  }

  // ---------- Routing ----------

  function route() {
    const path = location.hash.replace(/^#/, '') || '/';
    renderBar();
    window.scrollTo(0, 0);
    if (path === '/login') return renderLogin();
    if (path === '/add') return renderAdd();
    if (path === '/mine') return renderMine();
    return renderList();
  }

  window.addEventListener('hashchange', route);
  route();
})();
