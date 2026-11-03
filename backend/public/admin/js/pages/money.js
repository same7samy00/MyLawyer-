const PAYOUT_ACTIONS = { FREEZE: ['تجميد', 'red'], UNFREEZE: ['فك التجميد', 'green'], SETTLE: ['تسوية', 'blue'] };

function waitingTime(value) {
  if (!value) return 'غير مسجل';
  const hours = Math.floor((Date.now() - new Date(value)) / 3600000);
  if (hours < 1) return 'أقل من ساعة';
  return hours < 24 ? hours + ' ساعة' : Math.floor(hours / 24) + ' يوم';
}

const PAYMENT_METHODS = { WALLET: ['من الرصيد', 'blue'], DIRECT: ['دون بوابة دفع', 'amber'] };

function paymentState(item) {
  return item.order_status === 'REFUNDED' || item.payout_status === 'REFUNDED' ? badge('مردودة', 'purple') : badge('مدفوعة', 'green');
}

/// One line per client payment, with the numbers ready to copy
function paymentsTable(list, withClient) {
  const headers = ['رقم الدفعة', 'رقم الطلب', ...(withClient ? ['الموكل'] : []), 'المبلغ', 'الطريقة', 'الحالة', 'التاريخ'];
  return table(headers, list.map((item) => ({
    item,
    cells: [
      copyable(item.reference), copyable(item.order_number), ...(withClient ? [personCell(item.client_name, item.client_phone)] : []),
      el('strong', Number(item.amount) + ' ج.م'), badge(...(PAYMENT_METHODS[item.method] || [item.method, 'gray'])), paymentState(item), date(item.paid_at),
    ],
  })), (item) => open('order', item.order_id));
}

/// Every pound in one place: what is frozen, what moved, and the freeze history
async function moneyPage(box) {
  const params = new URLSearchParams();
  if (current.from) params.set('from', current.from);
  if (current.to) params.set('to', current.to);
  const { data } = await api('GET', '/admin/money?' + params);
  const pounds = (value) => Number(value) + ' ج.م';

  box.append(summaryBar([
    ['مدفوعات الموكلين', pounds(data.totals.paid), 'orders', 'brand'], ['مجمدة', pounds(data.totals.frozen), 'power', 'red'], ['محجوزة 24 ساعة', pounds(data.totals.held), 'calendar', 'amber'],
    ['مضافة', pounds(data.totals.added), 'money', 'green'], ['مخصومة', pounds(data.totals.deducted), 'money', 'red'],
  ]));

  const list = [['frozen', 'المجمدة', data.frozen.length], ['payments', 'المدفوعات', data.payments.length], ['movements', 'الحركات', data.movements.length], ['events', 'سجل التجميد', data.events.length]];
  const active = list.some(([key]) => key === current.tab) ? current.tab : 'frozen';
  box.append(tabs(list, active, (key) => { current.tab = key; render(); }));

  if (active === 'frozen') {
    box.append(guide('هذه الأموال لا يستطيع المحامي سحبها. افتح العملية لتتخذ القرار. وتظهر الأقدم أولًا.'));
    box.append(table(['رقم الطلب', 'المبلغ', 'المحامي', 'الموكل', 'سبب التجميد', 'مجمدة منذ', 'الإجراءات'], data.frozen.map((item) => ({
      item,
      cells: [
        copyable(item.order_number), el('strong', pounds(item.payout_amount), 'text-danger'), item.lawyer_name, item.client_name,
        item.reason || 'غير مسجل', waitingTime(item.frozen_at),
        item.ticket_id ? openButton('فتح', 'ticket', item.ticket_id) : openButton('فتح', 'order', item.order_id),
      ],
    })), (item) => (item.ticket_id ? open('ticket', item.ticket_id) : open('order', item.order_id))));
    return;
  }

  box.append(guide(active === 'payments'
    ? 'كل دفعة دفعها موكل برقمها وطريقتها. اضغط على الرقم لنسخه، أو على السطر لفتح الطلب.'
    : active === 'movements'
    ? 'كل مبلغ أُضيف إلى رصيد أي حساب أو خُصم منه، مع سببه ومن نفذه. اضغط على سطر لفتح الحساب.'
    : 'كل مرة جُمدت فيها أتعاب طلب أو فُك تجميدها أو سُويت، ومن قام بذلك. اضغط على سطر لفتح الطلب.'));
  box.append(controlsBar([
    ...(active === 'payments' ? [
      searchBox(current.search, 'ابحث برقم الدفعة أو الطلب أو الموكل', (value) => { current.search = value; render(); }),
      filterButtons([['', 'كل الطرق'], ['WALLET', 'من الرصيد'], ['DIRECT', 'دون بوابة دفع']], current.method || '', (value) => { current.method = value; render(); }),
    ] : []),
    ...(active === 'movements' ? [
      searchBox(current.search, 'ابحث بالاسم أو رقم الطلب أو السبب', (value) => { current.search = value; render(); }),
      stateFilter([['', 'كل الحركات'], ['add', 'إضافة'], ['deduct', 'خصم']]),
    ] : []),
    ...dateFilters(),
  ]));

  if (active === 'payments') {
    const q = (current.search || '').toLowerCase();
    const shown = data.payments.filter((item) => (!current.method || item.method === current.method) &&
      (!q || [item.reference, item.order_number, item.client_name, item.client_phone].some((text) => (text || '').toLowerCase().includes(q))));
    box.append(paymentsTable(shown, true));
    return;
  }

  if (active === 'movements') {
    const q = (current.search || '').toLowerCase();
    const shown = data.movements.filter((item) =>
      (!current.state || (current.state === 'add') === (Number(item.amount) > 0)) &&
      (!q || [item.account_name, item.order_number, item.reason].some((text) => (text || '').toLowerCase().includes(q))));
    box.append(table(['التاريخ', 'النوع', 'المبلغ', 'الحساب', 'السبب', 'رقم الطلب', 'بواسطة'], shown.map((item) => ({
      item,
      cells: [
        date(item.created_at), Number(item.amount) > 0 ? badge('إضافة', 'green') : badge('خصم', 'red'), money(item.amount),
        personCell(item.account_name, item.account_role === 'lawyer' ? 'محامٍ' : 'موكل'), item.reason, copyOr(item.order_number), item.created_by || 'النظام',
      ],
    })), (item) => open('user', item.user_id)));
    return;
  }

  box.append(table(['التاريخ', 'الإجراء', 'المبلغ', 'رقم الطلب', 'السبب', 'بواسطة'], data.events.map((item) => ({
    item,
    cells: [
      date(item.created_at), badge(...(PAYOUT_ACTIONS[item.action] || [item.action, 'gray'])), pounds(item.amount),
      copyable(item.order_number), item.reason, item.created_by || 'تلقائي من النظام',
    ],
  })), (item) => open('order', item.order_id)));
}
