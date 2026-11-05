const API = '/api/v1';
const STORE_KEY = 'my-lawyer-admin';
let session = readSession();
let refreshing = null;
const CANCELLED = Symbol('cancelled');
const $ = (id) => document.getElementById(id);

const ICONS = {
  home: 'M3 11.5 12 4l9 7.5M5 10v10h14V10',
  ticket: 'M4 7h16v4a2 2 0 0 0 0 4v4H4v-4a2 2 0 0 0 0-4zM10 7v12',
  complaint: 'M12 3 2 21h20zM12 10v5M12 18h.01',
  appeal: 'M4 5h16v11H8l-4 4zM9 10h6',
  apply: 'M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6zM9 12l2 2 4-4',
  lawyer: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21c0-4 4-6 8-6s8 2 8 6',
  client: 'M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM2 20c0-3.5 3-5 7-5s7 1.5 7 5M16 4.5a3.5 3.5 0 0 1 0 6.5M18 15c2.5.5 4 2 4 5',
  orders: 'M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6',
  review: 'm12 3 2.8 5.8 6.2.9-4.5 4.4 1 6.2L12 17.4l-5.5 2.9 1-6.2L3 9.7l6.2-.9z',
  price: 'M12 2v20M17 6H9.5a3 3 0 0 0 0 6h5a3 3 0 0 1 0 6H6',
  logout: 'M10 4H5v16h5M15 8l4 4-4 4M19 12H9',
  search: 'M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-4-4',
  check: 'M5 12.5l4.5 4.5L19 7.5',
  open: 'M14 4h6v6M20 4l-9 9M18 14v6H4V6h6',
  phone: 'M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2',
  mail: 'M4 6h16v12H4zM4 7l8 6 8-6',
  calendar: 'M4 6h16v15H4zM4 10h16M8 3v4M16 3v4',
  power: 'M12 3v9M6.3 6.3a8 8 0 1 0 11.4 0',
  money: 'M3 7h18v10H3zM12 9.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5',
  filter: 'M4 5h16l-6 8v6l-4-2v-4z',
  close: 'M6 6l12 12M18 6 6 18',
  copy: 'M9 9h11v11H9zM5 15H4V4h11v1',
  image: 'M4 5h16v14H4zM4 16l5-5 4 4 2-2 5 5M15.5 8.5h.01',
  transfer: 'M4 8h14M14 4l4 4-4 4M20 16H6M10 12l-4 4 4 4',
  minus: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM8 12h8',
  plus: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM8 12h8M12 8v8',
  freeze: 'M12 2v20M4 7l16 10M20 7 4 17M9 4l3 3 3-3M9 20l3-3 3 3',
  unlock: 'M6 11h12v10H6zM8 11V7a4 4 0 0 1 7.5-2',
  lock: 'M6 11h12v10H6zM8 11V7a4 4 0 0 1 8 0v4',
  reject: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM8.5 8.5l7 7M15.5 8.5l-7 7',
  show: 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7zM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z',
  hide: 'M3 3l18 18M10 5.3A10 10 0 0 1 12 5c6 0 10 7 10 7a17 17 0 0 1-3 3.7M6.5 6.8A17 17 0 0 0 2 12s4 7 10 7a10 10 0 0 0 4.5-1',
  percent: 'M19 5 5 19M7 5a2 2 0 1 0 0 4 2 2 0 0 0 0-4zM17 15a2 2 0 1 0 0 4 2 2 0 0 0 0-4z',
  note: 'M5 3h14v12l-6 6H5zM13 21v-6h6M9 8h6M9 12h3',
};

// Status badge colors
const STATUS = {
  PENDING: ['بانتظار المحامي', 'amber'], ACCEPTED: ['بانتظار الدفع', 'amber'], ACTIVE: ['قيد التنفيذ', 'blue'],
  COMPLETED: ['مكتمل', 'green'], CANCELLED: ['ملغى', 'gray'], REJECTED: ['اعتذر المحامي', 'red'],
  NO_RESPONSE: ['دون رد', 'red'], PAYMENT_EXPIRED: ['انتهت مهلة الدفع', 'red'],
  EXPIRED: ['انتهت المهلة', 'red'], REFUNDED: ['مردود للموكل', 'purple'],
};
const PAYOUT = { HELD: 'محجوزة 24 ساعة', AVAILABLE: 'متاحة', FROZEN: 'مجمدة', REFUNDED: 'مردودة' };

function readSession() {
  try { return JSON.parse(sessionStorage.getItem(STORE_KEY)); } catch { return null; }
}

function saveSession(next) {
  session = next;
  try {
    if (next) sessionStorage.setItem(STORE_KEY, JSON.stringify(next));
    else sessionStorage.removeItem(STORE_KEY);
  } catch { /* the page still works for this visit */ }
}

function el(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined && text !== null) node.textContent = text;
  if (className) node.className = className;
  return node;
}

