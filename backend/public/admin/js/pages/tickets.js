const TICKET_STATUS = { UNDER_REVIEW: ['تحت المراجعة', 'amber'], OPEN: ['مفتوحة', 'blue'], CLOSED: ['مغلقة', 'gray'] };
const TICKET_CATEGORY = { ORDER: 'مشكلة في طلب', MONEY: 'الأموال والمحفظة', ACCOUNT: 'الحساب', OTHER: 'أمور أخرى' };
const ticketStatus = (status) => badge(...(TICKET_STATUS[status] || [status, 'gray']));

/// Private images need the admin token, so they load through fetch
function privateImage(path) {
  const img = el('img', undefined, 'ticket-image');
  img.alt = 'صورة مرفقة';
  fetch(API + path, { headers: { Authorization: 'Bearer ' + session?.accessToken } })
    .then((res) => (res.ok ? res.blob() : null))
    .then((blob) => {
      if (!blob) return;
      img.src = URL.createObjectURL(blob);
      img.addEventListener('click', () => openImage(img.src, 'صورة مرفقة'));
    });
  return img;
}

const orderLink = (number) => {
  if (!number) return 'غير مربوطة بطلب';
  const node = el('span', undefined, 'order-link');
  node.append(el('span', 'مربوطة بطلب رقم '), copyable(number));
  return node;
};

const TICKET_TABS = [['UNDER_REVIEW', 'تنتظر الرد'], ['OPEN', 'مفتوحة'], ['CLOSED', 'مغلقة']];

async function ticketsPage(box) {
  const { data } = await api('GET', '/admin/support');
  const active = TICKET_TABS.some(([key]) => key === current.state) ? current.state : 'UNDER_REVIEW';
  const sided = current.side ? data.filter((item) => item.user_role === current.side) : data;
  box.append(tabs(TICKET_TABS.map(([key, label]) => [key, label, sided.filter((item) => item.status === key).length]), active, (key) => { current.state = key; render(); }));
  box.append(controlsBar([
    filterButtons([['', 'الكل'], ['client', 'الموكلون'], ['lawyer', 'المحامون']], current.side || '', (value) => { current.side = value; render(); }),
    ...dateFilters(),
  ]));
  const shown = applyFilters(sided.filter((item) => item.status === active), (item) => item.created_at);
  box.append(table(['رقم التذكرة', 'العنوان', 'النوع', 'صاحب التذكرة', 'الطلب', active === 'UNDER_REVIEW' ? 'تنتظر منذ' : 'آخر تحديث', 'الإجراءات'], shown.map((item) => ({
    item,
    cells: [
      copyable(item.reference), item.title, TICKET_CATEGORY[item.category] || item.category,
      personCell(item.user_name, (item.user_role === 'lawyer' ? 'محامٍ' : 'موكل') + ' • ' + item.user_phone), orderLink(item.order_number),
      active === 'UNDER_REVIEW' ? waitingTime(item.updated_at) : date(item.updated_at), openButton('فتح', 'ticket', item.id),
    ],
  })), (item) => open('ticket', item.id)));
}
