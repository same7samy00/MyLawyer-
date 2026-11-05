const PAGES = {
  overview: ['الرئيسية', 'home', overviewPage],
  tasks: ['متابعة المهام', 'check', tasksPage],
  tickets: ['تذاكر الدعم الفني', 'complaint', ticketsPage],
  reports: ['بلاغات التقييمات', 'review', reportsPage],
  applications: ['محاميك حالاً', 'apply', applicationsPage],
  lawyers: ['حسابات المحامين', 'lawyer', usersPage('lawyer')],
  clients: ['حسابات الموكلين', 'client', usersPage('client')],
  orders: ['إدارة الطلبات', 'orders', ordersPage],
  reviews: ['إدارة التقييمات', 'review', reviewsPage],
  decisions: ['سجل قرارات الإدارة', 'apply', decisionsPage],
  money: ['إدارة الأموال', 'money', moneyPage],
  prices: ['الأسعار والنسب', 'price', pricesPage],
};
const INNER = { user: userPage, order: orderPage, application: applicationPage, ticket: ticketPage, reviewReport: reviewReportPage };
const INNER_TITLES = { user: 'الملف الشخصي', order: 'تفاصيل الطلب', application: 'طلب تقديم على محاميك حالاً', ticket: 'تذكرة دعم فني', reviewReport: 'بلاغ عن تقييم' };
const SUBTITLES = {
  overview: 'إجمالي إحصائيات التطبيق', tasks: 'ما يحتاج إلى متابعتك الآن', tickets: 'كل ما يرسله الموكلون والمحامون إلى الدعم الفني', reports: 'تعليقات أبلغ عنها المحامون',
  reviewReport: 'مراجعة التعليق والقرار', ticket: 'الرسائل والرد والإغلاق', applications: 'طلبات التقديم على الخدمة والمحامون المفعلة لهم', lawyers: 'كل حسابات المحامين',
  clients: 'كل حسابات الموكلين', orders: 'البحث في الطلبات ومتابعة حالتها', reviews: 'تقييمات الموكلين للمحامين',
  decisions: 'من اتخذ كل قرار في اللوحة ومتى', money: 'المدفوعات والأموال المجمدة والحركات', prices: 'أسعار الخدمات ونسبة المنصة والضريبة', application: 'مراجعة بيانات المحامي والقرار', user: 'البيانات والطلبات والتقييمات', order: 'البيانات ودورة حياة الطلب',
};
const NAV_GROUPS = [
  [null, ['overview']],
  ['المتابعة', ['tasks', 'tickets', 'reports']],
  ['الخدمات', ['applications']],
  ['الطلبات والحسابات', ['orders', 'lawyers', 'clients', 'reviews', 'decisions']],
  ['الأموال', ['money', 'prices']],
];
// Stretched so the first menu word lines up with the longer names under it
const NAV_LABELS = { overview: 'الرئيــــــــــسية' };
const PREFETCH = {
  lawyers: '/admin/users?role=lawyer&q=', clients: '/admin/users?role=client&q=', orders: '/admin/orders?q=&status=', reviews: '/admin/reviews',
  reports: '/admin/reviews/reported', decisions: '/admin/actions', prices: '/admin/prices', applications: '/admin/urgent-applications',
};
const NAV_COUNTS = { tasks: 'all_tasks', tickets: 'waiting_tickets', applications: 'pending_lawyers', reports: 'reported_reviews', money: 'frozen_orders' };
let navCounts = {};
let navCountsAt = 0;
let renderTurn = 0;
function setMenu(isOpen) {
  $('sidebar').classList.toggle('mobile-open', isOpen);
  $('backdrop').hidden = !isOpen;
}

function navItem(title, name, onClick, isActive, count) {
  const item = el('button', undefined, 'nav-item' + (isActive ? ' active' : ''));
  item.type = 'button';
  item.title = title;
  item.append(icon(name, 'nav-icon'), el('span', title, 'nav-label'));
  if (count > 0) item.append(el('span', count, 'nav-count'));
  item.addEventListener('click', onClick);
  return item;
}

