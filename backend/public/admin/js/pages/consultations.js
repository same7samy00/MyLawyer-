const CONSULTATION_STATUS = { PAID: ['تنتظر الاتصال', 'amber'], CONTACTING: ['جارٍ التواصل', 'blue'], DONE: ['تمت', 'green'], REJECTED: ['مرفوضة ومستردة', 'red'] };
const CONSULTATION_KIND = { CALL: 'استشارة هاتفية', PAPERS: 'اطلاع على مستندات واستشارة' };
const consultationStatus = (status) => badge(...(CONSULTATION_STATUS[status] || [status, 'gray']));
/// حالة التواصل: الفريق بعت «لم نتمكن من الوصول»، أو الموكل طلب التواصل
function contactState(item) {
  const open = item.status === 'PAID' || item.status === 'CONTACTING';
  if (!open) return consultationStatus(item.status);
  if (item.callback_requested_at) return badge('الموكل طلب التواصل', 'green');
  if (item.unreachable_at) return badge('ننتظر طلب الموكل', 'amber');
  return consultationStatus(item.status);
}
const CONSULTATION_TABS = [['WAITING', 'تنتظر الاتصال'], ['CONTACTING', 'جارٍ التواصل'], ['DONE', 'تمت'], ['REJECTED', 'مرفوضة']];
const inConsultationTab = (item, tab) => (tab === 'WAITING' ? item.status === 'PAID' : item.status === tab);

/// «استشارة سريعة»: طلبات مدفوعة تنتظر اتصال الفريق بالموكل
async function consultationsPage(box) {
  const { data } = await api('GET', '/admin/consultations');
  const active = CONSULTATION_TABS.some(([key]) => key === current.state) ? current.state : 'WAITING';
  box.append(summaryBar([
    ['كل الاستشارات', data.length, 'phone', 'brand'],
    ['تنتظر الاتصال', data.filter((item) => item.status === 'PAID').length, 'calendar', 'amber'],
    ['تمت', data.filter((item) => item.status === 'DONE').length, 'check', 'green'],
    ['إيراد الاستشارات', sumOf(data.filter((item) => item.status !== 'REJECTED'), 'price') + ' ج.م', 'money', 'blue'],
  ]));
  box.append(tabs(CONSULTATION_TABS.map(([key, label]) => [key, label, data.filter((item) => inConsultationTab(item, key)).length]), active, (key) => { current.state = key; render(); }));
  box.append(controlsBar([
    searchBox(current.search, 'ابحث برقم الاستشارة أو اسم الموكل أو هاتفه', (value) => { current.search = value; render(); }),
    ...dateFilters(),
  ]));
  box.append(guide('اتصل بالموكل من رقم الشركة، ثم غيّر الحالة إلى «جارٍ التواصل» وبعد المكالمة إلى «تمت». الرفض يعيد المبلغ كاملًا إلى رصيد الموكل.'));
  const shown = applyFilters(data.filter((item) => inConsultationTab(item, active) && matchesSearch(item, ['reference', 'client_name', 'client_phone'])), (item) => item.created_at);
  box.append(table(['رقم الاستشارة', 'الموكل', 'النوع', 'المبلغ', active === 'WAITING' ? 'تنتظر منذ' : 'التاريخ', 'الحالة', 'الإجراءات'], shown.map((item) => ({
    item,
    cells: [
      copyable(item.reference), personCell(item.client_name, item.client_phone),
      CONSULTATION_KIND[item.kind] + (item.kind === 'PAPERS' ? ' • ' + item.pages + ' ورقة' : ''), Number(item.price) + ' ج.م',
      active === 'WAITING' ? waitingTime(item.created_at) : date(item.created_at), contactState(item), openButton('فتح', 'consultation', item.id),
    ],
  })), (item) => open('consultation', item.id)));
}

function consultationActions(data) {
  const move = (status, title, description, success, extraSteps = []) => ({
    title, description, success, danger: status === 'REJECTED', steps: extraSteps,
    summary: (values) => [['الإجراء', title], ...(values.reason ? [['السبب', values.reason]] : []), ...(values.note ? [['ملاحظة', values.note]] : [])],
    run: (values) => api('POST', '/admin/consultations/' + data.id + '/status', { status, reason: values.reason, note: values.note }),
  });
  const note = { key: 'note', type: 'long', label: 'ملاحظة داخلية عن المكالمة (اختياري)', optional: true };
  const list = [];
  if (data.status === 'PAID') list.push(move('CONTACTING', 'بدء التواصل', 'يعرف الموكل أن الفريق يتصل به الآن.', 'تم تغيير الحالة إلى جارٍ التواصل'));
  list.push({
    title: 'لم نتمكن من الوصول', description: 'يصل الموكل تنبيه: لما تكون متاح افتح الطلب واضغط «طلب التواصل».', success: 'تم إرسال التنبيه للموكل', steps: [],
    summary: () => [['الإجراء', 'تنبيه «لم نتمكن من الوصول إليك»'], ['الموكل', data.client_name + ' • ' + data.client_phone]],
    run: () => api('POST', '/admin/consultations/' + data.id + '/unreachable', {}),
  });
  list.push(move('DONE', 'تمت الاستشارة', 'تُغلق الاستشارة بعد انتهاء المكالمة.', 'تم إغلاق الاستشارة', [note]));
  list.push(move('REJECTED', 'رفض واسترداد', 'يعيد المبلغ كاملًا إلى رصيد الموكل ويرسل له السبب.', 'تم الرفض واسترداد المبلغ', [REASON_STEP]));
  return list;
}

