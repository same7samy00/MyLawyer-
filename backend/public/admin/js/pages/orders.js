async function ordersPage(box) {
  const q = current.search || '';
  const status = current.status || '';
  const res = await api('GET', '/admin/orders?q=' + encodeURIComponent(q) + '&status=' + status);
  const data = applyFilters(res.data, (item) => item.created_at);
  const count = (list) => data.filter((item) => list.includes(item.status)).length;

  box.append(summaryBar([
    ['الطلبات المعروضة', data.length, 'orders', 'brand'], ['قيمتها', sumOf(data, 'price') + ' ج.م', 'money', 'green'], ['طلبات جارية', count(['PENDING', 'ACCEPTED', 'ACTIVE']), 'ticket', 'blue'],
    ['طلبات مكتملة', count(['COMPLETED']), 'check', 'green'], ['ملغية أو منتهية', count(['CANCELLED', 'REJECTED', 'NO_RESPONSE', 'PAYMENT_EXPIRED', 'EXPIRED', 'REFUNDED']), 'close', 'red'],
  ]));
  box.append(guide('افتح الطلب لمراجعة مراحله وأطرافه، أو لتسويته ماليًا، أو لتجميد أتعابه.'));
  box.append(controlsBar([
    searchBox(q, 'ابحث برقم الطلب أو الاسم أو الهاتف', (value) => { current.search = value; render(); }),
    filterButtons([['', 'كل الحالات'], ...Object.entries(STATUS).map(([key, [label]]) => [key, label])], status,
      (value) => { current.status = value; render(); }),
    ...dateFilters(),
  ]));
  box.append(table(['رقم الطلب', 'الموكل', 'المحامي', 'المشكلة', 'المبلغ', 'الحالة', 'التاريخ'], data.map((item) => ({
    item, cells: [
      copyable(item.order_number), personCell(item.client_name, null, statsOf(item, 'client')),
      personCell(item.lawyer_name, null, statsOf(item, 'lawyer')), item.problem_type, item.price + ' ج.م', tag(item.status), date(item.created_at),
    ],
  })), (item) => open('order', item.id)));
}