/// The menu is rebuilt only when its active page or its numbers change
let navSignature = '';
function renderNav() {
  if (PAGES[current.page]) lastMenuPage = current.page;
  const activePage = PAGES[current.page] ? current.page : (lastMenuPage !== 'overview' ? lastMenuPage : PARENT_PAGES[current.page]);
  const signature = activePage + JSON.stringify(navCounts);
  if (signature === navSignature) return;
  navSignature = signature;
  $('nav').replaceChildren(...NAV_GROUPS.flatMap(([group, keys]) => [
    ...(group ? [el('div', group, 'nav-group-title')] : []),
    ...keys.map((key) => {
      const item = navItem(NAV_LABELS[key] || PAGES[key][0], PAGES[key][1], () => { setMenu(false); open(key, undefined, true); }, key === activePage, navCounts[NAV_COUNTS[key]]);
      item.addEventListener('pointerenter', () => prefetchPage(key), { once: true });
      return item;
    }),
  ]));
  $('nav-footer').replaceChildren(navItem('تسجيل الخروج', 'logout', () => { setMenu(false); showLogin(); }, false));
}

/// Asks for a page's list when the mouse reaches its menu item, so it is ready at the press
function prefetchPage(key) {
  const path = PREFETCH[key];
  if (path && session) api('GET', path).catch(() => {});
}

/// The red numbers follow every page change, and a failed refresh keeps the last ones
/// Tells the admin about work that arrived while the page is open
function announceNewWork(before, now) {
  if (before.waiting_tickets === undefined) return;
  if (now.waiting_tickets > before.waiting_tickets) toast('وصلت تذكرة جديدة');
  if (now.pending_lawyers > before.pending_lawyers) toast('وصل طلب تقديم جديد على محاميك حالاً');
  if (now.reported_reviews > before.reported_reviews) toast('وصل بلاغ جديد عن تقييم');
  if (now.frozen_orders > before.frozen_orders) toast('تم تجميد أموال عملية جديدة');
}

async function refreshNavCounts() {
  // Moving between pages does not ask again within 20 seconds, while a decision always does
  if (Date.now() - navCountsAt < 20000) return;
  navCountsAt = Date.now();
  try {
    const before = navCounts;
    navCounts = (await api('GET', '/admin/overview')).data;
    navCounts.all_tasks = navCounts.waiting_tickets + navCounts.frozen_orders + navCounts.pending_lawyers + navCounts.reported_reviews;
    announceNewWork(before, navCounts);
    renderNav();
  } catch {
    // Try again on the next page, the page itself shows its own errors
    navCountsAt = 0;
  }
}

/// The page is drawn again after each search, so typing carries on in the new box without losing letters
function restoreSearchFocus(typed) {
  if (!keepSearchFocus) return;
  keepSearchFocus = false;
  const field = $('content').querySelector('.table-search-input');
  if (!field) return;
  field.focus();
  if (typed !== undefined && typed !== field.value) {
    field.value = typed;
    field.dispatchEvent(new Event('input'));
  }
  field.setSelectionRange(field.value.length, field.value.length);
}

/// A list page reads from the top: numbers, search, filters, dates, then its note and table
function arrangeMainPage(box) {
  const controls = box.querySelector(':scope > .table-controls-bar');
  const note = box.querySelector(':scope > .page-guide');
  if (controls && note) controls.after(note);
}

/// The page's main tables start with a running number, tables inside a section stay as they are
function numberMainTables(box) {
  box.querySelectorAll(':scope > .table-wrapper, :scope > .tab-content-pane > .table-wrapper').forEach((wrap) => {
    wrap.classList.add('main-table');
    wrap.querySelector('thead tr').prepend(el('th', 'م', 'serial-cell'));
    wrap.querySelectorAll('tbody tr').forEach((row, index) => {
      const empty = row.querySelector('.empty-table-row');
      if (empty) empty.colSpan += 1;
      else row.prepend(el('td', String(index + 1), 'serial-cell'));
    });
  });
}

