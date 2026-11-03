async function applicationsPage(box) {
  const { data } = await api('GET', '/admin/urgent-applications');
  const shown = applyFilters(data, (item) => item.urgent_terms_accepted_at || item.created_at);
  const week = Date.now() - 7 * 86400000;
  box.append(summaryBar([
    ['طلبات انضمام', data.length, 'lawyer', 'amber'],
    ['آخر 7 أيام', data.filter((item) => new Date(item.urgent_terms_accepted_at || 0) > week).length, 'calendar', 'blue'],
    ['مستندات مكتملة', data.filter((item) => item.photo && item.card_id).length, 'check', 'green'],
  ]));
  box.append(guide('راجع الصورة الشخصية وصورة البطاقة وبيانات المحامي قبل الموافقة.',
    'بعد الموافقة ينتقل المحامي إلى قائمة المحامين ويصبح له ملف شخصي، ويتمكن من استقبال طلبات «محاميك حالاً».'));
  box.append(controlsBar(dateFilters()));

  box.append(table(['الاسم', 'الهاتف', 'رقم القيد', 'سنوات الخبرة', 'تاريخ التقديم', 'الحالة', 'الإجراءات'], shown.map((item) => ({
    item,
    cells: [
      el('strong', item.full_name, 'prod-name-ar'), item.phone, item.syndicate_number || 'غير مسجل', item.experience_years ?? 0,
      date(item.urgent_terms_accepted_at), badge('بانتظار المراجعة', 'amber'), link('فتح', () => open('application', item), 'btn-outline btn-xs', 'open'),
    ],
  })), (item) => open('application', item)));
}

/// The card is private, so it is fetched with the admin sign-in and shown from memory
async function privateDocument(id) {
  const load = () => fetch(API + '/lawyers/documents/' + id, { headers: { Authorization: 'Bearer ' + session?.accessToken } });
  let res = await load();
  if (res.status === 401 && await refreshSession()) res = await load();
  if (!res.ok) throw new Error('تعذر تحميل صورة البطاقة');
  return URL.createObjectURL(await res.blob());
}

function documentBox(title, content) {
  const box = el('figure', undefined, 'doc-box');
  box.append(content, el('figcaption', title));
  return box;
}

function missingDocument(text) {
  const node = el('div', undefined, 'doc-missing');
  node.append(icon('complaint'), el('span', text));
  return node;
}

async function documentsGrid(item) {
  const grid = el('div', undefined, 'doc-grid');

  if (item.photo) {
    grid.append(documentBox('الصورة الشخصية', imageThumb(item.photo, 'الصورة الشخصية')));
  } else {
    grid.append(documentBox('الصورة الشخصية', missingDocument('لم يرفع المحامي صورته بعد')));
  }

  if (!item.card_id) {
    grid.append(documentBox('بطاقة النقابة', missingDocument('لم يرفع المحامي صورة البطاقة بعد')));
  } else {
    try {
      const url = await privateDocument(item.card_id);
      if (item.card_mime === 'application/pdf') {
        const view = el('a');
        view.href = url;
        view.target = '_blank';
        view.rel = 'noopener';
        view.className = 'btn btn-outline';
        view.append(icon('open'), el('span', 'فتح ملف البطاقة'));
        grid.append(documentBox('بطاقة النقابة', view));
      } else {
        grid.append(documentBox('بطاقة النقابة', imageThumb(url, 'بطاقة النقابة')));
      }
    } catch (err) {
      grid.append(documentBox('بطاقة النقابة', missingDocument(err.message)));
    }
  }
  return grid;
}

/// One application on its own page, the list already carries everything it shows
async function applicationPage(box) {
  const item = current.param;
  const decide = (approve, reason) => decideAndReturn(() =>
    api('POST', '/admin/urgent-applications/' + item.user_id + '/decision', { approve, reason }));

  const card = el('div', undefined, 'application-card');
  const head = el('div', undefined, 'application-head');
  const title = el('div', undefined, 'view-title-row');
  title.append(el('h2', item.full_name, 'view-product-title'), badge('بانتظار المراجعة', 'amber'));
  head.append(title, actionButton([
    {
      title: 'الموافقة على الطلب', description: 'يتيح للمحامي استقبال طلبات «محاميك حالاً».', steps: [], success: 'تمت الموافقة',
      summary: () => [['المحامي', item.full_name]], run: () => decide(true),
    },
    {
      title: 'رفض الطلب', description: 'يرفض الطلب، ويصل إلى المحامي إشعار بالسبب.', success: 'تم الرفض', danger: true,
      steps: [{ key: 'reason', type: 'text', label: 'ما سبب الرفض؟', min: 3 }],
      summary: (values) => [['المحامي', item.full_name], ['السبب', values.reason]], run: (values) => decide(false, values.reason),
    },
  ]));
  const content = el('div', undefined, 'application-body');
  content.append(details([
    ['الهاتف', item.phone], ['رقم القيد', item.syndicate_number || 'غير مسجل'],
    ['سنوات الخبرة', item.experience_years ?? 0],
  ]), await documentsGrid(item));
  card.append(head, content);
  box.append(card);
}
