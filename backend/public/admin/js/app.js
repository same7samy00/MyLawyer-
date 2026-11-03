const PAGES = {
  overview: ['الرئيسية', 'home', overviewPage],
  tickets: ['تذاكر الدعم الفني', 'complaint', ticketsPage],
  reports: ['بلاغات التقييمات', 'review', reportsPage],
  applications: ['طلبات انضمام المحامين', 'apply', applicationsPage],
  lawyers: ['حسابات المحامين', 'lawyer', usersPage('lawyer')],
  clients: ['حسابات الموكلين', 'client', usersPage('client')],
  orders: ['إدارة الطلبات', 'orders', ordersPage],
  reviews: ['إدارة التقييمات', 'review', reviewsPage],
  decisions: ['سجل قرارات الإدارة', 'apply', decisionsPage],
  money: ['إدارة الأموال', 'money', moneyPage],
  prices: ['الأسعار والنسب', 'price', pricesPage],
};
const INNER = { user: userPage, order: orderPage, application: applicationPage, ticket: ticketPage, reviewReport: reviewReportPage };
const INNER_TITLES = { user: 'الملف الشخصي', order: 'تفاصيل الطلب', application: 'طلب انضمام', ticket: 'تذكرة دعم فني', reviewReport: 'بلاغ عن تقييم' };
const SUBTITLES = {
  overview: 'ما يحتاج إلى متابعتك الآن', tickets: 'كل ما يرسله الموكلون والمحامون إلى الدعم الفني', reports: 'تعليقات أبلغ عنها المحامون',
  reviewReport: 'مراجعة التعليق والقرار', ticket: 'الرسائل والرد والإغلاق', applications: 'محامون تقدموا للانضمام إلى الخدمة', lawyers: 'كل حسابات المحامين',
  clients: 'كل حسابات الموكلين', orders: 'البحث في الطلبات ومتابعة حالتها', reviews: 'تقييمات الموكلين للمحامين',
  decisions: 'من اتخذ كل قرار في اللوحة ومتى', money: 'المدفوعات والأموال المجمدة والحركات', prices: 'أسعار الخدمات ونسبة المنصة والضريبة', application: 'مراجعة بيانات المحامي والقرار', user: 'البيانات والطلبات والتقييمات', order: 'البيانات ودورة حياة الطلب',
};
const NAV_GROUPS = [
  [null, ['overview']],
  ['المتابعة', ['tickets', 'applications', 'reports']],
  ['الطلبات والحسابات', ['orders', 'lawyers', 'clients', 'reviews', 'decisions']],
  ['الأموال', ['money', 'prices']],
];
const NAV_COUNTS = { tickets: 'waiting_tickets', applications: 'pending_lawyers', reports: 'reported_reviews', money: 'frozen_orders' };
let navCounts = {};
let navCountsAt = 0;
let renderTurn = 0;
let current = { page: 'overview' };
let trail = [];

/// Any page opened from inside another one can go back to it, the side menu starts fresh
function open(page, param, fromMenu) {
  if (fromMenu) trail = [];
  else trail.push({ ...current });
  current = { page, param };
  render();
}

function goBack() {
  if (trail.length === 0) return;
  current = trail.pop();
  render();
}

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

function renderNav() {
  const activePage = trail.length ? trail[0].page : current.page;
  $('nav').replaceChildren(...NAV_GROUPS.flatMap(([group, keys]) => [
    ...(group ? [el('div', group, 'nav-group-title')] : []),
    ...keys.map((key) => navItem(PAGES[key][0], PAGES[key][1], () => { setMenu(false); open(key, undefined, true); }, key === activePage, navCounts[NAV_COUNTS[key]])),
  ]));
  $('nav-footer').replaceChildren(navItem('تسجيل الخروج', 'logout', () => { setMenu(false); showLogin(); }, false));
}

/// The red numbers follow every page change, and a failed refresh keeps the last ones
/// Tells the admin about work that arrived while the page is open
function announceNewWork(before, now) {
  if (before.waiting_tickets === undefined) return;
  if (now.waiting_tickets > before.waiting_tickets) toast('وصلت تذكرة جديدة');
  if (now.pending_lawyers > before.pending_lawyers) toast('وصل طلب انضمام جديد');
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
    announceNewWork(before, navCounts);
    renderNav();
  } catch {
    // Try again on the next page, the page itself shows its own errors
    navCountsAt = 0;
  }
}

async function render() {
  $('login').hidden = true;
  $('app').hidden = false;
  renderNav();
  refreshNavCounts();
  if (!INNER[current.page] && !PAGES[current.page]) current = { page: 'overview' };
  $('page-title').textContent = INNER_TITLES[current.page] || PAGES[current.page][0];
  $('page-subtitle').textContent = SUBTITLES[current.page] || '';
  $('back-button').hidden = trail.length === 0;

  // Only the newest page may draw, and the loader appears only if the page is slow
  const turn = ++renderTurn;
  const loader = setTimeout(() => {
    if (turn !== renderTurn) return;
    const spin = el('div', undefined, 'page-loader');
    spin.append(el('span', undefined, 'page-spinner'), el('p', 'جارٍ التحميل...'));
    $('content').replaceChildren(spin);
  }, 120);

  const page = el('div', undefined, 'page-view active');
  const box = el('div', undefined, 'clothing-page-container');
  page.append(box);
  try {
    await (INNER[current.page] || PAGES[current.page][2])(box);
    if (turn !== renderTurn) return;
    $('content').replaceChildren(page);
    $('content').scrollTop = 0;
  } catch (err) {
    console.error(err);
    if (turn !== renderTurn || !session) return;
    const failed = el('div', undefined, 'page-loader');
    failed.append(el('p', err.message), link('إعادة المحاولة', () => render(), 'btn-primary'));
    $('content').replaceChildren(failed);
  } finally {
    clearTimeout(loader);
  }
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
if (session) { render(); showAccount(); }

// New work reaches the admin without moving between pages
setInterval(() => {
  if (!session || $('app').hidden || document.hidden) return;
  navCountsAt = 0;
  refreshNavCounts();
}, 60000);
