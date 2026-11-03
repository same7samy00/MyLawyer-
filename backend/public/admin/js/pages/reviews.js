async function reviewsPage(box) {
  const { data } = await api('GET', '/admin/reviews');
  const shown = applyFilters(data, (item) => item.created_at, (item) => (item.is_hidden ? 'hidden' : 'shown'));
  const average = data.length ? (sumOf(data, 'rating') / data.length).toFixed(1) : '0.0';
  box.append(summaryBar([
    ['كل التقييمات', data.length, 'review', 'brand'], ['متوسط التقييم', average + ' / 5', 'review', 'green'],
    ['تقييمات ضعيفة', data.filter((item) => item.rating <= 2).length, 'complaint', 'red'],
    ['مخفية', data.filter((item) => item.is_hidden).length, 'close', 'gray'],
  ]));
  box.append(guide('تظهر التقييمات في ملف المحامي فور إرسالها. أما بلاغات المحامين عن التقييمات فتظهر في صفحة بلاغات التقييمات.'));
  box.append(controlsBar([stateFilter([['', 'كل الحالات'], ['shown', 'ظاهر'], ['hidden', 'مخفي']]), ...dateFilters()]));
  box.append(table(['المحامي', 'التقييم', 'التعليق', 'رقم الطلب', 'الحالة', 'التاريخ'], shown.map((item) => ({
    item, cells: [item.lawyer_name, item.rating + ' / 5', item.comment, copyOr(item.order_number), item.is_hidden ? badge('مخفي', 'gray') : badge('ظاهر', 'green'), date(item.created_at)],
  })), (item) => open('order', item.order_id)));
}
