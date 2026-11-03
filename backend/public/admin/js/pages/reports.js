async function reportsPage(box) {
  const { data } = await api('GET', '/admin/reviews/reported');
  const shown = applyFilters(data, (item) => item.reported_at, () => '');
  box.append(summaryBar([['بلاغات مفتوحة', data.length, 'review', 'blue']]));
  box.append(guide('تظهر هنا التعليقات التي أبلغ عنها المحامون في تقييماتهم.', 'افتح البلاغ لتقرر إخفاء التعليق أو إبقاءه.'));
  box.append(controlsBar([...dateFilters()]));
  box.append(table(['المحامي', 'التقييم', 'التعليق', 'سبب البلاغ', 'التاريخ', 'الإجراءات'], shown.map((item) => ({
    item,
    cells: [personCell(item.lawyer_name), item.rating + ' / 5', item.comment || '-', item.report_reason || '-', date(item.reported_at), openButton('فتح', 'reviewReport', item)],
  })), (item) => open('reviewReport', item)));
}

async function reviewReportPage(box) {
  const item = current.param;
  const moderate = (hide) => decideAndReturn(() => api('POST', '/admin/reviews/' + item.id + '/moderate', { hide }));

  box.append(hero(avatarBox(null, 'review'), 'بلاغ عن تقييم', [badge('مفتوح', 'amber')],
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
