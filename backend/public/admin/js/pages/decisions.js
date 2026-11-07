const ADMIN_ACTIONS = {
  ACCOUNT_SUSPEND: ['إيقاف حساب', 'red'], ACCOUNT_ACTIVATE: ['تفعيل حساب', 'green'],
  PRICE_UPDATE: ['تعديل سعر خدمة', 'blue'], COMMISSION_UPDATE: ['تعديل نسبة المنصة', 'blue'], TAX_UPDATE: ['تعديل الضريبة', 'blue'],
  LAWYER_APPROVE: ['موافقة على محامٍ', 'green'], LAWYER_REJECT: ['رفض محامٍ', 'red'],
  REVIEW_HIDE: ['إخفاء تعليق', 'red'], REVIEW_KEEP: ['إبقاء تعليق', 'green'],
  CONSULTATION_SETTINGS: ['إعدادات الاستشارة السريعة', 'blue'],
};

/// Who decided what on the control page
async function decisionsPage(box) {
  const { data } = await api('GET', '/admin/actions');
  const found = data.filter((item) => matchesSearch(item, ['target_label', 'details', 'created_by']));
  const shown = applyFilters(found, (item) => item.created_at);
  box.append(summaryBar([['كل القرارات', data.length, 'orders', 'brand'], ['في الفترة المختارة', shown.length, 'calendar', 'blue']]));
  box.append(controlsBar([
    searchBox(current.search, 'ابحث بالاسم أو التفاصيل أو من اتخذ القرار', (value) => { current.search = value; render(); }),
    ...dateFilters(),
  ]));
  box.append(guide('كل قرار اتخذته الإدارة في اللوحة: إيقاف الحسابات، والأسعار والنسب، وطلبات المحامين، والتعليقات.'));
  box.append(table(['القرار', 'على', 'التفاصيل', 'من اتخذه؟', 'متى؟'], shown.map((item) => ({
    item,
    cells: [badge(...(ADMIN_ACTIONS[item.action] || [item.action, 'gray'])), item.target_label || '-', item.details || '-', item.created_by || '-', date(item.created_at)],
  })), (item) => { if (item.target_user_id) open('user', item.target_user_id); }));
}
