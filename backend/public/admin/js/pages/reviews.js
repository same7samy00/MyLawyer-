async function reviewsPage(box) {
  const { data } = await api('GET', '/admin/reviews');
  const found = data.filter((item) => matchesSearch(item, ['lawyer_name', 'comment', 'order_number']));
  const shown = applyFilters(found, (item) => item.created_at, (item) => (item.is_hidden ? 'hidden' : 'shown'));
  const average = data.length ? (sumOf(data, 'rating') / data.length).toFixed(1) : '0.0';
  box.append(summaryBar([
    ['كل التقييمات', data.length, 'review', 'brand'], ['متوسط التقييم', average + ' / 5', 'review', 'green'],
    ['تقييمات ضعيفة', data.filter((item) => item.rating <= 2).length, 'complaint', 'red'],
    ['مخفية', data.filter((item) => item.is_hidden).length, 'close', 'gray'],
  ]));
  box.append(guide('تظهر التقييمات في ملف المحامي فور إرسالها. أما بلاغات المحامين عن التقييمات فتظهر في صفحة بلاغات التقييمات.'));
  box.append(controlsBar([
    searchBox(current.search, 'ابحث باسم المحامي أو التعليق أو رقم الطلب', (value) => { current.search = value; render(); }),
    stateFilter([['', 'كل الحالات'], ['shown', 'ظاهر'], ['hidden', 'مخفي']]),
    ...dateFilters(),
  ]));
  box.append(table(['المحامي', 'التقييم', 'التعليق', 'رقم الطلب', 'الحالة', 'التاريخ'], shown.map((item) => ({
    item, cells: [item.lawyer_name, item.rating + ' / 5', item.comment, copyOr(item.order_number), item.is_hidden ? badge('مخفي', 'gray') : badge('ظاهر', 'green'), date(item.created_at)],
  })), (item) => open('review', item.id)));
}

/// تقييم واحد: النجوم والتعليق وطرفا الطلب، والإخفاء أو الإظهار، ولينك للطلب
async function reviewPage(box) {
  const { data } = await api('GET', '/admin/reviews');
  const item = data.find((row) => String(row.id) === current.param);
  if (!item) {
    box.append(empty('التقييم غير موجود', 'ربما حُذف أو لم يعد ضمن آخر التقييمات.'));
    return;
  }
  pageHead('تقييم ' + item.rating + ' / 5');
  const moderate = (hide) => api('POST', '/admin/reviews/' + item.id + '/moderate', { hide });
  const buttons = [actionButton([item.is_hidden
    ? { title: 'إظهار التعليق', description: 'يعيد التعليق إلى ملف المحامي.', steps: [], success: 'تم إظهار التعليق', summary: () => [['التعليق', item.comment || 'دون تعليق']], run: () => moderate(false) }
    : { title: 'إخفاء التعليق', description: 'يحذف التعليق من ملف المحامي.', steps: [], success: 'تم إخفاء التعليق', danger: true, summary: () => [['التعليق', item.comment || 'دون تعليق']], run: () => moderate(true) }])];
  buttons.push(link('الطلب', () => open('order', item.order_id), 'btn-outline', 'orders'));
  buttons.push(link(item.lawyer_name, () => open('user', item.lawyer_id), 'btn-outline', 'open'));
  box.append(hero(avatarBox(null, 'review'), '★'.repeat(item.rating) + '☆'.repeat(5 - item.rating),
    [statusRow('review', 'الحالة', item.is_hidden ? badge('مخفي', 'gray') : badge('ظاهر', 'green'))],
    [['lawyer', item.lawyer_name], ['client', item.client_name + ' • ' + item.client_phone], ['calendar', date(item.created_at)], ['orders', copyOr(item.order_number)]], buttons));
  const text = el('p', item.comment || 'لم يكتب الموكل تعليقًا.');
  text.style.whiteSpace = 'pre-wrap';
  box.append(section('التعليق', text));
  if (item.reported_at) box.append(section('بلاغ المحامي', details([['التاريخ', date(item.reported_at)], ['السبب', item.report_reason || '-']])));
}