function icon(name, className) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('fill', 'none');
  svg.setAttribute('stroke', 'currentColor');
  svg.setAttribute('stroke-width', '2');
  svg.setAttribute('stroke-linecap', 'round');
  svg.setAttribute('stroke-linejoin', 'round');
  svg.setAttribute('class', className || 'ui-icon');
  const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  path.setAttribute('d', ICONS[name]);
  svg.append(path);
  return svg;
}

/// Notification pill
function toast(message, isError) {
  const pill = el('div', undefined, 'header-toast-pill type-' + (isError ? 'error' : 'success'));
  pill.title = message;
  const close = el('button', undefined, 'header-toast-close-btn');
  close.type = 'button';
  close.setAttribute('aria-label', 'إغلاق');
  close.append(icon('close', 'ui-icon'));
  close.addEventListener('click', () => pill.remove());
  pill.append(icon(isError ? 'complaint' : 'check'), el('span', message, 'header-toast-text'), close);
  $('toasts').replaceChildren(pill);
  setTimeout(() => pill.remove(), isError ? 6000 : 3500);
}

function date(value) {
  return value ? new Date(value).toLocaleString('ar-EG-u-nu-latn', { dateStyle: 'medium', timeStyle: 'short' }) : '-';
}

/// Only a clear Arabic message reaches the screen, never a technical one
function friendlyError(status, message) {
  if (message && /[\u0600-\u06FF]/.test(message)) return message;
  if (status === 401) return 'انتهت الجلسة، سجل الدخول مرة أخرى';
  if (status === 403) return 'ليس لديك صلاحية لتنفيذ هذا الإجراء';
  if (status === 404) return 'لم يتم العثور على ما تبحث عنه';
  if (status === 413) return 'حجم الملف أكبر من المسموح به';
  if (status === 429) return 'طلبات كثيرة في وقت قصير، انتظر قليلًا ثم حاول مرة أخرى';
  if (status >= 500) return 'حدثت مشكلة في الخادم، حاول مرة أخرى بعد قليل';
  return 'تعذر تنفيذ العملية، راجع البيانات وحاول مرة أخرى';
}

/// A fetch whose failures are explained in Arabic, and a body that may not be JSON
async function safeFetch(url, options) {
  try {
    return await fetch(url, options);
  } catch {
    throw new Error('تعذر الاتصال بالخادم، تحقق من الإنترنت وحاول مرة أخرى');
  }
}

async function readJson(res) {
  try {
    return await res.json();
  } catch {
    return {};
  }
}

async function refreshSession() {
  refreshing ??= fetch(API + '/auth/refresh', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken: session?.refreshToken }),
  }).then(async (res) => {
    const json = await res.json();
    if (!res.ok || !json.data?.accessToken) return false;
    saveSession({ accessToken: json.data.accessToken, refreshToken: json.data.refreshToken || session.refreshToken });
    return true;
  }).catch(() => false).finally(() => { refreshing = null; });
  return refreshing;
}

// Pages open at once from the last answer. An older answer is shown and refreshed behind it, and any change clears them.
// Counts, search and ticket messages always ask the server.
const API_FRESH_MS = 20000;
const API_KEEP_MS = 300000;
const apiCache = new Map();
const isCacheable = (method, path) => method === 'GET' && !/^\/admin\/(overview|search|support)/.test(path);

function askAndKeep(path) {
  const text = apiRequest('GET', path).then(JSON.stringify);
  const entry = { at: Date.now(), text };
  apiCache.set(path, entry);
  text.catch(() => { if (apiCache.get(path) === entry) apiCache.delete(path); });
  return text;
}

async function api(method, path, body) {
  if (!isCacheable(method, path)) {
    const json = await apiRequest(method, path, body);
    if (method !== 'GET') apiCache.clear();
    return json;
  }
  const saved = apiCache.get(path);
  const age = saved ? Date.now() - saved.at : Infinity;
  if (age > API_KEEP_MS) return JSON.parse(await askAndKeep(path));
  const answer = await saved.text;
  if (age > API_FRESH_MS) {
    askAndKeep(path).then((fresh) => { if (fresh !== answer) refreshQuietly(); }).catch(() => {});
  }
  return JSON.parse(answer);
}

async function apiRequest(method, path, body, isRetry) {
  const res = await safeFetch(API + path, {
    method,
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + session?.accessToken },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (res.status === 401) {
    if (!isRetry && await refreshSession()) return apiRequest(method, path, body, true);
    showLogin('انتهت الجلسة، سجل الدخول مرة أخرى');
    throw new Error('انتهت الجلسة');
  }
  const json = await readJson(res);
  if (!res.ok) throw new Error(friendlyError(res.status, json.error));
  return json;
}

function showLogin(message) {
  saveSession(null);
  if (typeof liveTurn !== 'undefined') liveTurn += 1;
  apiCache.clear();
  $('login').hidden = false;
  $('app').hidden = true;
  $('header-account').replaceChildren();
  $('login-error').textContent = message || '';
}
