// Building blocks

/// Every action shows a clear result and redraws the page
function button(text, className, onClick, success, iconName) {
  const node = el('button', undefined, 'btn ' + className);
  node.type = 'button';
  if (iconName) node.append(icon(iconName));
  node.append(el('span', text));
  node.addEventListener('click', async () => {
    node.disabled = true;
    node.classList.add('is-loading');
    try {
      const res = await onClick();
      if (res === CANCELLED) return;
      toast(success || res?.message || 'تم الحفظ');
      navCountsAt = 0;
      await render();
    } catch (err) {
      toast(err.message, true);
    } finally {
      node.disabled = false;
      node.classList.remove('is-loading');
    }
  });
  return node;
}

function link(text, onClick, className, iconName) {
  const node = el('button', undefined, 'btn ' + (className || 'btn-outline'));
  node.type = 'button';
  if (iconName) node.append(icon(iconName));
  node.append(el('span', text));
  node.addEventListener('click', onClick);
  return node;
}

/// A number that copies itself when pressed, without opening the row around it
function copyable(text) {
  const node = el('button', undefined, 'copy-number');
  node.type = 'button';
  node.title = 'اضغط للنسخ';
  node.append(el('span', text), icon('copy'));
  node.addEventListener('click', async (event) => {
    event.stopPropagation();
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      const area = el('textarea');
      area.value = text;
      document.body.append(area);
      area.select();
      document.execCommand('copy');
      area.remove();
    }
    toast('تم نسخ ' + text);
  });
  return node;
}

const copyOr = (text) => (text ? copyable(text) : '-');

function closeIcon(onClick) {
  const node = el('button', undefined, 'window-close');
  node.type = 'button';
  node.title = 'إغلاق';
  node.setAttribute('aria-label', 'إغلاق');
  node.append(icon('close'));
  node.addEventListener('click', onClick);
  return node;
}

/// Shows one image over everything, even over another window, without leaving the page
function openImage(src, alt) {
  const overlay = el('div', undefined, 'image-viewer');
  const close = () => { overlay.remove(); document.removeEventListener('keydown', onKey); };
  const onKey = (event) => { if (event.key === 'Escape') close(); };
  const image = el('img');
  image.src = src;
  image.alt = alt || '';
  overlay.append(closeIcon(close), image);
  overlay.addEventListener('click', (event) => { if (event.target === overlay) close(); });
  document.addEventListener('keydown', onKey);
  document.body.append(overlay);
}

/// A small image that opens large when pressed
function imageThumb(src, alt) {
  const node = el('button', undefined, 'image-thumb');
  node.type = 'button';
  node.setAttribute('aria-label', 'عرض ' + alt);
  const image = el('img');
  image.src = src;
  image.alt = alt;
  node.append(image);
  node.addEventListener('click', () => openImage(src, alt));
  return node;
}

function askConfirm(message) {
  return new Promise((resolve) => {
    const close = (answer) => { $('dialog').hidden = true; $('dialog').replaceChildren(); resolve(answer); };
    const backdrop = el('div', undefined, 'modal-backdrop');
    const card = el('div', undefined, 'modal-card modal-md');
    const head = el('div', undefined, 'modal-header');
    const titleBox = el('div', undefined, 'modal-title-box');
    titleBox.append(el('h3', 'تأكيد الإجراء'));
    head.append(titleBox, closeIcon(() => close(false)));
    const body = el('div', undefined, 'modal-body');
    body.style.padding = '1.1rem 1.35rem';
    body.append(el('p', message));
    const actions = el('div', undefined, 'modal-actions');
    actions.append(link('تراجع', () => close(false)), link('تأكيد', () => close(true), 'btn-danger'));
    card.append(head, body, actions);
    backdrop.append(card);
    $('dialog').replaceChildren(backdrop);
    $('dialog').hidden = false;
  });
}

function confirmed(message, action) {
  return async () => {
    if (!await askConfirm(message)) return CANCELLED;
    return action();
  };
}

function badge(label, color) {
  return el('span', label, 'status-badge bg-' + (color || 'gray'));
}

function tag(status) {
  const [label, color] = STATUS[status] || [status, 'gray'];
  return badge(label, color);
}