async function consultationPage(box) {
  const { data } = await api('GET', '/admin/consultations/' + current.param);
  const open_ = data.status === 'PAID' || data.status === 'CONTACTING';
  pageHead('استشارة ' + data.reference);
  const buttons = open_ ? [actionButton(consultationActions(data))] : [];
  buttons.push(link('اتصال', () => { location.href = 'tel:' + data.client_phone; }, 'btn-outline', 'phone'));
  buttons.push(link(data.client_name, () => open('user', data.client_id), 'btn-outline', 'open'));
  box.append(hero(avatarBox(data.client_photo, 'phone'), CONSULTATION_KIND[data.kind],
    [statusRow('ticket', 'الحالة', contactState(data)), statusRow('money', 'المبلغ', badge(Number(data.price) + ' ج.م', 'purple'))],
    [['client', data.client_name + ' • ' + data.client_phone], ['calendar', date(data.created_at)], ['ticket', copyable(data.reference)]], buttons));

  const layout = el('div', undefined, 'ticket-layout');
  const main = el('div', undefined, 'ticket-main');
  const side = el('div', undefined, 'ticket-side');
  layout.append(main, side);
  box.append(layout);

  const text = el('p', data.details, 'consultation-details');
  text.style.whiteSpace = 'pre-wrap';
  main.append(section('تفاصيل المشكلة', text));
  if (data.page_links.length) {
    const gallery = el('div', undefined, 'ticket-images');
    gallery.append(...data.page_links.map((path) => privateImage(path)));
    main.append(section('صور المستندات (' + data.page_links.length + ')', gallery));
  }

  side.append(section('بيانات الدفع', details([
    ['طريقة الدفع', data.payment_method === 'WALLET' ? 'من رصيد الموكل' : 'دفع مباشر'], ['المبلغ', Number(data.price) + ' ج.م'],
    ['عدد المستندات', data.kind === 'PAPERS' ? data.pages : 'لا يوجد'],
    ['طريقة الإدخال', data.input_method === 'VOICE' ? 'كلام مسجّل (اتحول لنص تلقائيًا، وممكن فيه أخطاء)' : 'كتابة'],
  ])));
  side.append(section('المتابعة', details([
    ['بدء التواصل', data.contacted_at ? date(data.contacted_at) : '-'],
    ['تنبيه لم نتمكن من الوصول', data.unreachable_at ? date(data.unreachable_at) : '-'], ['طلب الموكل التواصل', data.callback_requested_at ? date(data.callback_requested_at) : '-'],
    ['الإغلاق', data.closed_at ? date(data.closed_at) : '-'],
    ['المسؤول', data.handled_by_email || '-'], ['ملاحظة داخلية', data.admin_note || '-'], ...(data.reject_reason ? [['سبب الرفض', data.reject_reason]] : []),
  ])));
}

/// إعدادات الاستشارة داخل صفحة الأسعار
async function consultationSettingsTiles() {
  const { data } = await api('GET', '/admin/consultation-settings');
  // كل خانة فوقها اسمها، عشان الاسم يفضل باين بعد ما الرقم يتكتب
  const field = (value, placeholder) => {
    const node = input(value, placeholder, 'small');
    node.type = 'number';
    const wrap = el('label', undefined, 'labeled-field');
    wrap.style.display = 'grid';
    wrap.style.gap = '4px';
    wrap.append(el('span', placeholder, 'muted'), node);
    return Object.assign(wrap, { input: node });
  };
  const callPrice = field(data.callPrice, 'سعر الاستشارة');
  const base = field(data.papersBasePrice, 'سعر الاطلاع الأساسي');
  const page = field(data.pagePrice, 'سعر الورقة');
  const maxPages = field(data.maxPages, 'أقصى عدد أوراق');
  const minutes = field(data.callMinutes, 'مدة المكالمة بالدقائق');
  const minChars = field(data.minDetailsChars, 'أقل عدد أحرف للتفاصيل');
  const isOpen = filterSelect([['true', 'الخدمة متاحة'], ['false', 'الخدمة متوقفة']], String(data.isOpen), () => {}, 'power');
  const save = () => api('PUT', '/admin/consultation-settings', {
    callPrice: Number(callPrice.input.value), papersBasePrice: Number(base.input.value), pagePrice: Number(page.input.value), maxPages: Number(maxPages.input.value),
    callMinutes: Number(minutes.input.value), minDetailsChars: Number(minChars.input.value), isOpen: isOpen.querySelector('select').value === 'true',
  });
  return [
    actionTile('أسعار الاستشارة السريعة', 'سعر الاستشارة الهاتفية، وسعر الاطلاع الأساسي، وسعر كل ورقة. تُطبَّق على الاستشارات الجديدة فقط.', callPrice, base, page,
      button('حفظ', 'btn-primary', confirmed('هل تريد حفظ أسعار الاستشارة؟', save))),
    actionTile('شروط الاستشارة السريعة', 'أقصى عدد أوراق، ومدة المكالمة، وأقل طول لتفاصيل المشكلة، وإتاحة الخدمة.', maxPages, minutes, minChars, isOpen,
      button('حفظ', 'btn-primary', confirmed('هل تريد حفظ شروط الاستشارة؟', save))),
  ];
}