/// The old page stays on screen with a thin bar while the new one loads, so nothing flashes
async function render({ quiet = false } = {}) {
  if (waitingForBack) return;
  $('login').hidden = true;
  $('app').hidden = false;
  if (!INNER[current.page] && !PAGES[current.page]) current = { page: 'overview' };
  // Every list opens on all dates
  if (PAGES[current.page] && current.from === undefined && current.to === undefined) current.from = current.to = '';
  history.replaceState(null, '', linkFor(current));
  renderNav();
  refreshNavCounts();
  $('page-title').textContent = INNER_TITLES[current.page] || PAGES[current.page][0];
  $('page-subtitle').textContent = SUBTITLES[current.page] || '';
  $('back-button').hidden = !INNER[current.page];

  const turn = ++renderTurn;
  const shown = current.page + '/' + (current.param || '');
  const samePage = $('content').dataset.shown === shown;
  const scroll = $('content').scrollTop;
  const busy = setTimeout(() => { if (turn === renderTurn) $('content').classList.add('is-busy'); }, 150);

  const page = el('div', undefined, 'page-view active');
  const box = el('div', undefined, 'clothing-page-container');
  page.append(box);
  try {
    await (INNER[current.page] || PAGES[current.page][2])(box);
    if (turn !== renderTurn) return;
    arrangeMainPage(box);
    numberMainTables(box);
    const typed = $('content').querySelector('.table-search-input')?.value;
    $('content').replaceChildren(page);
    $('content').dataset.shown = shown;
    restoreSearchFocus(typed);
    $('content').scrollTop = samePage ? scroll : 0;
  } catch (err) {
    console.error(err);
    if (turn !== renderTurn || !session || quiet) return;
    const failed = el('div', undefined, 'page-loader');
    failed.append(el('p', err.message), link('إعادة المحاولة', () => render(), 'btn-primary'));
    $('content').replaceChildren(failed);
    $('content').dataset.shown = '';
  } finally {
    clearTimeout(busy);
    if (turn === renderTurn) $('content').classList.remove('is-busy');
  }
}

/// New data arrived for what is on screen: redraw it unless the admin is typing or in a window
function refreshQuietly() {
  if (!session || !$('dialog').hidden || document.activeElement?.matches('input, textarea, select')) return;
  render({ quiet: true });
}

async function signIn() {
  $('login-error').textContent = '';
  let res;
  const submit = $('login-button');
  submit.classList.add('is-loading');
  submit.disabled = true;
  try {
    res = await safeFetch(API + '/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identifier: $('identifier').value.trim(), password: $('password').value }),
    });
  } catch (err) {
    $('login-error').textContent = err.message;
    return;
  } finally {
    submit.classList.remove('is-loading');
    submit.disabled = false;
  }
  const json = await readJson(res);

  if (!res.ok || json.data?.user?.role !== 'admin') {
    $('login-error').textContent = res.ok ? 'الحساب ليس حساب إدارة' : friendlyError(res.status, json.error);
    return;
  }

  saveSession({ accessToken: json.data.accessToken, refreshToken: json.data.refreshToken });
  navCountsAt = 0;
  $('password').value = '';
  render();
  showAccount();
  toast('مرحبًا بك');
}