function accountTag(status) {
  const map = { active: ['نشط', 'green'], suspended: ['موقوف', 'red'], rejected: ['مرفوض', 'red'] };
  const [label, color] = map[status] || ['بانتظار التفعيل', 'amber'];
  return badge(label, color);
}

function table(headers, rows, onClick) {
  const wrap = el('div', undefined, 'table-wrapper sticky-table-container');
  const node = el('table', undefined, 'custom-table text-center-table');
  const head = el('tr');
  headers.forEach((title) => head.append(el('th', title)));
  const thead = el('thead');
  thead.append(head);
  const tbody = el('tbody');

  rows.forEach((row) => {
    const line = el('tr', undefined, onClick ? 'click' : '');
    row.cells.forEach((cell) => {
      const td = el('td');
      td.append(cell instanceof Node ? cell : document.createTextNode(cell ?? '-'));
      line.append(td);
    });
    if (onClick) line.addEventListener('click', (event) => { if (!event.target.closest('button')) onClick(row.item); });
    tbody.append(line);
  });
  if (rows.length === 0) {
    const empty = el('td', 'لا توجد بيانات', 'empty-table-row');
    empty.colSpan = headers.length;
    const line = el('tr');
    line.append(empty);
    tbody.append(line);
  }
  node.append(thead, tbody);
  wrap.append(node);
  return wrap;
}

const FIELD_ICONS = [
  [/الاسم|الموكل|المحامي/, 'client'], [/الهاتف/, 'phone'], [/الإيميل|البريد/, 'mail'],
  [/تاريخ|القبول|الدفع|الوصول|الإنهاء|آخر تحديث/, 'calendar'], [/القيد|الاعتماد/, 'apply'], [/الخبرة|الخدمة|المشكلة/, 'orders'],
  [/السعر|المبلغ|الأتعاب|صافي/, 'money'], [/التقييم/, 'review'], [/متاح|الإتاحة/, 'power'],
  [/الوصف|التعليق|السبب|الشكوى/, 'appeal'], [/الحالة/, 'filter'],
];

function fieldIcon(label) {
  const match = FIELD_ICONS.find(([pattern]) => pattern.test(label));
  return icon(match ? match[1] : 'ticket');
}

function details(fields) {
  const wrap = el('div', undefined, 'table-wrapper');
  const list = el('table', undefined, 'custom-table detail-table');
  const tbody = el('tbody');
  fields.forEach(([label, value]) => {
    const line = el('tr');
    const cell = el('td');
    cell.append(value instanceof Node ? value : document.createTextNode(value ?? '-'));
    const head = el('th');
    const key = el('span', undefined, 'info-key');
    key.append(fieldIcon(label), el('span', label));
    head.append(key);
    line.append(head, cell);
    tbody.append(line);
  });
  list.append(tbody);
  wrap.append(list);
  return wrap;
}

const SECTION_ICONS = {
  'الطلبات': 'orders', 'التذاكر': 'ticket', 'التقييمات': 'review', 'التقييم': 'review', 'المخالفات': 'complaint', 'الإنذارات': 'complaint',
  'إضافات وخصومات الرصيد': 'money', 'كل حركات الرصيد': 'money', 'مدفوعات الموكل': 'money', 'الدفعة': 'money', 'الأموال التي تحركت في هذا الطلب': 'transfer',
  'حالة الأتعاب': 'money', 'حالة الأموال': 'money', 'سجل التجميد': 'freeze', 'بيانات التسوية': 'apply', 'تذاكر الدعم الفني': 'ticket',
  'أطراف الطلب': 'client', 'تفاصيل المشكلة': 'appeal', 'المواعيد': 'calendar', 'مراحل الطلب': 'orders', 'الرسائل': 'appeal', 'حالة التذكرة': 'lock',
  'بيانات الحساب': 'lawyer', 'الصورة وبطاقة النقابة': 'apply', 'البيانات المهنية': 'apply', 'الإتاحة والموقع': 'power', 'سبب البلاغ': 'complaint', 'المطلوب منك': 'check',
};

