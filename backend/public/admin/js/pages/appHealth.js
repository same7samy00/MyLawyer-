/// The installed app: the oldest version still served, and the crashes phones reported in the last 30 days
async function appHealthPage(box) {
  const [version, errors] = await Promise.all([api('GET', '/admin/app-version'), api('GET', '/admin/app-errors')]);
  const list = errors.data.filter((item) => matchesSearch(item, ['message', 'platforms']));
  const shown = applyFilters(list, (item) => item.last_at);

  box.append(summaryBar([
    ['أقل نسخة مسموحة', version.data.minBuild || 'الكل مسموح', 'power', 'brand'],
    ['أعطال مختلفة', errors.data.length, 'complaint', 'red'],
    ['مرات الحدوث', sumOf(errors.data, 'times'), 'orders', 'amber'],
    ['مستخدمون تأثروا', sumOf(errors.data, 'people'), 'client', 'blue'],
  ]));

  const build = input(version.data.minBuild, 'رقم النسخة', 'small');
  build.type = 'number';
  build.min = '0';
  // 0 is a real value here: every version is allowed
  build.value = String(version.data.minBuild);
  const url = input(version.data.updateUrl || '', 'رابط صفحة التطبيق في المتجر (https)');
  box.append(guide(
    'أي تطبيق نسخته أقدم من الرقم المكتوب هنا تظهر له صفحة «حدّث التطبيق» ولا يعمل حتى يحدّث.',
    'اكتب 0 للسماح بكل النسخ. رقم النسخة هو الرقم بعد علامة + في إصدار التطبيق.'
  ));
  box.append(actionsSection([
    actionTile('أقل نسخة مسموحة من التطبيق', 'يُلزم كل من يستخدم نسخة أقدم بالتحديث، ويفتح له الرابط المكتوب.', build, url,
      button('حفظ', 'btn-primary', confirmed('هل تريد إلزام النسخ الأقدم بالتحديث؟', () => api('POST', '/admin/app-version', {
        minBuild: Number(build.value), updateUrl: url.value.trim(),
      })))),
  ]));

  box.append(controlsBar([
    searchBox(current.search, 'ابحث في رسالة العطل', (value) => { current.search = value; render(); }),
    ...dateFilters(),
  ]));
  if (shown.length === 0) {
    box.append(empty('لا توجد أعطال', 'لم يسجل التطبيق أي عطل على هواتف المستخدمين في هذه الفترة.'));
    return;
  }
  box.append(table(['العطل', 'مرات الحدوث', 'مستخدمون', 'النسخة', 'النظام', 'آخر مرة'], shown.map((item) => ({
    item,
    cells: [
      el('strong', item.message, 'prod-name-ar'), item.times, item.people,
      item.oldest_build === item.newest_build ? (item.newest_build ?? '-') : item.oldest_build + ' - ' + item.newest_build,
      item.platforms || '-', date(item.last_at),
    ],
  })), (item) => openErrorTrace(item)));
}

/// Where in the code the crash happened, for whoever fixes it
function openErrorTrace(item) {
  const text = [item.message, '', item.stack || 'لا توجد تفاصيل إضافية'].join('\n');
  navigator.clipboard?.writeText(text).then(() => toast('تم نسخ تفاصيل العطل'), () => toast('تعذر نسخ التفاصيل', true));
}
