/// Every page, tab and filter has its own link, so back, refresh and sharing a link all work.
/// Example: #/orders?status=ACTIVE&from=2026-11-01&to=2026-11-03

const LINK_KEYS = ['tab', 'state', 'status', 'side', 'method', 'filter', 'search', 'from', 'to'];
const PARENT_PAGES = { order: 'orders', ticket: 'tickets', consultation: 'consultations', review: 'reviews', application: 'applications', reviewReport: 'reports', user: 'lawyers' };

let current = { page: 'overview' };
let inAppSteps = 0;
let waitingForBack = false;
let lastMenuPage = 'overview';

function linkFor(state) {
  const query = new URLSearchParams();
  LINK_KEYS.forEach((key) => {
    if (state[key] !== undefined && state[key] !== null) query.set(key, state[key]);
  });
  const text = query.toString();
  return '#/' + state.page + (state.param ? '/' + encodeURIComponent(state.param) : '') + (text ? '?' + text : '');
}

function stateFromLink() {
  const [path, text] = location.hash.replace(/^#\/?/, '').split('?');
  const [page, param] = path.split('/');
  const state = { page: page || 'overview' };
  if (param) state.param = decodeURIComponent(param);
  new URLSearchParams(text || '').forEach((value, key) => {
    if (LINK_KEYS.includes(key)) state[key] = value;
  });
  return state;
}

function moveTo(state) {
  current = state;
  inAppSteps += 1;
  history.pushState(null, '', linkFor(state));
  render();
}

/// Any page opened from inside another one can go back to it, the side menu starts fresh
function open(page, param, fromMenu) {
  if (fromMenu) inAppSteps = 0;
  moveTo({ page, param });
}

/// Opens a list page from a work row with every date, so old work is not hidden
function goTo(page, state) {
  moveTo({ page, state, from: '', to: '' });
}

/// Goes back in the browser, and a page opened directly from a link goes to its list
function goBack() {
  if (inAppSteps > 0) {
    inAppSteps -= 1;
    waitingForBack = true;
    history.back();
    return;
  }
  moveTo({ page: PARENT_PAGES[current.page] || 'overview' });
  inAppSteps = 0;
}

window.addEventListener('popstate', () => {
  waitingForBack = false;
  if (inAppSteps > 0 && !stateFromLink().param) inAppSteps -= 1;
  current = stateFromLink();
  if (session) render();
});
