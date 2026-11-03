async function ticketPage(box) {
  const { data } = await api('GET', '/admin/support/' + current.param);
  const closed = data.status === 'CLOSED';
  pageHead('تذكرة ' + data.reference);

  if (data.order?.payout_status === 'FROZEN') box.append(frozenNote(data.order.payout_amount));

  const buttons = closed ? [] : [
    actionButton(ticketActions(data)),
    link('الشات', () => openChat(data), 'btn-outline', 'appeal'),
  ];
  buttons.push(link(data.user_name, () => open('user', data.user_id), 'btn-outline', 'open'));
  if (data.order) buttons.push(link('الطلب', () => open('order', data.order.id), 'btn-outline', 'orders'));
  box.append(hero(avatarBox(null, 'complaint'), data.title, [statusRow('ticket', 'حالة التذكرة', ticketStatus(data.status)), statusRow('note', 'نوع التذكرة', badge(TICKET_CATEGORY[data.category] || data.category, 'purple'))],
    [[data.user_role === 'lawyer' ? 'lawyer' : 'client', data.user_name + ' • ' + data.user_phone], ['calendar', date(data.created_at)],
      ['ticket', copyable(data.reference)], ...(data.order ? [['orders', orderLink(data.order.order_number)]] : [])], buttons));

  const layout = el('div', undefined, 'ticket-layout');
  const main = el('div', undefined, 'ticket-main');
  const side = el('div', undefined, 'ticket-side');
  layout.append(main, side);
  box.append(layout);

  const thread = el('div', undefined, 'ticket-thread');
  thread.append(...data.messages.map((message) => messageCard(message, data)));
  main.append(section('الرسائل', thread));

  if (data.order) {
    side.append(section('أطراف الطلب', parties(
      personCard('الموكل', data.order.client_name, data.order.client_phone, data.order.client_id, undefined, undefined, data.order.client_photo),
      personCard('المحامي', data.order.lawyer_name, data.order.lawyer_phone, data.order.lawyer_id, undefined, undefined, data.order.lawyer_photo))));
    if (data.order.payout_status) {
      side.append(section('حالة الأموال', details([
        ['حالة الأتعاب', PAYOUT[data.order.payout_status] || data.order.payout_status], ['صافي المحامي', Number(data.order.payout_amount || 0) + ' ج.م'],
      ])));
    }
  }

  if (closed) {
    main.append(section('حالة التذكرة', el('p', 'أُغلقت التذكرة في ' + date(data.closed_at) + (data.closed_by_email ? ' بواسطة ' + data.closed_by_email : '') + '، ولا يمكن الرد عليها.', 'muted')));
  }
}

function frozenNote(amount) {
  const box = el('div', undefined, 'system-alert');
  const body = el('div');
  body.append(el('strong', 'تنبيه من النظام'), el('p', 'أموال هذه العملية مجمدة ومعلقة (' + Number(amount || 0) + ' ج.م)، ولا يستطيع المحامي سحبها حتى يُفك التجميد أو تُنفَّذ تسوية.'));
  box.append(icon('complaint'), body);
  return box;
}