// A short line under each inner table's title, saying what the table shows
const SECTION_HELP = {
  'الطلبات': 'كل الطلبات التي كان هذا الحساب طرفًا فيها. اضغط على طلب لفتحه.',
  'التذاكر': 'كل المشكلات التي أرسلها صاحب هذا الحساب إلى الدعم الفني. اضغط على تذكرة لفتحها.',
  'التقييمات': 'التقييمات المسجلة على طلبات هذا الحساب. اضغط على تقييم لفتح طلبه.',
  'المخالفات': 'المخالفات التي سجلها النظام على المحامي، مثل الاعتذار بعد الدفع. وتكرارها قد يوقف حسابه.',
  'إضافات وخصومات الرصيد': 'كل مبلغ أُضيف إلى رصيد المحامي أو خُصم منه خارج أتعاب الطلبات، مثل إجراءات الإدارة والتحويلات، مع سببه.',
  'مدفوعات الموكل': 'كل دفعة دفعها هذا الموكل برقمها. اضغط على الرقم لنسخه، أو على السطر لفتح الطلب.',
  'الدفعة': 'الدفعة التي دفعها الموكل لهذا الطلب.',
  'كل حركات الرصيد': 'كل مبلغ دخل رصيد الموكل أو خرج منه، مثل رد قيمة طلب أو الدفع من الرصيد، مع سببه.',
  'الإنذارات': 'الإنذارات الموجهة إلى هذا الحساب. وثلاثة إنذارات سارية خلال 30 يومًا توقفه أسبوعًا.',
  'تذاكر الدعم الفني': 'المشكلات التي فتحها الموكل أو المحامي على هذا الطلب. اضغط على تذكرة لفتحها.',
  'التقييم': 'تقييم الموكل للمحامي على هذا الطلب.',
  'الأموال التي تحركت في هذا الطلب': 'كل مبلغ أُضيف إلى رصيد الموكل أو المحامي أو خُصم منه بسبب هذا الطلب.',
  'سجل التجميد': 'كل مرة جُمدت فيها أتعاب هذا الطلب أو فُك تجميدها أو سُويت، ومن قام بذلك.',
};

/// A titled card like form-card-section, its content goes into the body
function section(title, ...nodes) {
  const card = el('div', undefined, 'form-card-section');
  const head = el('div', undefined, 'form-card-header');
  const titleBox = el('div', undefined, 'section-title');
  titleBox.append(icon(SECTION_ICONS[title] || 'ticket'), el('h3', title));
  head.append(titleBox);
  if (SECTION_HELP[title]) head.append(el('p', SECTION_HELP[title], 'section-help'));
  const body = el('div', undefined, 'form-card-body');
  body.append(...nodes);
  card.append(head, body);
  card.body = body;
  return card;
}

function subheading(title) {
  const box = el('div', undefined, 'section-subheading-box');
  box.append(el('h4', title));
  return box;
}

function actionRow(...nodes) {
  const row = el('div', undefined, 'form-actions-row');
  row.append(...nodes);
  return row;
}

function actions(...nodes) {
  const wrap = el('div');
  wrap.append(subheading('الإجراءات'), actionRow(...nodes));
  return wrap;
}

/// KPI cards like products-summary-bar
function summaryBar(items) {
  const bar = el('div', undefined, 'products-summary-bar');
  items.forEach(([title, value, name, tone]) => {
    const card = el('div', undefined, 'summary-card');
    const box = el('div', undefined, 'summary-card-icon bg-' + (tone || 'brand') + '-subtle');
    const glyph = icon(name || 'orders');
    glyph.classList.add({ brand: 'text-brand', green: 'text-success', blue: 'text-blue', amber: 'text-amber', red: 'text-danger', gray: 'text-brand' }[tone || 'brand']);
    box.append(glyph);
    const data = el('div', undefined, 'summary-card-data');
    data.append(el('span', title, 'summary-title'), el('strong', value ?? '-', 'summary-val'));
    card.append(box, data);
    bar.append(card);
  });
  return bar;
}

function controlsBar(right, left) {
  const bar = el('div', undefined, 'table-controls-bar');
  const start = el('div', undefined, 'controls-right');
  start.append(...right);
  bar.append(start);
  if (left && left.length) {
    const end = el('div', undefined, 'controls-left');
    end.append(...left);
    bar.append(end);
  }
  return bar;
}

function searchBox(value, placeholder, onSearch) {
  const box = el('div', undefined, 'search-input-box icon-pos-start');
  box.append(icon('search', 'search-icon'));
  const input = el('input', undefined, 'table-search-input');
  input.placeholder = placeholder;
  input.value = value || '';
  input.addEventListener('keydown', (event) => { if (event.key === 'Enter') onSearch(input.value.trim()); });
  box.append(input);
  return box;
}

