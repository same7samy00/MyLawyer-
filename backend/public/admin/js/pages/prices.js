async function pricesPage(box) {
  const [prices, tax, consultationTiles] = await Promise.all([api('GET', '/admin/prices'), api('GET', '/admin/tax'), consultationSettingsTiles()]);

  const list = prices.data;
  const average = list.length ? (sumOf(list, 'commission_percent') / list.length).toFixed(1) : '0';
  box.append(summaryBar([
    ['عدد الخدمات', list.length, 'orders', 'brand'], ['متوسط نسبة المنصة', average + '%', 'price', 'blue'],
    ['نسبة الضريبة', tax.data.percent + '%', 'money', 'amber'],
    ['أقل وأعلى سعر', list.length ? Math.min(...list.map((item) => Number(item.min_price))) + ' - ' + Math.max(...list.map((item) => Number(item.max_price))) + ' ج.م' : '-', 'money', 'green'],
  ]));

  const percent = input('', 'النسبة %', 'small');
  percent.type = 'number';
  const taxInput = input(tax.data.percent, '', 'small');
  taxInput.type = 'number';

  box.append(table(['الخدمة', 'من', 'إلى', 'نسبة المنصة %'], list.map((item) => ({
    item, cells: [el('strong', item.problem_type, 'prod-name-ar'), Number(item.min_price) + ' ج.م', Number(item.max_price) + ' ج.م', Number(item.commission_percent) + '%'],
  }))));

  const min = input('', 'أقل سعر', 'small');
  const max = input('', 'أعلى سعر', 'small');
  const commission = input('', 'نسبة المنصة %', 'small');
  [min, max, commission].forEach((node) => { node.type = 'number'; });
  const fill = (name) => {
    const item = list.find((row) => row.problem_type === name);
    if (!item) return;
    min.value = Number(item.min_price);
    max.value = Number(item.max_price);
    commission.value = Number(item.commission_percent);
  };
  const service = filterSelect(list.map((item) => [item.problem_type, item.problem_type]), list[0]?.problem_type || '', fill, 'orders');
  fill(list[0]?.problem_type);

  box.append(guide('تُخصم الضريبة من السعر أولًا، ثم تُحسب نسبة المنصة من الصافي. وتُطبَّق التغييرات على الطلبات الجديدة فقط.'));
  box.append(actionsSection([
    actionTile('تعديل سعر خدمة', 'يغير أقل سعر وأعلى سعر ونسبة المنصة للخدمة التي تختارها.', service, min, max, commission,
      button('حفظ', 'btn-primary', () => api('PUT', '/admin/prices', {
        problemType: service.querySelector('select').value, minPrice: Number(min.value), maxPrice: Number(max.value), commissionPercent: Number(commission.value),
      }))),
    actionTile('نسبة المنصة لكل الخدمات', 'يطبق النسبة التي تكتبها على كل الخدمات مرة واحدة.', percent,
      button('تطبيق', 'btn-primary', confirmed('هل تريد تطبيق هذه النسبة على كل الخدمات؟', () => api('POST', '/admin/commission', { percent: Number(percent.value) })))),
    actionTile('نسبة الضريبة', 'يغير نسبة الضريبة التي تُخصم من سعر كل طلب جديد.', taxInput,
      button('حفظ', 'btn-primary', confirmed('هل تريد تغيير نسبة الضريبة؟', () => api('POST', '/admin/tax', { percent: Number(taxInput.value) })))),
    ...consultationTiles,
  ]));
}