async function orderPage(box) {
  const { data } = await api('GET', '/admin/orders/' + current.param);
  const { order } = data;
  pageHead('طلب ' + order.order_number);

  if (order.payout_status === 'FROZEN') box.append(frozenNote(order.payout_amount));

  const canSettle = order.status === 'ACTIVE' || ['HELD', 'FROZEN'].includes(order.payout_status);
  const settlement = canSettle ? await settlementParts(order.id) : null;
  const orderActions = [];
  if (settlement?.open) {
    const settle = (outcome) => (values) => api('POST', '/admin/orders/' + order.id + '/settle', { outcome, note: values.note });
    const noteStep = { key: 'note', type: 'text', label: 'ملاحظة القرار (اختيارية)', optional: true };
    const noteLine = (values) => [['قيمة الطلب', order.price + ' ج.م'], ...(values.note ? [['الملاحظة', values.note]] : [])];
    orderActions.push(
      { title: 'رد المبلغ إلى الموكل', description: 'يعيد قيمة الطلب كاملة إلى رصيد الموكل، ولا يأخذ المحامي شيئًا. ولا يمكن التراجع عن ذلك.', steps: [noteStep], success: 'تم تنفيذ القرار', danger: true, summary: noteLine, run: settle('REFUND') },
      { title: 'صرف الأتعاب للمحامي', description: 'يجعل أتعاب الطلب كاملة متاحة للمحامي ليسحبها. ولا يمكن التراجع عن ذلك.', steps: [noteStep], success: 'تم تنفيذ القرار', summary: noteLine, run: settle('LAWYER') });
  }
  if (['HELD', 'AVAILABLE', 'FROZEN'].includes(order.payout_status)) orderActions.push(freezeAction(order.id, order.payout_status === 'FROZEN'));

  const buttons = orderActions.length ? [actionButton(orderActions)] : [];
  data.tickets.filter((item) => item.status !== 'CLOSED').forEach((item) => buttons.push(link('تذكرة ' + item.reference, () => open('ticket', item.id), 'btn-primary', 'complaint')));
  box.append(hero(avatarBox(null, 'orders'), 'طلب ' + order.order_number, [statusRow('orders', 'حالة الطلب', tag(order.status))],
    [['orders', copyable(order.order_number)], ['calendar', 'تاريخ الطلب: ' + date(order.created_at)], ['money', order.price + ' ج.م']], buttons));

  box.append(summaryBar([
    ['السعر', order.price + ' ج.م', 'money', 'brand'], ['صافي المحامي', order.lawyer_amount + ' ج.م', 'lawyer', 'green'],
    ['نسبة المنصة', order.commission_percent + '%', 'price', 'blue'], ['الضريبة', order.tax_percent + '%', 'orders', 'amber'],
  ]));

  const list = [['summary', 'الملخص'], ['stages', 'المراحل', data.logs.length], ['money', 'الأموال', data.movements.length]];
  const active = list.some(([key]) => key === current.tab) ? current.tab : 'summary';
  box.append(tabs(list, active, (key) => { current.tab = key; render(); }));
  const pane = el('div', undefined, 'tab-content-pane');
  box.append(pane);

  if (active === 'summary') {
    pane.append(section('أطراف الطلب', parties(
      personCard('الموكل', order.client_name, order.client_phone, order.client_id, statsOf(order, 'client'), order.client_email, order.client_photo),
      personCard('المحامي', order.lawyer_name, order.lawyer_phone, order.lawyer_id, statsOf(order, 'lawyer'), order.lawyer_email, order.lawyer_photo))));
    pane.append(section('تفاصيل المشكلة', details([['المشكلة', order.problem_type], ['الوصف', order.problem_description]])));
    if (data.tickets.length) {
      pane.append(section('تذاكر الدعم الفني', table(['رقم التذكرة', 'العنوان', 'من', 'الحالة', 'التاريخ'], data.tickets.map((item) => ({
        item, cells: [copyable(item.reference), item.title, item.user_role === 'lawyer' ? 'المحامي' : 'الموكل', ticketStatus(item.status), date(item.created_at)],
      })), (item) => open('ticket', item.id))));
    }
    if (data.offers?.length) {
      pane.append(section('عروض الأسعار', table(['المحامي', 'السعر', 'صافي المحامي', 'الحالة', 'التاريخ'], data.offers.map((item) => ({
        item, cells: [item.lawyer_name, Number(item.price) + ' ج.م', Number(item.lawyer_amount) + ' ج.م',
          item.lawyer_id === order.lawyer_id ? 'العرض المختار' : item.withdrawn_at ? 'مسحوب' : 'لم يُختر', date(item.created_at)],
      })))));
    }
    if (data.reviews.length) {
      pane.append(section('التقييم', table(['التقييم', 'التعليق'], data.reviews.map((item) => ({ item, cells: [item.rating + ' / 5', item.comment] })))));
    }
    return;
  }

  if (active === 'stages') {
    pane.append(section('المواعيد', details([
      ['القبول', date(order.accepted_at)], ['الدفع', date(order.paid_at)], ['مهلة الوصول', date(order.arrival_deadline)], ['الوصول', date(order.arrived_at)], ['التأجيل', date(order.postponed_at)], ['الميعاد الجديد', date(order.postponed_until)], ['الإنهاء', date(order.completed_at)],
    ])));
    const timeline = el('ul', undefined, 'timeline');
    data.logs.forEach((log) => {
      const item = el('li');
      const actor = { client: 'الموكل', lawyer: 'المحامي', admin: 'الإدارة' }[log.actor_role] || 'النظام';
      item.append(el('strong', (STATUS[log.new_status] || [log.new_status])[0]), el('div', log.note, 'muted'), el('div', date(log.created_at) + ' • ' + actor, 'muted'));
      timeline.append(item);
    });
    pane.append(section('مراحل الطلب', data.logs.length ? timeline : el('p', 'لا توجد أحداث', 'muted')));
    return;
  }

  if (active === 'money') {
    if (settlement) pane.append(section('بيانات التسوية', settlement.facts));
    if (data.payment) {
      pane.append(section('الدفعة', details([
        ['رقم الدفعة', copyable(data.payment.reference)], ['المبلغ', Number(data.payment.amount) + ' ج.م'],
        ['الطريقة', badge(...(PAYMENT_METHODS[data.payment.method] || [data.payment.method, 'gray']))], ['تاريخ الدفع', date(data.payment.paid_at)],
      ])));
    }
    pane.append(section('حالة الأتعاب', details([
      ['حالة الأتعاب', PAYOUT[order.payout_status] || order.payout_status], ['صافي المحامي', Number(order.payout_amount ?? order.lawyer_amount ?? 0) + ' ج.م'],
    ])));
    const moveText = (item) => {
      const amount = Math.abs(Number(item.amount)) + ' ج.م';
      const who = item.account_name + ' (' + (item.account_role === 'lawyer' ? 'المحامي' : 'الموكل') + ')';
      return Number(item.amount) > 0 ? 'أُضيف ' + amount + ' إلى ' + who : 'خُصم ' + amount + ' من ' + who;
    };
    pane.append(section('الأموال التي تحركت في هذا الطلب', data.movements.length
      ? table(['ماذا حدث؟', 'السبب', 'من نفذها؟', 'متى؟'], data.movements.map((item) => ({
        item, cells: [
          el('strong', moveText(item), Number(item.amount) > 0 ? 'text-success' : 'text-danger'), item.reason,
          item.created_by ? 'الإدارة' : 'النظام تلقائيًا', date(item.created_at),
        ],
      })))
      : el('p', 'لم تتحرك أي أموال على هذا الطلب حتى الآن.', 'muted')));
    pane.append(section('سجل التجميد', table(['التاريخ', 'الإجراء', 'المبلغ', 'السبب', 'بواسطة'], data.events.map((item) => ({
      item, cells: [date(item.created_at), badge(...(PAYOUT_ACTIONS[item.action] || [item.action, 'gray'])), Number(item.amount) + ' ج.م', item.reason, item.created_by || 'تلقائي من النظام'],
    })))));
    return;
  }

}