function filterSelect(options, value, onPick, iconName) {
  const box = el('div', undefined, 'filter-select-box');
  if (iconName) box.append(icon(iconName));
  const select = el('select', undefined, 'table-filter-select');
  options.forEach(([key, label]) => select.append(new Option(label, key)));
  select.value = value;
  select.addEventListener('change', () => onPick(select.value));
  box.append(select);
  return box;
}

/// A filter as buttons: pressing one applies it at once
function filterButtons(options, value, onPick) {
  const bar = el('div', undefined, 'filter-buttons');
  options.forEach(([key, label]) => {
    const node = el('button', label, 'filter-button' + (key === value ? ' active' : ''));
    node.type = 'button';
    node.setAttribute('aria-pressed', String(key === value));
    node.addEventListener('click', () => onPick(key));
    bar.append(node);
  });
  return bar;
}

function input(value, placeholder, className) {
  const node = el('input', undefined, 'field-input ' + (className || ''));
  if (value !== undefined) node.value = value;
  if (placeholder) node.placeholder = placeholder;
  return node;
}

function textarea(value, placeholder, className) {
  const node = el('textarea', undefined, 'field-input ' + (className || ''));
  if (value !== undefined) node.value = value;
  if (placeholder) node.placeholder = placeholder;
  node.style.minHeight = '60px';
  node.style.width = '100%';
  node.style.resize = 'vertical';
  node.style.lineHeight = '1.6';
  node.style.padding = '0.65rem 0.85rem';
  return node;
}

/// Top card for a profile or an order, like view-hero-card
function hero(avatar, title, badges, pills, buttons) {
  const card = el('div', undefined, 'view-hero-card');
  const main = el('div', undefined, 'view-hero-main');
  const info = el('div', undefined, 'view-hero-info');
  const row = el('div', undefined, 'view-title-row');
  row.style.flexWrap = 'wrap';
  row.append(el('h2', title, 'view-product-title'), ...badges);
  const meta = el('div', undefined, 'view-meta-pills');
  pills.forEach(([name, text]) => {
    const pill = el('span', undefined, 'view-meta-pill');
    pill.append(icon(name), text instanceof Node ? text : document.createTextNode(text ?? '-'));
    meta.append(pill);
  });
  info.append(row, meta);
  main.append(avatar, info);
  card.append(main);
  if (buttons.length) {
    const tools = el('div', undefined, 'view-hero-actions');
    tools.append(...buttons);
    card.append(tools);
  }
  return card;
}

function avatarBox(photo, fallbackIcon) {
  const box = el('div', undefined, 'hero-avatar');
  if (photo) {
    const image = el('img');
    image.src = photo;
    image.alt = '';
    box.append(image);
  } else {
    box.append(icon(fallbackIcon));
  }
  return box;
}

function tabs(list, active, onPick) {
  const bar = el('div', undefined, 'custom-tabs-container');
  list.forEach(([key, label, count]) => {
    const tab = el('button', undefined, 'custom-tab-btn' + (key === active ? ' active' : ''));
    tab.type = 'button';
    tab.append(el('span', label));
    if (count !== undefined) tab.append(el('span', count, 'tab-badge-pill'));
    tab.addEventListener('click', () => onPick(key));
    bar.append(tab);
  });
  return bar;
}

function statsOf(item, prefix) {
  return { orders: item[prefix + '_orders'], against: item[prefix + '_against'], filed: item[prefix + '_filed'] };
}

/// Orders and complaints next to every account, so the history is clear at a glance
function statPills(stats) {
  const row = el('div', undefined, 'person-stats');
  if (!stats || stats.orders === undefined) return row;
  const pill = (label, value, tone) => {
    const node = el('span', undefined, 'person-pill ' + tone);
    node.append(el('b', value ?? 0), el('span', label));
    return node;
  };
  row.append(
    pill('طلب', stats.orders, 'blue'),
    pill('شكوى ضده', stats.against, stats.against > 0 ? 'red' : 'gray'),
    pill('شكوى قدمها', stats.filed, stats.filed > 0 ? 'amber' : 'gray'));
  return row;
}

function initials(name) {
  return (name || '؟').trim().split(/\s+/).filter((word) => !word.endsWith('.')).slice(0, 2).map((word) => word[0]).join('');
}

