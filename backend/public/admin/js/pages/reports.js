async function reportsPage(box) {
  const { data } = await api('GET', '/admin/reviews/reported');
  const found = data.filter((item) => matchesSearch(item, ['lawyer_name', 'comment', 'report_reason']));
  const shown = applyFilters(found, (item) => item.reported_at, () => '');
  box.append(summaryBar([
    ['بلاغات مفتوحة', data.length, 'review', 'blue'],
    ['اليوم', data.filter((item) => dayText(0, new Date(item.reported_at)) === dayText(0)).length, 'calendar', 'amber'],
    ['آخر 7 أيام', data.filter((item) => new Date(item.reported_at) > Date.now() - 7 * 86400000).length, 'calendar', 'brand'],
  ]));
  box.append(guide('تظهر هنا التعليقات التي أبلغ عنها المحامون في تقييماتهم.', 'افتح البلاغ لتقرر إخفاء التعليق أو إبقاءه.'));
  box.append(controlsBar([
    searchBox(current.search, 'ابحث باسم المحامي أو التعليق أو سبب البلاغ', (value) => { current.search = value; render(); }),
    ...dateFilters(),
  ]));
  box.append(table(['المحامي', 'التقييم', 'التعليق', 'سبب البلاغ', 'التاريخ', 'الإجراءات'], shown.map((item) => ({
    item,
    cells: [personCell(item.lawyer_name), item.rating + ' / 5', item.comment || '-', item.report_reason || '-', date(item.reported_at), openButton('فتح', 'reviewReport', item.id)],
  })), (item) => open('reviewReport', item.id)));
}

async function reviewReportPage(box) {
  const { data } = await api('GET', '/admin/reviews/reported');
  const item = data.find((row) => String(row.id) === current.param);
  if (!item) {
    box.append(section('بلاغ عن تقييم', el('p', 'تم الفصل في هذا البلاغ أو لم يعد موجودًا.', 'muted')));
    return;
  }
  const moderate = (hide) => decideAndReturn(() => api('POST', '/admin/reviews/' + item.id + '/moderate', { hide }));

  box.append(hero(avatarBox(null, 'review'), 'بلاغ عن تقييم', [statusRow('complaint', 'حالة البلاغ', badge('مفتوح', 'amber'))],
    [['lawyer', item.lawyer_name], ['calendar', date(item.reported_at)]], [actionButton([
      {
        title: 'إبقاء التعليق', description: 'يغلق البلاغ ويبقى التعليق ظاهرًا في ملف المحامي.', steps: [], success: 'تم إبقاء التعليق',
        summary: () => [['التعليق', item.comment || 'دون تعليق']], run: () => moderate(false),
      },
      {
        title: 'إخفاء التعليق', description: 'يحذف التعليق من ملف المحامي.', steps: [], success: 'تم إخفاء التعليق', danger: true,
        summary: () => [['التعليق', item.comment || 'دون تعليق']], run: () => moderate(true),
      },
    ])]));
  box.append(section('سبب البلاغ', el('p', item.report_reason || '-')));
  box.append(section('التقييم', details([['التقييم', item.rating + ' / 5'], ['التعليق', item.comment || 'دون تعليق']])));
}