/// The search in the top header: accounts, orders and tickets in one list
function setupGlobalSearch() {
  const box = $('global-search');
  const field = el('input', undefined, 'global-search-input');
  field.type = 'search';
  field.placeholder = 'ابحث عن حساب أو طلب أو تذكرة';
  field.setAttribute('aria-label', 'بحث شامل');
  const results = el('div', undefined, 'global-search-results');
  results.hidden = true;
  box.append(icon('search', 'global-search-icon'), field, results);

  let timer = null;
  let latest = 0;
  const close = () => { results.hidden = true; };
  const row = (title, detail, onPick) => {
    const node = el('button', undefined, 'global-search-row');
    node.type = 'button';
    node.append(el('strong', title), el('span', detail));
    node.addEventListener('click', () => {
      close();
      field.value = '';
      setMenu(false);
      onPick();
    });
    return node;
  };
  const show = ({ users, orders, tickets }) => {
    const groups = [
      ['الحسابات', users.map((item) => row(item.name, (item.role === 'lawyer' ? 'محامٍ' : 'موكل') + ' • ' + item.phone, () => open('user', item.id)))],
      ['الطلبات', orders.map((item) => row(item.order_number, item.client_name + ' • ' + (item.lawyer_name || '-'), () => open('order', item.id)))],
      ['التذاكر', tickets.map((item) => row(item.reference, item.title, () => open('ticket', item.id)))],
    ].filter(([, rows]) => rows.length);
    results.replaceChildren(...(groups.length
      ? groups.flatMap(([title, rows]) => [el('div', title, 'global-search-group'), ...rows])
      : [el('p', 'لا توجد نتائج', 'global-search-empty')]));
    results.hidden = false;
  };
  field.addEventListener('input', () => {
    clearTimeout(timer);
    const q = field.value.trim();
    const ticket = ++latest;
    if (q.length < 2) { close(); return; }
    timer = setTimeout(async () => {
      try {
        const { data } = await api('GET', '/admin/search?q=' + encodeURIComponent(q));
        if (ticket === latest) show(data);
      } catch (err) {
        toast(err.message, true);
      }
    }, 300);
  });
  field.addEventListener('keydown', (event) => { if (event.key === 'Escape') close(); });
  document.addEventListener('click', (event) => { if (!box.contains(event.target)) close(); });
}
setupGlobalSearch();

const MENU_KEY = 'my-lawyer-admin-menu';
function setCollapsed(isCollapsed) {
  $('sidebar').classList.toggle('collapsed', isCollapsed);
  // The arrow points where the menu will move
  $('sidebar-arrow').setAttribute('d', isCollapsed ? 'M15 6l-6 6 6 6' : 'M9 6l6 6-6 6');
  try { localStorage.setItem(MENU_KEY, isCollapsed ? '1' : '0'); } catch { /* remembered for this visit only */ }
}
try { setCollapsed(localStorage.getItem(MENU_KEY) === '1'); } catch { /* opens expanded */ }
$('sidebar-toggle').addEventListener('click', () => setCollapsed(!$('sidebar').classList.contains('collapsed')));

/// The app name and the account repeated faintly over the page, so a screenshot shows who took it
function setWatermark(account) {
  const safe = account.replace(/[&<>"']/g, (char) => '&#' + char.charCodeAt(0) + ';');
  const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="340" height="190"><g transform="rotate(-24 170 95)" fill="#1d4ed8" text-anchor="middle" font-family="Arial, sans-serif">'
    + '<text x="170" y="90" font-size="24" font-weight="700">My Lawyer</text><text x="170" y="114" font-size="12">' + safe + '</text></g></svg>';
  $('watermark').style.backgroundImage = 'url("data:image/svg+xml,' + encodeURIComponent(svg) + '")';
}

/// The signed-in account at the left edge of the top header
async function showAccount() {
  try {
    const { data } = await api('GET', '/users/me');
    const box = $('header-account');
    box.title = data.email || '';
    const name = data.fullName || data.email || data.phone || 'حساب الإدارة';
    box.replaceChildren(icon('lawyer'), el('span', name));
    setWatermark(data.email && data.email !== name ? name + ' - ' + data.email : name);
  } catch { /* the page works without the name */ }
}

$('menu-button').addEventListener('click', () => setMenu(true));
$('backdrop').addEventListener('click', () => setMenu(false));
$('back-button').addEventListener('click', goBack);
$('login-form').addEventListener('submit', (event) => {
  event.preventDefault();
  signIn();
});
current = stateFromLink();
if (session) { render(); showAccount(); }

// New work reaches the admin without moving between pages
setInterval(() => {
  if (!session || $('app').hidden || document.hidden) return;
  navCountsAt = 0;
  refreshNavCounts();
}, 60000);