/// Each piece of a person's data on its own line with an icon
function infoLine(name, label, value) {
  const line = el('div', undefined, 'info-line');
  const key = el('span', undefined, 'info-key');
  key.append(icon(name), el('span', label));
  line.append(key, el('span', value || '-', 'info-value'));
  return line;
}

/// The person's photo, or their initials when there is none. Pressing a photo opens it large
function personAvatar(name, photo) {
  if (!photo) return el('div', initials(name), 'person-avatar');
  const box = imageThumb(photo, name || 'صورة الحساب');
  box.classList.add('person-avatar');
  return box;
}

function personCard(role, name, phone, id, stats, email, photo) {
  const card = el('div', undefined, 'person-card');
  const head = el('div', undefined, 'person-head');
  const title = el('div', undefined, 'person-info');
  title.append(el('span', role, 'person-role'), el('strong', name || '-', 'person-name'));
  head.append(personAvatar(name, photo), title);
  if (id) head.append(link('الملف', () => open('user', id), 'btn-outline btn-xs', 'open'));

  const lines = el('div', undefined, 'info-lines');
  lines.append(infoLine('phone', 'الهاتف', phone));
  if (email !== undefined) lines.append(infoLine('mail', 'البريد', email));
  card.append(head, lines, statPills(stats));
  return card;
}

function parties(...cards) {
  const grid = el('div', undefined, 'person-grid');
  grid.append(...cards);
  return grid;
}

function personCell(name, phone) {
  const cell = el('div', undefined, 'person-cell');
  cell.append(el('strong', name || '-'));
  if (phone) cell.append(el('span', phone, 'person-phone'));
  return cell;
}

function dateInput(key, placeholder) {
  const node = el('input', undefined, 'field-input date-input');
  node.type = 'date';
  node.title = placeholder;
  node.value = current[key] || '';
  node.addEventListener('change', () => { current[key] = node.value; render(); });
  const box = el('label', undefined, 'date-filter');
  box.append(el('span', placeholder), node);
  return box;
}

function dateFilters() {
  return [dateInput('from', 'من'), dateInput('to', 'إلى')];
}

function stateFilter(options) {
  return filterButtons(options, current.state || '', (value) => { current.state = value; render(); });
}

/// Keeps the rows inside the chosen dates and state
function applyFilters(list, getDate, getState) {
  const from = current.from ? new Date(current.from + 'T00:00:00') : null;
  const to = current.to ? new Date(current.to + 'T23:59:59') : null;
  return list.filter((row) => {
    const at = getDate ? new Date(getDate(row)) : null;
    if (from && at && at < from) return false;
    if (to && at && at > to) return false;
    if (current.state && getState && getState(row) !== current.state) return false;
    return true;
  });
}

function sumOf(list, key) {
  return list.reduce((total, row) => total + Number(row[key] || 0), 0);
}

/// A short explanation for whoever works on the control page
function guide(...lines) {
  const box = el('div', undefined, 'page-guide');
  const body = el('div');
  lines.forEach((line) => body.append(el('p', line)));
  box.append(icon('note'), body);
  return box;
}

const OUTCOMES = {
  REFUND: ['رد للموكل', 'btn-outline-danger'],
  LAWYER: ['صرف للمحامي', 'btn-outline'],
};

/// The order facts behind a money decision, and the equal decision buttons
async function settlementParts(orderId) {
  const { data } = await api('GET', '/admin/orders/' + orderId + '/settlement');
  const facts = details([
    ['وصول المحامي', data.lawyerArrived ? badge('سُجّل الوصول', 'green') : badge('لم يُسجّل الوصول', 'red')],
    ['إنهاء المهمة', data.taskCompleted ? badge('أنهى المحامي المهمة', 'green') : badge('لم تُنهَ المهمة', 'red')],
    ['إنذارات الموكل السارية', data.clientWarnings], ['إنذارات المحامي السارية', data.lawyerWarnings],
    ['قيمة الطلب', data.price + ' ج.م'],
  ]);
  return { facts, open: data.open };
}

/// The title lives in the top header, and the page keeps only its extra details
function pageHead(title) {
  $('page-title').textContent = title;
}

function empty(title, message) {
  return section(title, el('p', message, 'muted'));
}
