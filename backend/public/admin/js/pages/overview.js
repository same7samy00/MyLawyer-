// Pages

/// Opens a list page from a work row, already filtered to what needs attention
function goTo(page, state) {
  trail = [];
  current = { page, state };
  render();
}

function workRow(iconName, count, text, onClick) {
  const row = el('button', undefined, 'work-row');
  row.type = 'button';
  row.append(icon(iconName), el('strong', count, 'work-count'), el('span', text, 'work-text'), icon('open', 'ui-icon work-arrow'));
  row.addEventListener('click', onClick);
  return row;
}

async function overviewPage(box) {
  const { data } = await api('GET', '/admin/overview');
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

  box.append(summaryBar([
    ['الموكلون', data.clients, 'client', 'brand'], ['المحامون', data.lawyers, 'lawyer', 'blue'],
    ['محامون متاحون', data.available_lawyers, 'apply', 'green'], ['طلبات جارية', data.open_orders, 'orders', 'blue'],
    ['طلبات مكتملة', data.completed_orders, 'check', 'green'], ['قيمة المكتملة', Number(data.completed_value) + ' ج.م', 'money', 'brand'],
  ]));
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
