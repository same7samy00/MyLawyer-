// Pages

function workRow(iconName, count, text, onClick) {
  const row = el('button', undefined, 'work-row');
  row.type = 'button';
  row.append(icon(iconName), el('strong', count, 'work-count'), el('span', text, 'work-text'), icon('open', 'ui-icon work-arrow'));
  row.addEventListener('click', onClick);
  return row;
}

/// What needs the admin now, each row opens its list with no date limit
async function tasksPage(box) {
  const { data } = await api('GET', '/admin/overview');
  box.append(summaryBar([
    ['تذاكر تنتظر ردك', data.waiting_tickets, 'complaint', 'amber'], ['أموال مجمدة', data.frozen_orders, 'power', 'red'],
    ['طلبات تقديم', data.pending_lawyers, 'apply', 'blue'], ['بلاغات تقييم', data.reported_reviews, 'review', 'amber'],
  ]));
  const rows = [
    ['complaint', data.waiting_tickets, 'تذاكر تنتظر ردك', () => goTo('tickets', 'UNDER_REVIEW')],
    ['power', data.frozen_orders, 'عمليات أموالها مجمدة وتنتظر قرارك', () => goTo('money')],
    ['apply', data.pending_lawyers, 'طلبات تقديم على محاميك حالاً تنتظر المراجعة', () => goTo('applications')],
    ['review', data.reported_reviews, 'بلاغات تقييم تنتظر قرارك', () => goTo('reports')],
  ].filter(([, count]) => count > 0);

  const list = el('div', undefined, 'work-list');
  if (rows.length) list.append(...rows.map((row) => workRow(...row)));
  else list.append(el('p', 'لا يوجد شيء مطلوب منك الآن.', 'muted'));
  box.append(section('المطلوب منك', list));
}

/// Totals for the whole app since it started
async function overviewPage(box) {
  const { data } = await api('GET', '/admin/overview');
  const pounds = (value) => Number(value) + ' ج.م';
  const group = (title, cards) => box.append(section(title, summaryBar(cards)));
  group('الحسابات', [
    ['الموكلون', data.clients, 'client', 'brand'], ['المحامون', data.lawyers, 'lawyer', 'blue'],
    ['خدمة محاميك حالاً مفعلة', data.service_lawyers, 'check', 'green'], ['محامون متاحون', data.available_lawyers, 'apply', 'green'],
  ]);
  group('إحصائيات الطلبات', [
    ['كل الطلبات', data.total_orders, 'orders', 'brand'], ['جارية', data.open_orders, 'orders', 'blue'],
    ['مكتملة', data.completed_orders, 'check', 'green'], ['ملغاة', data.cancelled_orders, 'close', 'red'],
  ]);
  group('الأموال', [
    ['إجمالي المدفوعات', pounds(data.total_paid), 'money', 'brand'], ['قيمة الطلبات المكتملة', pounds(data.completed_value), 'money', 'green'],
    ['أموال مجمدة', pounds(data.frozen_value), 'power', 'red'],
  ]);
  group('الدعم والتقييمات', [
    ['تذاكر مفتوحة', data.open_tickets + data.waiting_tickets, 'complaint', 'amber'], ['كل التقييمات', data.total_reviews, 'review', 'blue'],
    ['متوسط التقييم', Number(data.average_rating).toFixed(1) + ' / 5', 'review', 'green'],
  ]);
}

/// Opens a list item on its own page, then comes back to the list after a decision
async function decideAndReturn(request) {
  const res = await request();
  goBack();
  return res;
}

function openButton(text, page, item) {
  return link(text, () => open(page, item), 'btn-outline btn-xs', 'open');
}
